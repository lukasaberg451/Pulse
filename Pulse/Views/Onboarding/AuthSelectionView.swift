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
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            if showingSignUp {
                RegisterView(authViewModel: authViewModel, showingSignUp: $showingSignUp)
            } else if showingSignIn {
                LoginView(authViewModel: authViewModel, showingSignIn: $showingSignIn)
            } else {
                VStack(spacing: 40) {
                    Spacer()
                    
                    // App branding
                    VStack(spacing: 16) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(Color.appAccent)
                        
                        Text("Pulse")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(Color.appText)
                        
                        Text("Your Fitness Journey Starts Here")
                            .font(.subheadline)
                            .foregroundStyle(Color.appText.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // Auth buttons
                    VStack(spacing: 16) {
                        Button {
                            showingSignUp = true
                        } label: {
                            Text("Let's Get Started")
                                .font(.headline)
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.appAccent)
                                .cornerRadius(10)
                        }
                        
                        Button {
                            showingSignIn = true
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
            }
        }
    }
}
