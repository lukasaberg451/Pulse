//
//  RegisterSelectionView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-03-03.
//

import SwiftUI
import AuthenticationServices

struct RegisterSelectionView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Binding var showingSignUp: Bool
    @Binding var showingSignIn: Bool
    @State private var errorMessage = ""
    @State private var showError = false
    
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
                    
                    // Content section
                    VStack(spacing: 20) {
                        Text("Create Your Account")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.appText)
                        
                        Text("Choose how you'd like to sign up")
                            .font(.subheadline)
                            .foregroundStyle(Color.appText.opacity(0.7))
                        
                        // Error message
                        if showError {
                            Text(errorMessage)
                                .foregroundStyle(Color.red)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // Sign up with Email button
                        NavigationLink {
                            RegisterView(authViewModel: authViewModel, showingSignUp: $showingSignUp, showingSignIn: $showingSignIn)
                        } label: {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .font(.body)
                                Text("Sign Up with Email")
                                    .font(.headline)
                            }
                            .foregroundStyle(Color.appText)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appAccent)
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
                        
                        // Sign up with Apple button
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
                                    errorMessage = "Sign up with Apple failed."
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
        }
    }
}
