//
//  HomeTab.swift
//  Pulse
//
//  Tab definitions for the main tab bar.
//

import Foundation

enum HomeTab: Int, CaseIterable {
    case dashboard, workout, progress, profile

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .workout:   "Workout"
        case .progress:  "Progress"
        case .profile:   "Profile"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: "DashboardTabIcon"
        case .workout:   "WorkoutTabIcon"
        case .progress:  "ProgressTabIcon"
        case .profile:   "ProfileTabIcon"
        }
    }
}
