//
//  AuthSelectionView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-14.
//

import SwiftUI

struct AuthSelectionView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var showingSignUp = false
    @State private var showingSignIn = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
            
                if showingSignUp {
                    RegisterView(authViewModel: authViewModel, showingSignUp: $showingSignUp, showingSignIn: $showingSignIn)
                } else if showingSignIn {
                    LoginView(authViewModel: authViewModel, showingSignIn: $showingSignIn)
                } else {
                    VStack(spacing: 40) {
                        Spacer()
                        
                        // App branding
                        VStack(spacing: 16) {
                            Image(.logo)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 140, height: 80)
                        
                            Text("Your Fitness Journey Starts Here")
                            .font(.subheadline)
                            .foregroundStyle(Color.appText.opacity(0.7))
                        }
                    
                        Spacer()
                    
                        // Auth buttons
                        VStack(spacing: 16) {
                            NavigationLink {
                                RegisterView(authViewModel: authViewModel, showingSignUp: $showingSignUp, showingSignIn: $showingSignIn)
                            } label: {
                                Text("Let's Get Started")
                                    .font(.headline)
                                    .foregroundStyle(Color.appText)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.appAccent)
                                    .cornerRadius(10)
                            }
                            NavigationLink {
                                LoginView(authViewModel: authViewModel, showingSignIn: $showingSignIn)
                            } label: {
                                Text("Already Have an Account")
                                    .font(.headline)
                                    .foregroundStyle(Color.appAccent)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.appSurface)
                                    .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 40)
                    }
                    .navigationDestination(isPresented: $showingSignUp) {
                        RegisterView(authViewModel: authViewModel, showingSignUp: $showingSignUp, showingSignIn: $showingSignIn)
                    }
                    .navigationDestination(isPresented: $showingSignIn) {
                        LoginView(authViewModel: authViewModel, showingSignIn: $showingSignIn)
                    }
                }
            }
        }
    }
}
