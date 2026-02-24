//
//  OfflineWorkoutRepository.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-24.
//

import Foundation
import SwiftData

@MainActor
class OfflineWorkoutRepository {
    private let modelContext: ModelContext
    private let syncService: WorkoutSyncService
    private let exerciseRepository: OfflineExerciseRepository
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.syncService = WorkoutSyncService.shared
        self.syncService.modelContext = modelContext
        self.exerciseRepository = OfflineExerciseRepository(modelContext: modelContext)
    }
    
    // MARK: - Create
    
    func createSession(name: String, routineId: UUID?) -> LocalWorkoutSession {
        let session = LocalWorkoutSession(
            routineId: routineId,
            name: name,
            needsSync: true
        )
        
        modelContext.insert(session)
        
        do {
            try modelContext.save()
            
            // Try to sync immediately if online
            if syncService.isOnline {
                Task {
                    await syncService.syncPendingWorkouts()
                }
            }
        } catch {
            print("❌ Failed to save session: \(error)")
        }
        
        return session
    }
    
    func createSet(
        session: LocalWorkoutSession,
        exerciseId: UUID,
        setNumber: Int,
        reps: Int?,
        weight: Double?
    ) -> LocalWorkoutSet {
        let set = LocalWorkoutSet(
            sessionId: session.id,
            exerciseId: exerciseId,
            setNumber: setNumber,
            reps: reps,
            weight: weight,
            needsSync: true
        )
        
        set.session = session
        
        modelContext.insert(set)
        
        do {
            try modelContext.save()
            
            // Try to sync immediately if online
            if syncService.isOnline {
                Task {
                    await syncService.syncPendingWorkouts()
                }
            }
        } catch {
            print("❌ Failed to save set: \(error)")
        }
        
        return set
    }
    
    // MARK: - Read
    
    func fetchAllSessions() throws -> [LocalWorkoutSession] {
        let descriptor = FetchDescriptor<LocalWorkoutSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func fetchSets(for session: LocalWorkoutSession) throws -> [LocalWorkoutSet] {
        let sessionId = session.id
        let descriptor = FetchDescriptor<LocalWorkoutSet>(
            predicate: #Predicate { $0.sessionId == sessionId },
            sortBy: [SortDescriptor(\.setNumber)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - Update
    
    func updateSet(
        _ set: LocalWorkoutSet,
        reps: Int?,
        weight: Double?,
        durationSeconds: Int?,
        completed: Bool
    ) {
        set.reps = reps
        set.weight = weight
        set.durationSeconds = durationSeconds
        set.completed = completed
        set.needsSync = true
        
        do {
            try modelContext.save()
            
            // Try to sync immediately if online
            if syncService.isOnline {
                Task {
                    await syncService.syncPendingWorkouts()
                }
            }
        } catch {
            print("❌ Failed to update set: \(error)")
        }
    }
    
    func completeSession(_ session: LocalWorkoutSession, durationSeconds: Int) {
        session.completedAt = Date()
        session.durationSeconds = durationSeconds
        session.needsSync = true
        
        do {
            try modelContext.save()
            
            // Try to sync immediately if online
            if syncService.isOnline {
                Task {
                    await syncService.syncPendingWorkouts()
                }
            }
        } catch {
            print("❌ Failed to complete session: \(error)")
        }
    }
    
    // MARK: - Delete
    
    func deleteSession(_ session: LocalWorkoutSession) {
        modelContext.delete(session)
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to delete session: \(error)")
        }
    }
    
    // MARK: - Sync Status
    
    func getPendingSyncCount() throws -> Int {
        let descriptor = FetchDescriptor<LocalWorkoutSession>(
            predicate: #Predicate { $0.needsSync == true }
        )
        return try modelContext.fetchCount(descriptor)
    }
    
    // MARK: - Exercises & Routines
    
    /// Fetch cached exercises (exercises that have been cached locally)
    func getCachedExercises() throws -> [Exercise] {
        return try exerciseRepository.getCachedExercises()
    }
    
    /// Fetch a specific exercise
    func getExercise(id: UUID) async throws -> Exercise {
        return try await exerciseRepository.getExercise(id: id)
    }
    
    /// Fetch routines (from cache or Supabase)
    func getRoutines(forceRefresh: Bool = false) async throws -> [Routine] {
        return try await exerciseRepository.getRoutines(forceRefresh: forceRefresh)
    }
    
    /// Fetch routine exercises
    func getRoutineExercises(routineId: UUID, forceRefresh: Bool = false) async throws -> [RoutineExercise] {
        return try await exerciseRepository.getRoutineExercises(routineId: routineId, forceRefresh: forceRefresh)
    }
    
    /// Prefetch all data needed for offline use
    func prefetchOfflineData() async throws {
        print("🔄 Prefetching data for offline use...")
        
        do {
            // Fetch and cache all routines
            let routines = try await exerciseRepository.fetchAndCacheRoutines()
            print("✅ Cached \(routines.count) routines")
            
            // Fetch routine exercises for all routines (this also caches the exercises)
            for routine in routines {
                let routineExercises = try await exerciseRepository.fetchAndCacheRoutineExercises(routineId: routine.id)
                print("✅ Cached \(routineExercises.count) exercises for routine: \(routine.name)")
            }
            
            print("✅ Offline prefetch complete!")
        } catch {
            print("❌ Failed to prefetch offline data: \(error)")
            throw error
        }
    }
}
