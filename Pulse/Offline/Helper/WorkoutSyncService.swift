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

@MainActor
class WorkoutSyncService: ObservableObject {
    static let shared = WorkoutSyncService()
    
    @Published var isOnline = true
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.pulse.networkmonitoring")
    private let repository = WorkoutRepository()
    
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
                }
            }
        }
        monitor.start(queue: queue)
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
            // Fetch all unsynced sessions
            let descriptor = FetchDescriptor<LocalWorkoutSession>(
                predicate: #Predicate { $0.needsSync == true }
            )
            let unsyncedSessions = try modelContext.fetch(descriptor)
            
            print("🔄 Found \(unsyncedSessions.count) sessions to sync")
            
            for session in unsyncedSessions {
                await syncSession(session, context: modelContext)
            }
            
            lastSyncDate = Date()
            print("✅ Sync completed successfully")
        } catch {
            print("❌ Sync error: \(error)")
        }
    }
    
    private func syncSession(_ session: LocalWorkoutSession, context: ModelContext) async {
        do {
            print("🔄 Syncing session: \(session.name)")
            
            // Create session in Supabase
            let remoteSession = try await repository.createSession(
                name: session.name,
                routineId: session.routineId
            )
            
            // Sync all sets for this session
            if let sets = session.sets {
                for set in sets where set.needsSync {
                    await syncSet(set, remoteSessionId: remoteSession.id)
                }
            }
            
            // Complete the session if it's finished
            if session.completedAt != nil,
               let duration = session.durationSeconds {
                try await repository.completeSession(
                    id: remoteSession.id,
                    durationSeconds: duration
                )
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
            
            print("✅ Synced session: \(session.name)")
        } catch {
            print("❌ Failed to sync session: \(error)")
        }
    }
    
    private func syncSet(_ set: LocalWorkoutSet, remoteSessionId: UUID) async {
        do {
            // Create set in Supabase
            let _ = try await repository.createSet(
                sessionId: remoteSessionId,
                exerciseId: set.exerciseId,
                setNumber: set.setNumber,
                reps: set.reps,
                weight: set.weight
            )
            
            // If the set was completed, update it
            if set.completed {
                try await repository.updateSet(
                    id: set.id,
                    reps: set.reps,
                    weight: set.weight,
                    durationSeconds: set.durationSeconds,
                    completed: true
                )
            }
        } catch {
            print("❌ Failed to sync set: \(error)")
        }
    }
    
    func forceSyncIfNeeded() async {
        guard isOnline else { return }
        await syncPendingWorkouts()
    }
}
