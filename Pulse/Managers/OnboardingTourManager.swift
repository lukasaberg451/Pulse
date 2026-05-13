//
//  OnboardingTourManager.swift
//  Pulse
//
//  Observable state machine that drives the spotlight onboarding tour.
//

import SwiftUI
import Combine
import PostHog

final class OnboardingTourManager: ObservableObject {

    // MARK: - Tour steps

    let steps: [TourStep] = [
        TourStep(
            id: "welcome",
            title: String(localized: "Welcome to Pulse"),
            body: String(localized: "Let's take a quick tour to help you get the most out of your training. Tap Next to get started!"),
            tab: .dashboard,
            hidesSpotlight: true
        ),
        TourStep(
            id: "statsBar",
            title: String(localized: "Your Stats at a Glance"),
            body: String(localized: "Track your weekly streak, workouts and training time right here."),
            tab: .dashboard
        ),
        TourStep(
            id: "todaySection",
            title: String(localized: "Today's Workouts"),
            body: String(localized: "See what's scheduled for today and jump straight into a session."),
            tab: .dashboard
        ),
        TourStep(
            id: "weeklyGoal",
            title: String(localized: "Weekly Goal"),
            body: String(localized: "Set a weekly training goal and watch your progress fill up over the week."),
            tab: .dashboard
        ),
        TourStep(
            id: "workoutTab",
            title: String(localized: "Plan & Workout"),
            body: String(localized: "This is where you schedule workouts and build routines. Let's take a closer look."),
            tab: .workout,
            spotlightCornerRadius: 16,
            spotlightPadding: 4
        ),
        TourStep(
            id: "schedulePill",
            title: String(localized: "Schedule Your Workouts"),
            body: String(localized: "Plan your week ahead, assign routines to specific days so you always know what's coming next."),
            tab: .workout,
            workoutSubTab: 0,
            spotlightCornerRadius: 20,
            spotlightPadding: 4
        ),
        TourStep(
            id: "routinesPill",
            title: String(localized: "Build Your Routines"),
            body: String(localized: "Create workout routines, add exercises, configure target reps and sets, and customize them to match your goals."),
            tab: .workout,
            workoutSubTab: 1,
            spotlightCornerRadius: 20,
            spotlightPadding: 4
        ),
        TourStep(
            id: "progressTab",
            title: String(localized: "Track Your Progress"),
            body: String(localized: "Upgrade to Pro to unlock estimated 1RM, weight progress, strength gains, and body metrics. All in one place."),
            tab: .progress,
            spotlightCornerRadius: 16,
            spotlightPadding: 4
        ),
        TourStep(
            id: "profileTab",
            title: String(localized: "Your Profile"),
            body: String(localized: "See your milestones, custom exercises and completed workouts."),
            tab: .profile,
            spotlightCornerRadius: 16,
            spotlightPadding: 4
        ),
        TourStep(
            id: "settingsButton",
            title: String(localized: "Settings"),
            body: String(localized: "Customize your experience! Connect Apple Health, change your theme, set preferred units, and more."),
            tab: .profile,
            spotlightCornerRadius: 50,
            spotlightPadding: 6
        ),
    ]

    // MARK: - Published state

    @Published var isActive = false
    @Published var currentIndex = 0

    var currentStep: TourStep? {
        guard isActive, steps.indices.contains(currentIndex) else { return nil }
        return steps[currentIndex]
    }

    var progress: (current: Int, total: Int) {
        (currentIndex + 1, steps.count)
    }

    // MARK: - Actions

    func start() {
        currentIndex = 0
        isActive = true
    }

    func next() {
        if currentIndex < steps.count - 1 {
            currentIndex += 1
        } else {
            finish()
        }
    }

    func skip() {
        PostHogSDK.shared.capture("onboarding_tour_skipped", properties: [
            "skipped_at_step": currentIndex
        ])
        finish()
    }

    private func finish() {
        PostHogSDK.shared.capture("onboarding_tour_completed", properties: [
            "steps_viewed": currentIndex + 1
        ])
        isActive = false
        currentIndex = 0
    }
}
