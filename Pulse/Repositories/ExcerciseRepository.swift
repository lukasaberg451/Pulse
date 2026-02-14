//
//  ExcerciseRepository.swift
//  Pulse
//
//  Created by lukasaberg on 2/7/26.
//

import Foundation
import Supabase

class ExcerciseRepository {
    private let supabase = SupabaseManager.shared.client
    
    func fetchExercises() async throws -> [Exercise] {
        let response: [Exercise] = try await supabase
            .from("exercises")
            .select()
            .order("name")
            .execute()
            .value
        return response
    }
}
