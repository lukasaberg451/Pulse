//
//  PostSignInGuideView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-27.
//

import SwiftUI
import PostHog

struct PostSignInGuideView: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 0
    @AppStorage("hasCompletedFirstLaunchGuide") private var hasCompletedGuide = false
    
    let steps = [
        GuideStep(
            icon: "hand.wave.fill",
            title: "Great to have you here!",
            description: "Let's take a quick moment to show you around and get you started on your fitness journey.",
            actionTitle: "Show Me Around"
        ),
        GuideStep(
            icon: "dumbbell.fill",
            title: "Create Your First Routine",
            description: "Start by creating a workout routine. Add exercises, set your target reps and sets, and customize it to match your goals.",
            actionTitle: "Got It",
            highlightTab: "Workout"
        ),
        GuideStep(
            icon: "calendar.badge.clock",
            title: "Schedule Your Workouts",
            description: "Plan your week ahead! Assign routines to specific days so you always know what's coming next.",
            actionTitle: "Makes Sense",
            highlightTab: "Workout"
        ),
        GuideStep(
            icon: "play.circle.fill",
            title: "Start a Workout Session",
            description: "When you're ready to train, tap a scheduled workout or start it directly from the routine to begin. Log your sets, track rest times, and stay focused.",
            actionTitle: "Nice!",
            highlightTab: "Workout"
        ),
        GuideStep(
            icon: "chart.bar.fill",
            title: "Your Day at a Glance",
            description: "See today's scheduled workouts, your weekly progress and jump straight into training. All from one place.",
            actionTitle: "Cool!",
            highlightTab: "Dashboard"
        ),
        GuideStep(
            icon: "chart.xyaxis.line",
            title: "Track Your Progress",
            description: "Watch your stats grow over time. Check your workout history, view personal records, and see how far you've come.",
            actionTitle: "Awesome",
            highlightTab: "Progress"
        ),
        GuideStep(
            icon: "person.circle.fill",
            title: "Personalize Your Experience",
            description: "Connect Apple Health, pick a theme, change language, set your preferred units, and more, Make Pulse truly yours.",
            actionTitle: "Super!",
            highlightTab: "Profile"
        ),
        GuideStep(
            icon: "bubble.left.and.exclamationmark.bubble.right",
            title: "Anything Missing?",
            description: "If you have any question or if you feel like something is missing from the app, please use the feedback form on the profile tab",
            actionTitle: "Sure Thing!",
            highlightTab: "Profile"
        ),
        GuideStep(
            icon: "checkmark.circle.fill",
            title: "You're All Set!",
            description: "That's everything you need to know. Ready to crush your first workout?",
            actionTitle: "Let's Go!"
        )
    ]
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                }
            
            // Guide card
            VStack(spacing: 0) {
               
                // Content
                VStack(spacing: 24) {
                    // Icon
                    Image(systemName: steps[currentStep].icon)
                        .font(.largeTitle)
                        .foregroundStyle(Color.appAccent)
                        .id(currentStep) // Force animation on change
                        .transition(.scale.combined(with: .opacity))
                    
                    // Title
                    Text(steps[currentStep].title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.appText)
                        .multilineTextAlignment(.center)
                        .id("title\(currentStep)")
                        .transition(.opacity)
                    
                    // Description
                    Text(steps[currentStep].description)
                        .font(.body)
                        .foregroundStyle(Color.appText.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .id("desc\(currentStep)")
                        .transition(.opacity)
                    
                    // Highlight info (if applicable)
                    if let highlightTab = steps[currentStep].highlightTab {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(Color.appAccent)
                            Text("Check the \(highlightTab) tab")
                                .font(.subheadline)
                                .foregroundStyle(Color.appAccent)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.appAccent.opacity(0.15))
                        .cornerRadius(12)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 24)
                
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? Color.appAccent : Color.appText.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentStep ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3), value: currentStep)
                    }
                }
                .padding(.vertical, 20)
                
                // Action button
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if currentStep < steps.count - 1 {
                            currentStep += 1
                        } else {
                            PostHogSDK.shared.capture("onboarding_completed")
                            hasCompletedGuide = true
                            isPresented = false
                        }
                    }
                } label: {
                    Text(steps[currentStep].actionTitle)
                        .font(.headline)
                        .foregroundStyle(Color.appText)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appAccent)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                
                // Skip option for non-final steps
                if currentStep < steps.count - 1 {
                    Button {
                        PostHogSDK.shared.capture("onboarding_skipped")
                        hasCompletedGuide = true
                        isPresented = false
                    } label: {
                        Text("Skip Guide")
                            .font(.subheadline)
                            .foregroundStyle(Color.appText.opacity(0.5))
                    }
                    .padding(.bottom, 16)
                }
            }
            .frame(maxWidth: 500)
            .background(Color.appSurface)
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
            .padding(32)
        }
    }
}

struct GuideStep: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let actionTitle: String
    let highlightTab: String?
    
    init(icon: String, title: String, description: String, actionTitle: String, highlightTab: String? = nil) {
        self.icon = icon
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.highlightTab = highlightTab
    }
}

#Preview {
    PostSignInGuideView(isPresented: .constant(true))
        .preferredColorScheme(.dark)
}
