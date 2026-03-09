//
//  ResetPasswordInAppView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-20.
//

import SwiftUI
import Supabase

struct ResetPasswordInAppView: View {
    @Environment(\.dismiss) var dismiss
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var isInitializing = true
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var hasExchangedCode = false
    
    private let supabase = SupabaseManager.shared.client
    let recoveryCode: String?
    
    init(recoveryCode: String? = nil) {
        self.recoveryCode = recoveryCode
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                if isInitializing {
                    // Loading state while exchanging code
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Verifying...")
                            .foregroundStyle(Color.appText)
                    }
                } else if showSuccess {
                    // Success view
                    VStack(spacing: 24) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(Color.green)
                        
                        Text("Password Reset!")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.appText)
                        
                        Text("You can now sign in with your new password.")
                            .foregroundStyle(Color.appText.opacity(0.7))
                            .multilineTextAlignment(.center)
                        
                        Button("Go to Login") {
                            dismiss()
                        }
                        .foregroundStyle(Color.appText)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(Color.appAccent)
                        .cornerRadius(12)
                    }
                } else {
                    // Form
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Set New Password")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.appText)
                            
                            Text("Enter your new password below")
                                .font(.subheadline)
                                .foregroundStyle(Color.appText.opacity(0.7))
                        }
                        
                        if showError {
                            Text(errorMessage)
                                .foregroundStyle(Color.red)
                                .font(.caption)
                        }
                        
                        SecureField("New Password", text: $newPassword)
                            .padding()
                            .background(Color.appSurface)
                            .cornerRadius(12)
                            .textContentType(.newPassword)
                        
                        SecureField("Confirm Password", text: $confirmPassword)
                            .padding()
                            .background(Color.appSurface)
                            .cornerRadius(12)
                            .textContentType(.newPassword)
                        
                        Button {
                            Task {
                                await resetPassword()
                            }
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Reset Password")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .foregroundStyle(Color.appText)
                        .padding()
                        .background(isValid ? Color.appAccent : Color.appAccent.opacity(0.5))
                        .cornerRadius(12)
                        .disabled(!isValid || isLoading)
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !showSuccess && !isInitializing {
                        Button("Cancel") {
                            Task {
                                UserDefaults.standard.removeObject(forKey: "pendingPasswordReset")
                                try? await supabase.auth.signOut()
                                dismiss()
                            }
                        }
                        .foregroundStyle(Color.appText)
                    }
                }
            }
        }
        .presentationBackground(Color.appBackground)
        .task {
            await exchangeCodeForSession()
        }
    }
    
    var isValid: Bool {
        !newPassword.isEmpty && newPassword.count >= 6 && newPassword == confirmPassword
    }
    
    func exchangeCodeForSession() async {
        guard !hasExchangedCode else { return }
        hasExchangedCode = true
        
        // If no code provided, assume session already exists from previous exchange
        if recoveryCode == nil {
            do {
                _ = try await supabase.auth.session
                await MainActor.run {
                    isInitializing = false  // Show the form
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Session expired. Please request a new password reset."
                    showError = true
                    isInitializing = false
                }
            }
            return
        }
        
        // Code provided - exchange it
        
        do {
            _ = try await supabase.auth.exchangeCodeForSession(authCode: recoveryCode!)
            await MainActor.run {
                isInitializing = false
                showError = false
            }
        } catch {
            await MainActor.run {
                if isInitializing {
                    errorMessage = "Invalid or expired recovery link: \(error.localizedDescription)"
                    showError = true
                    isInitializing = false
                }
            }
        }
    }
    
    func resetPassword() async {
        isLoading = true
        showError = false
        
        do {
            try await supabase.auth.update(
                user: UserAttributes(password: newPassword)
            )
            
            // Clear the pending reset flag so it doesn't re-trigger on next launch
            UserDefaults.standard.removeObject(forKey: "pendingPasswordReset")
            
            // Sign out the recovery session so the user must log in fresh
            try? await supabase.auth.signOut()
            
            showSuccess = true
        } catch {
            errorMessage = "Failed to reset password: \(error.localizedDescription)"
            showError = true
        }
        
        isLoading = false
    }
}
