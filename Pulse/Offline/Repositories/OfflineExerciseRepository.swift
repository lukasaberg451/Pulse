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
                debugLog("⚠️ Failed to fetch routines from Supabase, falling back to cache: \(error)")
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
                debugLog("⚠️ Failed to fetch routine exercises from Supabase, falling back to cache: \(error)")
                return try fetchLocalRoutineExercises(routineId: routineId)
            }
        }
        
        return try fetchLocalRoutineExercises(routineId: routineId)
    }
    
    /// Fetch routines from Supabase and cache them
    func fetchAndCacheRoutines() async throws -> [Routine] {
        debugLog("🔄 Fetching routines from Supabase...")
        
        let routines: [Routine] = try await supabase
            .from("routines")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        
        debugLog("✅ Fetched \(routines.count) routines from Supabase")
        
        let remoteRoutineIds = Set(routines.map { $0.id })
        
        // Delete local routines that no longer exist on the server
        let allLocalDescriptor = FetchDescriptor<LocalRoutine>()
        let allLocalRoutines = try modelContext.fetch(allLocalDescriptor)
        for localRoutine in allLocalRoutines {
            if !remoteRoutineIds.contains(localRoutine.id) {
                debugLog("🗑️ Removing deleted routine from cache: \(localRoutine.name)")
                modelContext.delete(localRoutine)
            }
        }
        
        // Cache/update routines from server
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
        debugLog("✅ Cached \(routines.count) routines locally")
        
        return routines
    }
    
    /// Fetch routine exercises from Supabase and cache them
    func fetchAndCacheRoutineExercises(routineId: UUID) async throws -> [RoutineExercise] {
        debugLog("🔄 Fetching routine exercises for \(routineId)...")
        
        let routineExercises: [RoutineExercise] = try await supabase
            .from("routine_exercises")
            .select()
            .eq("routine_id", value: routineId.uuidString)
            .order("order_index")
            .execute()
            .value
        
        debugLog("✅ Fetched \(routineExercises.count) routine exercises")
        
        let remoteExerciseIds = Set(routineExercises.map { $0.id })
        
        // Delete local routine exercises for this routine that no longer exist on the server
        let allLocalDescriptor = FetchDescriptor<LocalRoutineExercise>(
            predicate: #Predicate { $0.routineId == routineId }
        )
        let allLocalRoutineExercises = try modelContext.fetch(allLocalDescriptor)
        for localRE in allLocalRoutineExercises {
            if !remoteExerciseIds.contains(localRE.id) {
                debugLog("🗑️ Removing deleted routine exercise from cache: \(localRE.id)")
                modelContext.delete(localRE)
            }
        }
        
        // Cache/update routine exercises from server
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
                existing.notes = routineExercise.notes
            } else {
                let localRoutineExercise = LocalRoutineExercise.from(routineExercise)
                modelContext.insert(localRoutineExercise)
                
                // Also ensure the exercise is cached
                do {
                    _ = try await getExercise(id: routineExercise.exerciseId)
                } catch {
                    debugLog("⚠️ Failed to cache exercise \(routineExercise.exerciseId): \(error)")
                }
            }
        }
        
        try modelContext.save()
        debugLog("✅ Cached \(routineExercises.count) routine exercises locally")
        
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
