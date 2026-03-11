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
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground.ignoresSafeArea()
            
                if showingSignUp {
                    RegisterSelectionView(authViewModel: authViewModel, showingSignUp: $showingSignUp, showingSignIn: $showingSignIn)
                } else if showingSignIn {
                    LoginView(authViewModel: authViewModel, showingSignIn: $showingSignIn)
                } else {
                    VStack(spacing: 40) {
                        Spacer()
                        
                        // App branding
                        VStack(spacing: 20) {
                            Image("LoadingLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 180, height: 100)
                        
                            Text("Your Fitness Journey Starts Here")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.appSecondaryText)
                        }
                    
                        Spacer()
                    
                        // Auth buttons
                        VStack(spacing: 14) {
                            PrimaryCTALink("Let's Get Started") {
                                RegisterSelectionView(authViewModel: authViewModel, showingSignUp: $showingSignUp, showingSignIn: $showingSignIn)
                            }
                            
                            NavigationLink {
                                LoginView(authViewModel: authViewModel, showingSignIn: $showingSignIn)
                            } label: {
                                Text("Already Have an Account")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.appText)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.appSurface)
                                            .overlay {
                                                if colorScheme == .dark {
                                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                                }
                                            }
                                            .shadow(color: colorScheme == .light ? .black.opacity(0.06) : .clear, radius: 8, x: 0, y: 4)
                                    }
                            }
                            .buttonStyle(ScalePressStyle())
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                    .navigationDestination(isPresented: $showingSignUp) {
                        RegisterSelectionView(authViewModel: authViewModel, showingSignUp: $showingSignUp, showingSignIn: $showingSignIn)
                    }
                    .navigationDestination(isPresented: $showingSignIn) {
                        LoginView(authViewModel: authViewModel, showingSignIn: $showingSignIn)
                    }
                }
            }
        }
    }
}
