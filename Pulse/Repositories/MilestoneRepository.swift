//
//  MilestoneRepository.swift
//  Pulse
//

import Foundation
import Supabase

class MilestoneRepository {
    private let supabase = SupabaseManager.shared.client
    
    /// Calls the server-side RPC to recompute all milestone progress
    /// and returns the updated milestones.
    func refreshMilestones() async throws -> [UserMilestone] {
        guard let userId = supabase.auth.currentUser?.id else {
            return []
        }
        
        let milestones: [UserMilestone] = try await supabase
            .rpc("refresh_user_milestones", params: ["p_user_id": userId.uuidString])
            .execute()
            .value
        
        return milestones
    }
    
    /// Fetches existing milestone data without recomputing.
    /// Used for fast reads when fresh data isn't needed.
    func fetchUserMilestones() async throws -> [UserMilestone] {
        guard let userId = supabase.auth.currentUser?.id else {
            return []
        }
        
        let milestones: [UserMilestone] = try await supabase
            .from("user_milestones")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        return milestones
    }
    
    /// Sets `unlocked_at` to now for a given user milestone.
    func unlockMilestone(milestoneId: UUID) async throws {
        try await supabase
            .from("user_milestones")
            .update(["unlocked_at": SharedFormatters.iso8601.string(from: Date())])
            .eq("id", value: milestoneId.uuidString)
            .execute()
    }
}
