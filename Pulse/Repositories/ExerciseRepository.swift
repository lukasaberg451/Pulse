//
//  ExerciseRepository.swift
//  Pulse
//
//  Created by lukasaberg on 2/7/26.
//

import Foundation
import Supabase

class ExerciseRepository {
    private let supabase = SupabaseManager.shared.client
    
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
    
    func fetchAllExercises() async throws -> [Exercise] {
        let supabase = SupabaseManager.shared.client
        
        let exercises: [Exercise] = try await supabase
            .from("exercises")
            .select()
            .order("name")
            .execute()
            .value
        
        return exercises
    }
}
