//
//  OnboardingView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-14.
//

import SwiftUI

struct OnboardingPage: Identifiable {
    let id = UUID()
    let imageName: String
    let title: String
    let description: String
}

struct OnboardingView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var currentPage = 0
    @State private var showingAuth = false
    
    let pages = [
        OnboardingPage(
            imageName: "figure.strengthtraining.traditional",
            title: "Track Every Rep",
            description: "Log your workouts with precision. Track sets, reps, and weight for every exercise."
        ),
        OnboardingPage(
            imageName: "calendar.badge.clock",
            title: "Plan Your Week",
            description: "Schedule your workouts in advance and stay consistent with your fitness goals."
        ),
        OnboardingPage(
            imageName: "chart.line.uptrend.xyaxis",
            title: "See Your Progress",
            description: "Watch your strength grow over time with detailed workout history and statistics."
        )
    ]
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        showingAuth = true
                    }
                    .foregroundStyle(Color.appText.opacity(0.6))
                    .padding()
                }
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                // Bottom buttons
                VStack(spacing: 16) {
                    if currentPage == pages.count - 1 {
                        // Last page - show auth buttons
                        Button {
                            showingAuth = true
                        } label: {
                            Text("Get Started")
                                .font(.headline)
                                .foregroundStyle(Color.appText)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.appAccent)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 40)
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        // Other pages - show next button
                        Button {
                            withAnimation {
                                currentPage += 1
                            }
                        } label: {
                            Text("Next")
                                .font(.headline)
                                .foregroundStyle(Color.appText)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.appAccent)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 40)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.bottom, 40)
                .animation(.easeInOut, value: currentPage)
            }
        }
        .fullScreenCover(isPresented: $showingAuth) {
            AuthSelectionView(authViewModel: authViewModel)
        }
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Icon
            Image(systemName: page.imageName)
                .font(.system(size: 120))
                .foregroundStyle(Color.appAccent)
            
            // Content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.appText)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundStyle(Color.appText.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            Spacer()
        }
    }
}
