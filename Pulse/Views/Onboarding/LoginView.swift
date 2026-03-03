//
//  LoginView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/5/26.
//

import SwiftUI
import Supabase
import AuthenticationServices

struct LoginView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Binding var showingSignIn: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showingForgotPassword = false
    
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
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
                        VStack {
                            if showError {
                                Text(errorMessage)
                                    .foregroundStyle(Color.red)
                                    .font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text(" ")
                                    .font(.caption)
                            }
                        }
                        .frame(minHeight: 20)
                        
                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .foregroundStyle(Color.appText)
                                .font(.headline)
                                .bold()
                            
                            TextField("", text: $email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .padding()
                                .background(Color.appSurface)
                                .foregroundStyle(Color.appText)
                                .cornerRadius(10)
                                .onChange(of: email) {
                                    showError = false
                                }
                        }
                        
                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .foregroundStyle(Color.appText)
                                .font(.headline)
                                .bold()
                            
                            SecureField("", text: $password)
                                .padding()
                                .background(Color.appSurface)
                                .foregroundStyle(Color.appText)
                                .cornerRadius(10)
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
                            .font(.caption)
                            .foregroundStyle(Color.appAccent)
                        }
                        
                        // Sign in button
                        Button(action: {
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
                        }) {
                            HStack {
                                Spacer()
                                Text("Sign In")
                                Spacer()
                            }
                            .font(.headline)
                            .padding()
                            .background(Color.appAccent)
                            .foregroundStyle(Color.appText)
                            .cornerRadius(10)
                        }
                        .padding(.top, 10)
                        
                        // Divider with "or"
                        HStack {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundStyle(Color.appText.opacity(0.3))
                            Text("or")
                                .font(.subheadline)
                                .foregroundStyle(Color.appText.opacity(0.5))
                            Rectangle()
                                .frame(height: 1)
                                .foregroundStyle(Color.appText.opacity(0.3))
                        }
                        .padding(.top, 20)
                        
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
                        .frame(height: 50)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                }
                
                // Fullscreen loading overlay
                if authViewModel.isLoading {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("Signing in...")
                            .foregroundStyle(Color.appText)
                            .font(.headline)
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: authViewModel.isLoading)
            .navigationBarBackButtonHidden(false)
            .toolbar {
            }
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
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            if resetSuccess {
                // Success View
                VStack(spacing: 24) {
                    Image(systemName: "envelope.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(Color.green)
                    
                    Text("Check Your Email")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.appText)
                    
                    Text("We've sent a password reset link to")
                        .foregroundStyle(Color.appText.opacity(0.7))
                    
                    Text(email)
                        .foregroundStyle(Color.appAccent)
                        .fontWeight(.semibold)
                    
                    Text("Click the link in the email to reset your password, then return here to sign in.")
                        .foregroundStyle(Color.appText.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button(action: {
                        resetSuccess = false
                        dismiss()
                    }) {
                        Text("Back to Login")
                            .font(.headline)
                            .foregroundStyle(Color.appText)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appAccent)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
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
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.appText)
                            
                            Text("Enter your email to receive a reset link")
                                .font(.subheadline)
                                .foregroundStyle(Color.appText.opacity(0.7))
                        }
                        .padding(.bottom, 10)
                        
                        // Error message
                        VStack {
                            if showError {
                                Text(errorMessage)
                                    .foregroundStyle(Color.red)
                                    .font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineLimit(3)
                            } else {
                                Text(" ")
                                    .font(.caption)
                            }
                        }
                        .frame(minHeight: 40)
                        
                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .foregroundStyle(Color.appText)
                                .font(.headline)
                                .bold()
                            
                            TextField("", text: $email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .padding()
                                .background(Color.appSurface)
                                .foregroundStyle(Color.appText)
                                .cornerRadius(10)
                                .onChange(of: email) {
                                    showError = false
                                }
                        }
                        
                        // Reset Button
                        Button(action: {
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
                        }) {
                            HStack {
                                Spacer()
                                Text("Reset Password")
                                Spacer()
                            }
                            .font(.headline)
                            .padding()
                            .background(Color.appAccent)
                            .foregroundStyle(Color.appText)
                            .cornerRadius(10)
                        }
                        .padding(.top, 10)
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                }
            }
            
            // Fullscreen loading overlay
            if isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("Sending reset link...")
                        .foregroundStyle(Color.appText)
                        .font(.headline)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: isLoading)
        .animation(.easeInOut, value: resetSuccess)
    }
}
