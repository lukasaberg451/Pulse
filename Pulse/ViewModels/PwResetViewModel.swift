//
//  PwResetViewModel.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/7/26.
//

import Foundation
import SwiftUI
import Combine
import Supabase

enum PasswordResetStep {
    case enterEmail
    case enterOTP
    case setNewPassword
    case success
}

@MainActor
class PwResetViewModel: ObservableObject {
    @Published var step: PasswordResetStep = .enterEmail
    @Published var email = ""
    @Published var otpCode = ""
    @Published var newPassword = ""
    @Published var confirmPassword = ""
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    
    // Resend cooldown
    @Published var resendCooldown: Int = 0
    private var cooldownTask: Task<Void, Never>?
    
    private let supabase = SupabaseManager.shared.client
    
    // MARK: - Validation
    
    var isPasswordValid: Bool {
        newPassword.count >= 8 &&
        newPassword.range(of: "[A-Z]", options: .regularExpression) != nil &&
        newPassword.range(of: "[a-z]", options: .regularExpression) != nil &&
        newPassword.range(of: "[0-9]", options: .regularExpression) != nil
    }
    
    var passwordsMatch: Bool {
        newPassword == confirmPassword
    }
    
    var canSetPassword: Bool {
        isPasswordValid && passwordsMatch && !confirmPassword.isEmpty
    }
    
    // MARK: - Step 1: Send OTP
    
    func sendOTP() async {
        isLoading = true
        showError = false
        
        // Always advance to OTP step regardless of success/failure
        // to prevent email enumeration. If the email doesn't exist,
        // the user simply won't receive a code and will fail at verify.
        try? await supabase.auth.resetPasswordForEmail(
            email,
            redirectTo: nil
        )
        
        step = .enterOTP
        startResendCooldown()
        isLoading = false
    }
    
    // MARK: - Step 2: Verify OTP
    
    func verifyOTP() async {
        isLoading = true
        showError = false
        
        do {
            // Use .recovery type to create a scoped recovery session,
            // NOT .magicLink or .signup which would create a full login session
            _ = try await supabase.auth.verifyOTP(
                email: email,
                token: otpCode,
                type: .recovery
            )
            step = .setNewPassword
        } catch {
            let message = error.localizedDescription.lowercased()
            if message.contains("expired") {
                errorMessage = "This code has expired. Please request a new one."
            } else {
                errorMessage = "Invalid code. Please check and try again."
            }
            showError = true
        }
        
        isLoading = false
    }
    
    // MARK: - Step 3: Update Password
    
    func updatePassword() async {
        isLoading = true
        showError = false
        
        do {
            try await supabase.auth.update(
                user: UserAttributes(password: newPassword)
            )
            
            // Sign out the temporary recovery session so it does not persist as a full login
            try? await supabase.auth.signOut()
            
            step = .success
        } catch {
            let message = error.localizedDescription.lowercased()
            if message.contains("same password") || message.contains("different password") || message.contains("should be different") {
                errorMessage = "You can't reuse your previous password. Please choose a new one."
            } else {
                errorMessage = "Failed to update password. Please try again."
            }
            showError = true
        }
        
        isLoading = false
    }
    
    // MARK: - Resend OTP
    
    func resendOTP() async {
        guard resendCooldown == 0 else { return }
        
        isLoading = true
        showError = false
        
        // Silently ignore errors to prevent email enumeration
        try? await supabase.auth.resetPasswordForEmail(
            email,
            redirectTo: nil
        )
        
        startResendCooldown()
        isLoading = false
    }
    
    // MARK: - Cooldown Timer
    
    private func startResendCooldown() {
        resendCooldown = 60
        cooldownTask?.cancel()
        cooldownTask = Task { @MainActor in
            while resendCooldown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                resendCooldown -= 1
            }
        }
    }
    
    // MARK: - Reset
    
    func reset() {
        step = .enterEmail
        email = ""
        otpCode = ""
        newPassword = ""
        confirmPassword = ""
        isLoading = false
        errorMessage = ""
        showError = false
        resendCooldown = 0
        cooldownTask?.cancel()
    }
}
