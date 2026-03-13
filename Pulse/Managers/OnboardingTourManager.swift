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
            id: "statsBar",
            title: "Your Stats at a Glance",
            body: "Track your daily streak, total workouts, and weekly training time right here.",
            tab: .dashboard
        ),
        TourStep(
            id: "todaySection",
            title: "Today's Workouts",
            body: "See what's scheduled for today and jump straight into a session.",
            tab: .dashboard
        ),
        TourStep(
            id: "weeklyGoal",
            title: "Weekly Goal",
            body: "Set a weekly training goal and watch your progress fill up over the week.",
            tab: .dashboard
        ),
        TourStep(
            id: "workoutTab",
            title: "Create Your Routines",
            body: "Build workout routines, add exercises, and schedule them to specific days.",
            tab: .workout,
            spotlightCornerRadius: 16,
            spotlightPadding: 4
        ),
        TourStep(
            id: "progressTab",
            title: "Track Your Progress",
            body: "View workout history, personal records, and see how far you've come.",
            tab: .progress,
            spotlightCornerRadius: 16,
            spotlightPadding: 4
        ),
        TourStep(
            id: "profileTab",
            title: "Make It Yours",
            body: "Connect Apple Health, pick a theme, set your units, and send feedback.",
            tab: .profile,
            spotlightCornerRadius: 16,
            spotlightPadding: 4
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
