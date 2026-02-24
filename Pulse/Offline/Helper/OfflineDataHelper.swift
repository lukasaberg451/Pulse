//
//  OfflineDataHelper.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-24.
//

import Foundation
import SwiftData

@MainActor
class OfflineDataHelper {
    /// Fetch routines with offline support
    /// User's routines are cached for offline access
    static func fetchRoutines(
        modelContext: ModelContext?,
        forceRefresh: Bool = false
    ) async throws -> [Routine] {
        if let modelContext = modelContext {
            let offlineRepo = OfflineExerciseRepository(modelContext: modelContext)
            return try await offlineRepo.getRoutines(forceRefresh: forceRefresh)
        } else {
            // Fallback to direct Supabase query
            let routineRepo = RoutineRepository()
            return try await routineRepo.fetchRoutines()
        }
    }
    
    /// Fetch routine exercises with offline support
    /// Exercises in user's routines are cached for offline workouts
    static func fetchRoutineExercises(
        routineId: UUID,
        modelContext: ModelContext?,
        forceRefresh: Bool = false
    ) async throws -> [RoutineExercise] {
        if let modelContext = modelContext {
            let offlineRepo = OfflineExerciseRepository(modelContext: modelContext)
            return try await offlineRepo.getRoutineExercises(
                routineId: routineId,
                forceRefresh: forceRefresh
            )
        } else {
            // Fallback to direct Supabase query
            let routineRepo = RoutineRepository()
            return try await routineRepo.fetchRoutineExercises(routineId: routineId)
        }
    }
    
    /// Fetch a specific exercise with offline support
    /// Only cached if it's part of a user's routine
    static func fetchExercise(
        id: UUID,
        modelContext: ModelContext?
    ) async throws -> Exercise {
        if let modelContext = modelContext {
            let offlineRepo = OfflineExerciseRepository(modelContext: modelContext)
            return try await offlineRepo.getExercise(id: id)
        } else {
            // Fallback to direct Supabase query
            let exerciseRepo = ExerciseRepository()
            return try await exerciseRepo.fetchExercise(id: id)
        }
    }
}
