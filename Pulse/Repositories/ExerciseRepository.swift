//
//  ExerciseRepository.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/7/26.
//

import Foundation
import Supabase

class ExerciseRepository {
    static let shared = ExerciseRepository()
    
    private let supabase = SupabaseManager.shared.client
    private var cachedExercises: [Exercise]?
    private var cacheDate: Date?
    private let cacheTTL: TimeInterval = 300 // 5 minutes
    
    func fetchExercises(
        page: Int = 0,
        pageSize: Int = 50,
        equipment: String? = nil,
        muscleGroup: String? = nil,
        search: String = ""
    ) async throws -> [Exercise] {
        let supabase = SupabaseManager.shared.client
        let from = page * pageSize
        let to = from + pageSize - 1
        
        var query = supabase
            .from("exercises")
            .select()
        
        if let equipment = equipment {
            query = query.eq("equipment", value: equipment)
        }
        
        if let muscleGroup = muscleGroup {
            query = query.eq("muscle_group", value: muscleGroup)
        }
        
        if !search.isEmpty {
            query = query.ilike("name", pattern: "%\(search)%")
        }
        
        let exercises: [Exercise] = try await query
            .order("name")
            .range(from: from, to: to)
            .execute()
            .value
        
        if exercises.first != nil {
        }
        
        return exercises
    }
    
    func fetchAllExercises(forceRefresh: Bool = false) async throws -> [Exercise] {
        if !forceRefresh,
           let cached = cachedExercises,
           let date = cacheDate,
           Date().timeIntervalSince(date) < cacheTTL {
            return cached
        }
        
        let exercises: [Exercise] = try await supabase
            .from("exercises")
            .select()
            .order("name")
            .execute()
            .value
        
        cachedExercises = exercises
        cacheDate = Date()
        return exercises
    }
    
    /// Adds an exercise to the cache without a full refresh.
    func addToCache(_ exercise: Exercise) {
        cachedExercises?.append(exercise)
    }
    
    /// Clears the exercise cache (e.g., on logout).
    func clearCache() {
        cachedExercises = nil
        cacheDate = nil
    }
    
    private struct CreateCustomExercisePayload: Encodable {
        let name: String
        let exerciseType: String
        let isCustom: Bool
        let createdBy: String
        
        enum CodingKeys: String, CodingKey {
            case name
            case exerciseType = "exercise_type"
            case isCustom = "is_custom"
            case createdBy = "created_by"
        }
    }
    
    func createCustomExercise(name: String, exerciseType: String) async throws -> Exercise {
        guard let userId = supabase.auth.currentUser?.id else {
            throw NSError(domain: "ExerciseRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let payload = CreateCustomExercisePayload(
            name: name,
            exerciseType: exerciseType,
            isCustom: true,
            createdBy: userId.uuidString
        )
        
        let exercise: Exercise = try await supabase
            .from("exercises")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        
        return exercise
    }
    
    func fetchCustomExercises() async throws -> [Exercise] {
        guard let userId = supabase.auth.currentUser?.id else {
            return []
        }
        
        let exercises: [Exercise] = try await supabase
            .from("exercises")
            .select()
            .eq("is_custom", value: true)
            .eq("created_by", value: userId.uuidString)
            .order("name")
            .execute()
            .value
        
        return exercises
    }
    
    func deleteCustomExercise(id: UUID) async throws {
        guard let userId = supabase.auth.currentUser?.id else {
            throw NSError(domain: "ExerciseRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        try await supabase
            .from("exercises")
            .delete()
            .eq("id", value: id.uuidString)
            .eq("is_custom", value: true)
            .eq("created_by", value: userId.uuidString)
            .execute()
    }
    
    func fetchExercise(id: UUID) async throws -> Exercise {
        let supabase = SupabaseManager.shared.client
        
        let exercise: Exercise = try await supabase
            .from("exercises")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        
        return exercise
    }
}
