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
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground.ignoresSafeArea()
                
                if isInitializing {
                    // Loading state while exchanging code
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .appAccent))
                            .scaleEffect(1.5)
                        Text("Verifying...")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.appSecondaryText)
                    }
                } else if showSuccess {
                    // Success view
                    VStack(spacing: 20) {
                        IconBadge(systemName: "checkmark.circle.fill", color: .green, size: 64)
                        
                        Text("Password Reset!")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.appText)
                        
                        Text("You can now sign in with your new password.")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                            .multilineTextAlignment(.center)
                        
                        PrimaryCTAButton("Go to Login") {
                            dismiss()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                    }
                } else {
                    // Form
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Set New Password")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Color.appText)
                            
                            Text("Enter your new password below")
                                .font(.subheadline)
                                .foregroundStyle(Color.appSecondaryText)
                        }
                        
                        if showError {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                                Text(errorMessage)
                                    .foregroundStyle(.red)
                                    .font(.caption.weight(.medium))
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("New Password")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.appText)
                            
                            SecureField("New Password", text: $newPassword)
                                .padding()
                                .foregroundStyle(Color.appText)
                                .background {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.appSurface)
                                        .overlay {
                                            if colorScheme == .dark {
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                            }
                                        }
                                }
                                .textContentType(.newPassword)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm Password")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.appText)
                            
                            SecureField("Confirm Password", text: $confirmPassword)
                                .padding()
                                .foregroundStyle(Color.appText)
                                .background {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.appSurface)
                                        .overlay {
                                            if colorScheme == .dark {
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                            }
                                        }
                                }
                                .textContentType(.newPassword)
                        }
                        
                        Button {
                            Task {
                                await resetPassword()
                            }
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(LinearGradient.accentGradient.opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            } else {
                                Text("Reset Password")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(
                                        LinearGradient.accentGradient.opacity(isValid ? 1 : 0.5),
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    )
                            }
                        }
                        .buttonStyle(ScalePressStyle())
                        .disabled(!isValid || isLoading)
                        .padding(.top, 4)
                        
                        Spacer()
                    }
                    .padding(24)
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
                        .foregroundStyle(Color.appSecondaryText)
                    }
                }
            }
        }
        .presentationBackground(LinearGradient.dashboardBackground)
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
