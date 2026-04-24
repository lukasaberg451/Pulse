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
        case .dashboard: String(localized: "Dashboard")
        case .workout:   String(localized: "Workout")
        case .progress:  String(localized: "Progress")
        case .profile:   String(localized: "Profile")
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
