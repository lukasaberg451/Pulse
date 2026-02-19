//
//  WelcomeTourView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-16.
//

import SwiftUI

struct WelcomeTourView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentPage = 0
    
    let pages = [
        TourPage(
            icon: "dumbbell.fill",
            title: "Welcome to Pulse",
            description: "Your personal workout companion to track, plan, and crush your fitness goals."
        ),
        TourPage(
            icon: "calendar.badge.plus",
            title: "Schedule Workouts",
            description: "Create routines and schedule them throughout your week. Tap the Workout tab to get started."
        ),
        TourPage(
            icon: "play.circle.fill",
            title: "Track Your Sessions",
            description: "Log every set, rep, and weight. Start a workout and watch your rest timer count down between sets."
        ),
        TourPage(
            icon: "chart.line.uptrend.xyaxis",
            title: "See Your Progress",
            description: "Check your stats, track personal records, and watch your strength grow over time."
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
                        dismiss()
                    }
                    .foregroundStyle(Color.appText.opacity(0.6))
                    .padding()
                }
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        TourPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                // Bottom button
                VStack(spacing: 16) {
                    if currentPage == pages.count - 1 {
                        Button {
                            dismiss()
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
    }
}

struct TourPage: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

struct TourPageView: View {
    let page: TourPage
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            Image(systemName: page.icon)
                .font(.system(size: 100))
                .foregroundStyle(Color.appAccent)
            
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
