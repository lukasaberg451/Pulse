//
//  TourStep.swift
//  Pulse
//
//  Defines individual steps for the spotlight onboarding tour.
//

import SwiftUI

/// A single step in the spotlight onboarding tour.
struct TourStep: Identifiable {
    let id: String
    let title: String
    let body: String
    let tab: HomeTab
    /// When on the workout tab, which sub-tab to select (0 = Schedule, 1 = Routines). Nil means no change.
    var workoutSubTab: Int? = nil
    /// Corner radius for the spotlight cutout (matches the highlighted view's shape).
    var spotlightCornerRadius: CGFloat = 22
    /// Extra padding around the highlighted element's frame.
    var spotlightPadding: CGFloat = 4
    /// When true, shows only the dimmed overlay and tooltip card with no spotlight cutout.
    var hidesSpotlight: Bool = false
}
