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
            .rpc("refresh_user_milestones", params: ["p_user_id": userId.uuidString])
            .execute()
            .value
        
        return milestones
    }
}
