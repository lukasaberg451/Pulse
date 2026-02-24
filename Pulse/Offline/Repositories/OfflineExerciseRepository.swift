//
//  OfflineExerciseRepository.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-24.
//

import Foundation
import SwiftData
import Supabase

@MainActor
class OfflineExerciseRepository {
    private let modelContext: ModelContext
    private let supabase = SupabaseManager.shared.client
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Exercises
    
    /// Get a specific exercise by ID - caches only what's needed
    func getExercise(id: UUID) async throws -> Exercise {
        // Try local cache first
        let descriptor = FetchDescriptor<LocalExercise>(
            predicate: #Predicate { $0.id == id }
        )
        
        if let localExercise = try modelContext.fetch(descriptor).first {
            return localExercise.toExercise()
        }
        
        // If not in cache and online, fetch from Supabase
        let exercise: Exercise = try await supabase
            .from("exercises")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        
        // Cache it for offline access
        let localExercise = LocalExercise.from(exercise)
        modelContext.insert(localExercise)
        try modelContext.save()
        
        return exercise
    }
    
    /// Get all cached exercises (only exercises used in user's routines)
    func getCachedExercises() throws -> [Exercise] {
        return try fetchLocalExercises()
    }
    
    // MARK: - Routines
    
    /// Fetch routines - tries cache first, then Supabase if online
    func getRoutines(forceRefresh: Bool = false) async throws -> [Routine] {
        let localCount = try fetchLocalRoutineCount()
        if forceRefresh || localCount == 0 {
            do {
                return try await fetchAndCacheRoutines()
            } catch {
                print("⚠️ Failed to fetch routines from Supabase, falling back to cache: \(error)")
                return try fetchLocalRoutines()
            }
        }
        
        return try fetchLocalRoutines()
    }
    
    /// Get routine exercises for a specific routine
    func getRoutineExercises(routineId: UUID, forceRefresh: Bool = false) async throws -> [RoutineExercise] {
        if forceRefresh {
            do {
                return try await fetchAndCacheRoutineExercises(routineId: routineId)
            } catch {
                print("⚠️ Failed to fetch routine exercises from Supabase, falling back to cache: \(error)")
                return try fetchLocalRoutineExercises(routineId: routineId)
            }
        }
        
        return try fetchLocalRoutineExercises(routineId: routineId)
    }
    
    /// Fetch routines from Supabase and cache them
    func fetchAndCacheRoutines() async throws -> [Routine] {
        print("🔄 Fetching routines from Supabase...")
        
        let routines: [Routine] = try await supabase
            .from("routines")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        
        print("✅ Fetched \(routines.count) routines from Supabase")
        
        // Cache them locally
        for routine in routines {
            let descriptor = FetchDescriptor<LocalRoutine>(
                predicate: #Predicate { $0.id == routine.id }
            )
            
            if let existing = try modelContext.fetch(descriptor).first {
                existing.name = routine.name
                existing.routineDescription = routine.description
                existing.lastSyncedAt = Date()
            } else {
                let localRoutine = LocalRoutine.from(routine)
                modelContext.insert(localRoutine)
            }
        }
        
        try modelContext.save()
        print("✅ Cached \(routines.count) routines locally")
        
        return routines
    }
    
    /// Fetch routine exercises from Supabase and cache them
    func fetchAndCacheRoutineExercises(routineId: UUID) async throws -> [RoutineExercise] {
        print("🔄 Fetching routine exercises for \(routineId)...")
        
        let routineExercises: [RoutineExercise] = try await supabase
            .from("routine_exercises")
            .select()
            .eq("routine_id", value: routineId.uuidString)
            .order("order_index")
            .execute()
            .value
        
        print("✅ Fetched \(routineExercises.count) routine exercises")
        
        // Cache them locally
        for routineExercise in routineExercises {
            let descriptor = FetchDescriptor<LocalRoutineExercise>(
                predicate: #Predicate { $0.id == routineExercise.id }
            )
            
            if let existing = try modelContext.fetch(descriptor).first {
                existing.sets = routineExercise.sets
                existing.repsTarget = routineExercise.repsTarget
                existing.targetWeight = routineExercise.targetWeight
                existing.durationSeconds = routineExercise.durationSeconds
                existing.restSeconds = routineExercise.restSeconds
                existing.orderIndex = routineExercise.orderIndex
            } else {
                let localRoutineExercise = LocalRoutineExercise.from(routineExercise)
                modelContext.insert(localRoutineExercise)
                
                // Also ensure the exercise is cached
                do {
                    _ = try await getExercise(id: routineExercise.exerciseId)
                } catch {
                    print("⚠️ Failed to cache exercise \(routineExercise.exerciseId): \(error)")
                }
            }
        }
        
        try modelContext.save()
        print("✅ Cached \(routineExercises.count) routine exercises locally")
        
        return routineExercises
    }
    
    // MARK: - Private Helpers
    
    private func fetchLocalExercises() throws -> [Exercise] {
        let descriptor = FetchDescriptor<LocalExercise>(
            sortBy: [SortDescriptor(\.name)]
        )
        let localExercises = try modelContext.fetch(descriptor)
        return localExercises.map { $0.toExercise() }
    }
    
    private func fetchLocalExerciseCount() throws -> Int {
        let descriptor = FetchDescriptor<LocalExercise>()
        return try modelContext.fetchCount(descriptor)
    }
    
    private func fetchLocalRoutines() throws -> [Routine] {
        let descriptor = FetchDescriptor<LocalRoutine>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let localRoutines = try modelContext.fetch(descriptor)
        return localRoutines.map { $0.toRoutine() }
    }
    
    private func fetchLocalRoutineCount() throws -> Int {
        let descriptor = FetchDescriptor<LocalRoutine>()
        return try modelContext.fetchCount(descriptor)
    }
    
    private func fetchLocalRoutineExercises(routineId: UUID) throws -> [RoutineExercise] {
        let descriptor = FetchDescriptor<LocalRoutineExercise>(
            predicate: #Predicate { $0.routineId == routineId },
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        let localRoutineExercises = try modelContext.fetch(descriptor)
        return localRoutineExercises.map { $0.toRoutineExercise() }
    }
}
