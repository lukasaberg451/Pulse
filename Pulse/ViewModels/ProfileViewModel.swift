//
//  ProfileViewModel.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-15.
//

import Foundation
import Combine
import Supabase

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var profile: Profile?
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var isSubmittingFeedback = false
    @Published var feedbackError: String?
    
    private let supabase = SupabaseManager.shared.client
    
    var initials: String {
        guard let profile = profile else { return "?" }
        let first = profile.firstName?.prefix(1) ?? ""
        let last = profile.lastName?.prefix(1) ?? ""
        return "\(first)\(last)".uppercased()
    }
    
    func loadProfile() async {
        isLoading = true
        
        do {
            guard let userId = supabase.auth.currentUser?.id else {
                isLoading = false
                return
            }
            let profile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            self.profile = profile
        } catch {
            print("Failed to load profile: \(error)")
        }
        
        isLoading = false
    }
    
    func updateProfile(firstName: String, lastName: String) async {
        do {
            guard let userId = supabase.auth.currentUser?.id else { return }
            
            struct UpdateProfile: Encodable {
                let first_name: String
                let last_name: String
            }
            
            try await supabase
                .from("profiles")
                .update(UpdateProfile(first_name: firstName, last_name: lastName))
                .eq("id", value: userId.uuidString)
                .execute()
            
            // Reload profile
            await loadProfile()
        } catch {
            print("Failed to update profile: \(error)")
        }
    }
    
    func submitFeedback(type: String, title: String, description: String) async -> Bool {
        isSubmitting = true
        errorMessage = nil
        
        do {
            guard let userId = supabase.auth.currentUser?.id else {
                errorMessage = "User not authenticated"
                isSubmitting = false
                return false
            }
            
            struct Feedback: Encodable {
                let user_id: String
                let type: String
                let title: String
                let description: String
            }
            
            let feedback = Feedback(
                user_id: userId.uuidString,
                type: type,
                title: title,
                description: description
            )
            
            try await supabase
                .from("feedback")
                .insert(feedback)
                .execute()
            
            isSubmitting = false
            return true
        } catch {
            errorMessage = "Failed to submit feedback: \(error.localizedDescription)"
            isSubmitting = false
            return false
        }
    }
}
