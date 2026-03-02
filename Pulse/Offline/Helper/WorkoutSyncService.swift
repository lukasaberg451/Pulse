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
                let wasOffline = self?.isOnline == false
                self?.isOnline = path.status == .satisfied
                
                // If we just came back online, trigger sync
                if wasOffline && self?.isOnline == true {
                    await self?.syncPendingWorkouts()
                    await self?.syncExercisesAndRoutines()
                    await self?.syncFromServer() // Pull changes from server
                }
            }
        }
        monitor.start(queue: queue)
        
        // Set up periodic sync every 5 minutes
        startPeriodicSync()
    }
    
    private func startPeriodicSync() {
        // Cancel any existing periodic sync
        periodicSyncTask?.cancel()
        
        // Start new periodic sync task
        periodicSyncTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000) // 5 minutes
                if !Task.isCancelled && isOnline {
                    print("⏰ Running periodic sync from server...")
                    await syncFromServer()
                }
            }
        }
        
        print("✅ Periodic sync started (every 5 minutes)")
    }
    
    /// Sync changes FROM the server TO local storage
    private func syncFromServer() async {
        guard isOnline, let modelContext = modelContext else {
            print("🔽 Cannot sync from server: isOnline=\(isOnline), modelContext=\(modelContext != nil)")
            return
        }
        
        print("🔽 Syncing from server...")
        
        do {
            // Fetch all remote sessions
            let remoteSessions = try await WorkoutRepository().fetchSessions()
            print("🔽 Found \(remoteSessions.count) remote sessions")
            let remoteSessionIds = Set(remoteSessions.map { $0.id })
            
            // Fetch all local sessions
            let localDescriptor = FetchDescriptor<LocalWorkoutSession>()
            let localSessions = try modelContext.fetch(localDescriptor)
            print("🔽 Found \(localSessions.count) local sessions")
            
            // Delete local sessions that don't exist remotely
            var deletedCount = 0
            for localSession in localSessions {
                if !remoteSessionIds.contains(localSession.id) {
                    print("🗑️ Deleting local session that was removed remotely: \(localSession.name) (ID: \(localSession.id))")
                    modelContext.delete(localSession)
                    deletedCount += 1
                }
            }
            
            if deletedCount > 0 {
                try modelContext.save()
                print("✅ Server sync complete - deleted \(deletedCount) local sessions")
                
                // Post notification to refresh UI
                NotificationCenter.default.post(name: .workoutDataChanged, object: nil)
            } else {
                print("✅ Server sync complete - no changes")
            }
        } catch {
            print("❌ Failed to sync from server: \(error.localizedDescription)")
        }
    }
    
    /// Sync routines from Supabase to local cache
    func syncExercisesAndRoutines() async {
        guard isOnline, let modelContext = modelContext else { return }
        
        print("🔄 Syncing routines and exercises...")
        
        let exerciseRepo = OfflineExerciseRepository(modelContext: modelContext)
        
        do {
            // Fetch and cache all routines
            let routines = try await exerciseRepo.fetchAndCacheRoutines()
            print("✅ Cached \(routines.count) routines")
            
            // Fetch and cache exercises for each routine
            for routine in routines {
                do {
                    let exercises = try await exerciseRepo.fetchAndCacheRoutineExercises(routineId: routine.id)
                    print("✅ Cached \(exercises.count) exercises for routine: \(routine.name)")
                } catch {
                    print("⚠️ Failed to cache exercises for routine \(routine.name): \(error)")
                }
            }
            
            print("✅ Routine and exercise sync complete")
        } catch {
            print("❌ Failed to sync routines/exercises: \(error)")
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
            
            print("🔄 Found \(unsyncedSessions.count) completed sessions to sync")
            
            for session in unsyncedSessions {
                await syncSession(session, context: modelContext)
            }
            
            lastSyncDate = Date()
            if unsyncedSessions.count > 0 {
                print("✅ Sync completed successfully - synced \(unsyncedSessions.count) sessions")
            }
        } catch {
            print("❌ Sync error: \(error)")
        }
    }
    
    private func syncSession(_ session: LocalWorkoutSession, context: ModelContext) async {
        do {
            print("🔄 Syncing completed session: \(session.name) (ID: \(session.id))")
            
            // Check if this is a new session that needs to be created in Supabase
            // (sessions from scheduled workouts already exist in Supabase)
            let sessionExistsInSupabase = await checkSessionExists(id: session.id)
            
            if !sessionExistsInSupabase {
                // Create the session in Supabase first
                print("📝 Creating new session in Supabase")
                try await repository.createSessionWithId(
                    id: session.id,
                    name: session.name,
                    routineId: session.routineId,
                    startedAt: session.startedAt
                )
            } else {
                print("✅ Session already exists in Supabase (from scheduling)")
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
                print("✅ Marked session as completed in Supabase")
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
            
            print("✅ Successfully synced session: \(session.name)")
        } catch {
            print("❌ Failed to sync session: \(error)")
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
                    completed: set.completed
                )
                print("✅ Created set in Supabase: Set \(set.setNumber) for exercise \(set.exerciseId)")
            } catch {
                // If creation failed (e.g., set already exists), try updating
                print("⚠️ Set creation failed, attempting update: \(error.localizedDescription)")
                try await repository.updateSet(
                    id: set.id,
                    reps: set.reps,
                    weight: set.weight,
                    durationSeconds: set.durationSeconds,
                    completed: set.completed
                )
                print("✅ Updated existing set in Supabase: Set \(set.setNumber)")
            }
        } catch {
            print("❌ Failed to sync set: \(error)")
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
}
