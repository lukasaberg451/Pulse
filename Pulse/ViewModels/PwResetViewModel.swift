//
//  PwResetViewModel.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/7/26.
//

import Foundation
import SwiftUI
import Supabase

@MainActor
func sendPasswordReset(email: String) async throws {
    let supabase = SupabaseManager.shared.client
    do {
        try await supabase.auth.resetPasswordForEmail(
            email,
            redirectTo: URL(string: "https://pulsefitness.io/reset-password")
        )
    } catch let error as AuthError {
        if error.localizedDescription.contains("email") || error.localizedDescription.contains("not found") {
            throw NSError(
                domain: "PasswordReset",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "No account found with this email address."]
            )
        } else {
            throw error
        }
    }
}
