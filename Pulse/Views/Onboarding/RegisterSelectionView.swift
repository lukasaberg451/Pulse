//
//  RegisterSelectionView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-03-03.
//

import SwiftUI
import AuthenticationServices
import SafariServices

struct RegisterSelectionView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Binding var showingSignUp: Bool
    @Binding var showingSignIn: Bool
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var safariURL: URL?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Logo section
                    VStack {
                        Image("LoadingLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 180, height: 100)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 50)
                    
                    // Content section
                    VStack(spacing: 20) {
                        Text("Create Your Account")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.appText)
                        
                        Text("Choose how you'd like to sign up")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                        
                        // Error message
                        if showError {
                            HStack(spacing: 8) {
                                Image("error")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .foregroundStyle(.red)
                                Text(errorMessage)
                                    .foregroundStyle(.red)
                                    .font(.caption.weight(.medium))
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        
                        // Sign up with Email button
                        PrimaryCTALink("Sign Up with Email", icon: "envelope") {
                            RegisterView(authViewModel: authViewModel, showingSignUp: $showingSignUp, showingSignIn: $showingSignIn)
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
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
                
                // Fullscreen loading overlay
                if authViewModel.isLoading {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .appAccent))
                            .scaleEffect(1.5)
                        
                        Text("Signing in...")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.appSecondaryText)
                    }
                    .transition(.opacity)
                }
            }
            .fullScreenCover(item: $safariURL) { url in
                SafariView(url: url)
                    .ignoresSafeArea()
            }
            .animation(.easeInOut, value: authViewModel.isLoading)
            .navigationBarBackButtonHidden(false)
            .toolbar {
            }
            .toolbarBackground(Color.appBackground, for: .navigationBar)
        }
    }
}
