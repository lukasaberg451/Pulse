//
//  WeightHistoryRepository.swift
//  Pulse
//

import Foundation
import Supabase

@MainActor
class WeightHistoryRepository {
    private let supabase = SupabaseManager.shared.client
    
    /// Insert a new weight entry for the current user
    func logWeight(_ weightKg: Double) async throws {
        guard let userId = supabase.auth.currentUser?.id else { return }
        
        struct InsertWeight: Encodable {
            let user_id: String
            let weight_kg: Double
        }
        
        try await supabase
            .from("weight_history")
            .insert(InsertWeight(user_id: userId.uuidString, weight_kg: weightKg))
            .execute()
    }
    
    /// Fetch the user's first ever recorded weight
    func fetchStartWeight() async throws -> WeightHistory? {
        guard let userId = supabase.auth.currentUser?.id else { return nil }
        
        let entries: [WeightHistory] = try await supabase
            .from("weight_history")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("recorded_at", ascending: true)
            .limit(1)
            .execute()
            .value
        
        return entries.first
    }
    
    /// Fetch the user's most recent recorded weight
    func fetchLatestWeight() async throws -> WeightHistory? {
        guard let userId = supabase.auth.currentUser?.id else { return nil }
        
        let entries: [WeightHistory] = try await supabase
            .from("weight_history")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("recorded_at", ascending: false)
            .limit(1)
            .execute()
            .value
        
        return entries.first
    }
    
    /// Fetch all weight history entries for the current user, ordered by date
    func fetchAllWeightHistory() async throws -> [WeightHistory] {
        guard let userId = supabase.auth.currentUser?.id else { return [] }
        
        let entries: [WeightHistory] = try await supabase
            .from("weight_history")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("recorded_at", ascending: true)
            .execute()
            .value
        
        return entries
    }
    
    /// Delete all weight history entries for the current user
    func deleteAllWeightHistory() async throws {
        guard let userId = supabase.auth.currentUser?.id else { return }
        
        try await supabase
            .from("weight_history")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .execute()
    }
}
