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
    @Binding var selectedTab: HomeTab
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
            icon: "chart.bar.fill",
            title: "Your Day at a Glance",
            description: "See today's scheduled workouts, your weekly progress and jump straight into training. All from one place.",
            actionTitle: "Cool!",
            highlightTab: "Dashboard"
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
            icon: "check-circle",
            isAssetIcon: true,
            title: "You're All Set!",
            description: "That's everything you need to know. Ready to crush your first workout?",
            actionTitle: "Let's Go!",
            navigateToTab: "Dashboard"
        )
    ]
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // Guide card
            VStack(spacing: 0) {
               
                // Content
                VStack(spacing: 20) {
                    // Icon
                    Group {
                        if steps[currentStep].isAssetIcon {
                            IconBadge(assetName: steps[currentStep].icon, size: 56)
                        } else {
                            IconBadge(systemName: steps[currentStep].icon, size: 56)
                        }
                    }
                        .id(currentStep)
                        .transition(.scale.combined(with: .opacity))
                    
                    // Title
                    Text(steps[currentStep].title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.appText)
                        .multilineTextAlignment(.center)
                        .id("title\(currentStep)")
                        .transition(.opacity)
                    
                    // Description
                    Text(steps[currentStep].description)
                        .font(.subheadline)
                        .foregroundStyle(Color.appSecondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.horizontal, 16)
                        .id("desc\(currentStep)")
                        .transition(.opacity)
                    
                    // Highlight info (if applicable)
                    if let highlightTab = steps[currentStep].highlightTab {
                        HStack(spacing: 8) {
                            Image("arrow-down-circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundStyle(Color.appAccent)
                            Text("Check the \(highlightTab) tab")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.appAccent)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(Color.appAccentSubtle, in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.vertical, 28)
                .padding(.horizontal, 24)
                
                // Progress dots
                HStack(spacing: 6) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentStep ? Color.appAccent : Color.appText.opacity(0.15))
                            .frame(width: index == currentStep ? 20 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentStep)
                    }
                }
                .padding(.vertical, 20)
                
                // Action button
                PrimaryCTAButton(steps[currentStep].actionTitle) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if currentStep < steps.count - 1 {
                            currentStep += 1
                        } else {
                            PostHogSDK.shared.capture("onboarding_completed")
                            hasCompletedGuide = true
                            isPresented = false
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                
                // Skip option for non-final steps
                if currentStep < steps.count - 1 {
                    Button {
                        PostHogSDK.shared.capture("onboarding_skipped")
                        hasCompletedGuide = true
                        isPresented = false
                    } label: {
                        Text("Skip Guide")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.appTertiaryText)
                    }
                    .padding(.bottom, 16)
                }
            }
            .frame(maxWidth: 500)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.appSurface)
                    .overlay {
                        if colorScheme == .dark {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        }
                    }
                    .shadow(
                        color: colorScheme == .light ? .black.opacity(0.12) : .clear,
                        radius: 24, x: 0, y: 12
                    )
            }
            .padding(32)
        }
        .onChange(of: currentStep) { _, newStep in
            let tabName = steps[newStep].highlightTab ?? steps[newStep].navigateToTab
            if let tabName,
               let tab = HomeTab.allCases.first(where: { $0.title == tabName }) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    selectedTab = tab
                }
            }
        }
    }
}

struct GuideStep: Identifiable {
    let id = UUID()
    let icon: String
    let isAssetIcon: Bool
    let title: String
    let description: String
    let actionTitle: String
    let highlightTab: String?
    let navigateToTab: String?
    
    init(icon: String, isAssetIcon: Bool = false, title: String, description: String, actionTitle: String, highlightTab: String? = nil, navigateToTab: String? = nil) {
        self.icon = icon
        self.isAssetIcon = isAssetIcon
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.highlightTab = highlightTab
        self.navigateToTab = navigateToTab
    }
}

#Preview {
    PostSignInGuideView(isPresented: .constant(true), selectedTab: .constant(.dashboard))
        .preferredColorScheme(.dark)
}
