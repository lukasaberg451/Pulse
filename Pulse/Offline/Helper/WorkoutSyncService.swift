//
//  WorkoutSyncService.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-24.
//

import Foundation
import SwiftData
import Network
import Combine
import Supabase

extension Notification.Name {
    static let workoutDataChanged = Notification.Name("workoutDataChanged")
    static let routineDataChanged = Notification.Name("routineDataChanged")
}

@MainActor
class WorkoutSyncService: ObservableObject {
    static let shared = WorkoutSyncService()
    
    @Published var isOnline = true
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.pulse.networkmonitoring")
    private let repository = WorkoutRepository()
    private var periodicSyncTask: Task<Void, Never>?
    
    var modelContext: ModelContext?
    
    private init() {
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let isNowOnline = path.status == .satisfied
                let wasOffline = self?.isOnline == false
                
                debugLog("🌐 Network path update: status=\(path.status), isNowOnline=\(isNowOnline), wasOffline=\(wasOffline)")
                
                self?.isOnline = isNowOnline
                
                // If we just came back online, trigger sync
                if wasOffline && isNowOnline {
                    debugLog("🌐 Back online - triggering sync...")
                    await self?.syncPendingWorkouts()
                    await self?.syncExercisesAndRoutines()
                    await self?.syncFromServer()
                    debugLog("🌐 Post-reconnect sync complete")
                }
            }
        }
        monitor.start(queue: queue)
        
        // Set up periodic sync for pending local workouts and server-side changes
        startPeriodicSync()
    }
    
    private var serverSyncCounter = 0
    
    private func startPeriodicSync() {
        // Cancel any existing periodic sync
        periodicSyncTask?.cancel()
        
        // Start new periodic sync task
        periodicSyncTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000) // 60 seconds
                guard !Task.isCancelled else { break }
                
                // Always check connectivity with a real network probe,
                // since NWPathMonitor can report stale status in some environments
                let reachable = await checkRealConnectivity()
                
                if reachable && !isOnline {
                    debugLog("⏰ Periodic check detected connectivity restored (monitor was stale)")
                    isOnline = true
                } else if !reachable && isOnline {
                    isOnline = false
                }
                
                if isOnline {
                    // Always sync pending local workouts (lightweight when nothing pending)
                    await syncPendingWorkouts()
                    
                    // Only sync from server every 5th cycle (~5 minutes) to reduce
                    // memory and network overhead from the full session comparison
                    serverSyncCounter += 1
                    if serverSyncCounter >= 5 {
                        serverSyncCounter = 0
                        debugLog("⏰ Running periodic server sync...")
                        await syncFromServer()
                    }
                }
            }
        }
        
        debugLog("✅ Periodic sync started (pending: every 60s, server: every ~5min)")
    }
    
    /// Perform a lightweight network request to verify actual connectivity
    private func checkRealConnectivity() async -> Bool {
        do {
            let url = URL(string: "https://apple.com/library/test/success.html")!
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    /// Sync changes FROM the server TO local storage
    private func syncFromServer() async {
        guard isOnline, let modelContext = modelContext else {
            debugLog("🔽 Cannot sync from server: isOnline=\(isOnline), modelContext=\(modelContext != nil)")
            return
        }
        
        debugLog("🔽 Syncing from server...")
        
        do {
            // Fetch recent remote sessions for sync comparison.
            // A smaller limit reduces memory usage; only recent sessions
            // are likely to be deleted or changed server-side.
            let remoteSessions = try await WorkoutRepository().fetchSessions(limit: 50)
            debugLog("🔽 Found \(remoteSessions.count) remote sessions")
            let remoteSessionIds = Set(remoteSessions.map { $0.id })
            
            // Fetch all local sessions
            let localDescriptor = FetchDescriptor<LocalWorkoutSession>()
            let localSessions = try modelContext.fetch(localDescriptor)
            debugLog("🔽 Found \(localSessions.count) local sessions")
            
            // Delete local sessions that don't exist remotely,
            // but skip sessions that still need sync (they haven't been
            // uploaded yet, so of course they won't exist on the server)
            // and in-progress sessions (completedAt == nil) that may be resumable.
            var deletedCount = 0
            for localSession in localSessions {
                if !remoteSessionIds.contains(localSession.id) && localSession.completedAt != nil && !localSession.needsSync {
                    debugLog("🗑️ Deleting local session that was removed remotely: \(localSession.name) (ID: \(localSession.id))")
                    modelContext.delete(localSession)
                    deletedCount += 1
                }
            }
            
            if deletedCount > 0 {
                try modelContext.save()
                debugLog("✅ Server sync complete - deleted \(deletedCount) local sessions")
                
                // Post notification to refresh UI
                NotificationCenter.default.post(name: .workoutDataChanged, object: nil)
            } else {
                debugLog("✅ Server sync complete - no changes")
            }
        } catch {
            debugLog("❌ Failed to sync from server: \(error.localizedDescription)")
        }
    }
    
    /// Sync routines from Supabase to local cache
    func syncExercisesAndRoutines() async {
        guard isOnline, let modelContext = modelContext else { return }
        
        debugLog("🔄 Syncing routines and exercises...")
        
        let exerciseRepo = OfflineExerciseRepository(modelContext: modelContext)
        
        do {
            // Fetch and cache all routines
            let routines = try await exerciseRepo.fetchAndCacheRoutines()
            debugLog("✅ Cached \(routines.count) routines")
            
            // Fetch and cache exercises for each routine
            for routine in routines {
                do {
                    let exercises = try await exerciseRepo.fetchAndCacheRoutineExercises(routineId: routine.id)
                    debugLog("✅ Cached \(exercises.count) exercises for routine: \(routine.name)")
                } catch {
                    debugLog("⚠️ Failed to cache exercises for routine \(routine.name): \(error)")
                }
            }
            
            debugLog("✅ Routine and exercise sync complete")
        } catch {
            debugLog("❌ Failed to sync routines/exercises: \(error)")
        }
    }
    
    func syncPendingWorkouts() async {
        guard isOnline, let modelContext = modelContext else { return }
        guard !isSyncing else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            // Fetch only COMPLETED unsynced sessions
            let descriptor = FetchDescriptor<LocalWorkoutSession>(
                predicate: #Predicate { 
                    $0.needsSync == true && $0.completedAt != nil
                }
            )
            let unsyncedSessions = try modelContext.fetch(descriptor)
            
            debugLog("🔄 Found \(unsyncedSessions.count) completed sessions to sync")
            
            for session in unsyncedSessions {
                await syncSession(session, context: modelContext)
            }
            
            lastSyncDate = Date()
            if unsyncedSessions.count > 0 {
                debugLog("✅ Sync completed successfully - synced \(unsyncedSessions.count) sessions")
            }
        } catch {
            debugLog("❌ Sync error: \(error)")
        }
    }
    
    private func syncSession(_ session: LocalWorkoutSession, context: ModelContext) async {
        do {
            debugLog("🔄 Syncing completed session: \(session.name) (ID: \(session.id))")
            
            // Check if this is a new session that needs to be created in Supabase
            // (sessions from scheduled workouts already exist in Supabase)
            let sessionExistsInSupabase = await checkSessionExists(id: session.id)
            
            if !sessionExistsInSupabase {
                // Create the session in Supabase first
                debugLog("📝 Creating new session in Supabase")
                try await repository.createSessionWithId(
                    id: session.id,
                    name: session.name,
                    routineId: session.routineId,
                    startedAt: session.startedAt
                )
            } else {
                debugLog("✅ Session already exists in Supabase (from scheduling)")
            }
            
            // Sync all sets for this session
            if let sets = session.sets {
                for set in sets where set.needsSync {
                    await syncSet(set, remoteSessionId: session.id)
                }
            }
            
            // Complete the session if it's finished
            if session.completedAt != nil, let duration = session.durationSeconds {
                try await repository.completeSession(
                    id: session.id,
                    durationSeconds: duration
                )
                debugLog("✅ Marked session as completed in Supabase")
                
                // Create/update scheduled workout entry (only if not already done by finishWorkout)
                if !session.scheduledEntryCreated {
                    if let scheduledWorkoutId = session.scheduledWorkoutId {
                        // This was a scheduled workout — mark it as completed
                        try await repository.completeScheduledWorkout(
                            id: scheduledWorkoutId,
                            sessionId: session.id
                        )
                        session.scheduledEntryCreated = true
                        debugLog("✅ Marked scheduled workout \(scheduledWorkoutId) as completed")
                    } else if let routineId = session.routineId {
                        // Non-scheduled workout — create a completed scheduled entry for the calendar
                        let userTimeZone = await Self.fetchUserTimeZone()
                        try await repository.createCompletedScheduledWorkout(
                            routineId: routineId,
                            sessionId: session.id,
                            date: session.startedAt,
                            timeZone: userTimeZone
                        )
                        session.scheduledEntryCreated = true
                        debugLog("✅ Created completed scheduled entry for offline workout")
                    }
                } else {
                    debugLog("⏭️ Scheduled entry already created, skipping")
                }
                
                // Post notification to refresh UI
                NotificationCenter.default.post(name: .workoutDataChanged, object: nil)
            }
            
            // Mark as synced
            session.needsSync = false
            session.syncedAt = Date()
            
            if let sets = session.sets {
                for set in sets {
                    set.needsSync = false
                    set.syncedAt = Date()
                }
            }
            
            try context.save()
            
            debugLog("✅ Successfully synced session: \(session.name)")
        } catch {
            debugLog("❌ Failed to sync session: \(error)")
        }
    }
    
    // Check if a session exists in Supabase
    private func checkSessionExists(id: UUID) async -> Bool {
        do {
            let _: WorkoutSession = try await SupabaseManager.shared.client
                .from("workout_sessions")
                .select()
                .eq("id", value: id.uuidString)
                .single()
                .execute()
                .value
            return true
        } catch {
            return false
        }
    }
    
    private func syncSet(_ set: LocalWorkoutSet, remoteSessionId: UUID) async {
        do {
            // Try to create the set with the local ID
            // If it already exists, this will fail gracefully and we'll update instead
            do {
                let _ = try await repository.createSetWithId(
                    id: set.id,
                    sessionId: remoteSessionId,
                    exerciseId: set.exerciseId,
                    setNumber: set.setNumber,
                    reps: set.reps,
                    weight: set.weight,
                    durationSeconds: set.durationSeconds,
                    completed: set.completed,
                    orderIndex: set.orderIndex
                )
                debugLog("✅ Created set in Supabase: Set \(set.setNumber) for exercise \(set.exerciseId)")
            } catch {
                // If creation failed (e.g., set already exists), try updating
                debugLog("⚠️ Set creation failed, attempting update: \(error.localizedDescription)")
                try await repository.updateSet(
                    id: set.id,
                    reps: set.reps,
                    weight: set.weight,
                    durationSeconds: set.durationSeconds,
                    completed: set.completed
                )
                debugLog("✅ Updated existing set in Supabase: Set \(set.setNumber)")
            }
        } catch {
            debugLog("❌ Failed to sync set: \(error)")
        }
    }
    
    func forceSyncIfNeeded() async {
        guard isOnline else { return }
        await syncPendingWorkouts()
        await syncFromServer() // Also pull changes from server
    }
    
    /// Force a sync from server immediately (useful for testing)
    func forceSyncFromServer() async {
        await syncFromServer()
    }
    
    private static func fetchUserTimeZone() async -> TimeZone {
        let supabase = SupabaseManager.shared.client
        guard let userId = supabase.auth.currentUser?.id else { return .current }
        
        do {
            let profile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            return profile.resolvedTimeZone
        } catch {
            return .current
        }
    }
}
