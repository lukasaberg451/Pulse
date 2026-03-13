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
        case .dashboard: "dashboard"
        case .workout:   "workout"
        case .progress:  "progress"
        case .profile:   "profile"
        }
    }
}
