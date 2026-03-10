//
//  LoginView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/5/26.
//

import SwiftUI
import Supabase
import AuthenticationServices
import SafariServices

struct LoginView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Binding var showingSignIn: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showingForgotPassword = false
    @State private var safariURL: URL?
    @Environment(\.colorScheme) private var colorScheme
    
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Logo section
                    VStack {
                        Image(.logo)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 140, height: 80)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 50)
                    
                    // Form section
                    VStack(alignment: .leading, spacing: 20) {
                        // Error message
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
                        
                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.appText)
                            
                            TextField("Email", text: $email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
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
                                .onChange(of: email) {
                                    showError = false
                                }
                        }
                        
                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.appText)
                            
                            SecureField("Password", text: $password)
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
                                .onChange(of: password) {
                                    showError = false
                                }
                        }
                        
                        // Forgot password
                        HStack {
                            Spacer()
                            Button("Forgot Password?") {
                                showingForgotPassword = true
                            }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.appAccent)
                        }
                        
                        // Sign in button
                        PrimaryCTAButton("Sign In") {
                            if email.trimmingCharacters(in: .whitespaces).isEmpty {
                                errorMessage = "Email is required"
                                showError = true
                            } else if !isValidEmail(email) {
                                errorMessage = "Please enter a valid email address"
                                showError = true
                            } else if password.isEmpty {
                                errorMessage = "Password is required"
                                showError = true
                            } else {
                                showError = false
                                errorMessage = ""
                                Task {
                                    await authViewModel.signIn(email: email, password: password)
                                    
                                    // Check for auth errors after sign in attempt
                                    if let authError = authViewModel.errorMessage {
                                        errorMessage = authError
                                        showError = true
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                        
                        // Divider with "or"
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 0.5)
                                .fill(Color.appTertiaryText)
                                .frame(height: 1)
                            Text("or")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.appTertiaryText)
                            RoundedRectangle(cornerRadius: 0.5)
                                .fill(Color.appTertiaryText)
                                .frame(height: 1)
                        }
                        .padding(.top, 16)
                        
                        // Sign in with Apple button
                        SignInWithAppleButton(.continue) { request in
                            let nonce = authViewModel.generateNonce()
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = authViewModel.sha256(nonce)
                        } onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                Task {
                                    await authViewModel.signInWithApple(authorization: authorization)
                                }
                            case .failure(let error):
                                if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                                    errorMessage = "Sign in with Apple failed."
                                    showError = true
                                }
                            }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        
                        // Terms & Privacy note
                        HStack(spacing: 4) {
                            Text("By continuing, you agree to the")
                                .font(.caption2)
                                .foregroundStyle(Color.appTertiaryText)
                            
                            Button(action: {
                                safariURL = URL(string: "https://pulsefitness.io/terms-app.html")
                            }) {
                                Text("Terms of Service")
                                    .font(.caption2)
                                    .foregroundStyle(Color.appAccent)
                                    .underline()
                            }
                            
                            Text("&")
                                .font(.caption2)
                                .foregroundStyle(Color.appTertiaryText)
                            
                            Button(action: {
                                safariURL = URL(string: "https://pulsefitness.io/privacy-app.html")
                            }) {
                                Text("Privacy Policy")
                                    .font(.caption2)
                                    .foregroundStyle(Color.appAccent)
                                    .underline()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
                
                // Fullscreen loading overlay
                if authViewModel.isLoading {
                    ZStack {
                        Color.appBackground
                            .ignoresSafeArea()
                        
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                    }
                    .transition(.opacity)
                }
            }
            .sheet(item: $safariURL) { url in
                SafariView(url: url)
                    .ignoresSafeArea()
            }
            .animation(.easeInOut, value: authViewModel.isLoading)
            .navigationBarBackButtonHidden(authViewModel.isLoading)
            .toolbar {
            }
            .toolbar(authViewModel.isLoading ? .hidden : .automatic, for: .navigationBar)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .sheet(isPresented: $showingForgotPassword) {
                ForgotPasswordView()
                    .environmentObject(authViewModel)
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

struct ForgotPasswordView: View {
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var isLoading = false
    @State private var resetSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.dismissAllSheets) var dismissAllSheets
    @EnvironmentObject var authViewModel: AuthViewModel
    
    private let supabase = SupabaseManager.shared.client
    
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            LinearGradient.dashboardBackground.ignoresSafeArea()
            
            if resetSuccess {
                // Success View
                VStack(spacing: 20) {
                    IconBadge(systemName: "envelope.circle.fill", color: .green, size: 64)
                    
                    Text("Check Your Email")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.appText)
                    
                    Text("We've sent a password reset link to")
                        .font(.subheadline)
                        .foregroundStyle(Color.appSecondaryText)
                    
                    Text(email)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appAccent)
                    
                    Text("Click the link in the email to reset your password, then return here to sign in.")
                        .font(.subheadline)
                        .foregroundStyle(Color.appSecondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    PrimaryCTAButton("Back to Login") {
                        resetSuccess = false
                        dismiss()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                }
            } else {
                // Reset Password Form
                VStack(spacing: 0) {
                    // Logo section
                    VStack {
                        Image(.logo)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 140, height: 80)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 100)
                    
                    // Form section
                    VStack(alignment: .leading, spacing: 20) {
                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reset Password")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Color.appText)
                            
                            Text("Enter your email to receive a reset link")
                                .font(.subheadline)
                                .foregroundStyle(Color.appSecondaryText)
                        }
                        .padding(.bottom, 10)
                        
                        // Error message
                        if showError {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                                Text(errorMessage)
                                    .foregroundStyle(.red)
                                    .font(.caption.weight(.medium))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineLimit(3)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        
                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.appText)
                            
                            TextField("Email", text: $email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
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
                                .onChange(of: email) {
                                    showError = false
                                }
                        }
                        
                        // Reset Button
                        PrimaryCTAButton("Reset Password") {
                            if email.trimmingCharacters(in: .whitespaces).isEmpty {
                                errorMessage = "Email is required"
                                showError = true
                            } else if !isValidEmail(email) {
                                errorMessage = "Please enter a valid email address"
                                showError = true
                            } else {
                                showError = false
                                errorMessage = ""
                                Task {
                                    isLoading = true
                                    do {
                                        try await sendPasswordReset(email: email)
                                        resetSuccess = true
                                    } catch {
                                        errorMessage = "Failed to send reset email. Please try again."
                                        showError = true
                                    }
                                    isLoading = false
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
            }
            
            // Fullscreen loading overlay
            if isLoading {
                ZStack {
                    Color.appBackground
                        .ignoresSafeArea()
                    
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                }
                .transition(.opacity)
            }
        }
        .presentationBackground(LinearGradient.dashboardBackground)
        .animation(.easeInOut, value: isLoading)
        .animation(.easeInOut, value: resetSuccess)
    }
}
