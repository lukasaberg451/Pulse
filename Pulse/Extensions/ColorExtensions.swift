//
//  ColorExtensions.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-19.
//

import SwiftUI

extension Color {
    // MARK: - Core palette (asset catalog)
    static var appBackground: Color { Color("AppBack") }
    static var appSurface: Color { Color("AppSur") }
    static var appText: Color { Color("AppT") }
    static var appAccent: Color { Color("AppAcce") }

    // MARK: - Derived design tokens
    static var appSecondaryText: Color { appText.opacity(0.55) }
    static var appTertiaryText: Color { appText.opacity(0.35) }

    /// Soft accent used for icon backgrounds and tinted tracks
    static var appAccentSubtle: Color { appAccent.opacity(0.12) }

    /// Gradient endpoint for CTA buttons and progress fills
    static var appAccentGradientEnd: Color {
        Color(red: 1.0, green: 0.35, blue: 0.15) // deeper warm orange
    }
}
// MARK: - Gradient helpers

extension LinearGradient {
    /// Subtle vertical background gradient for the dashboard
    static var dashboardBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color.appBackground,
                Color.appBackground.opacity(0.92)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Orange accent gradient for CTA buttons
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Color.appAccent, Color.appAccentGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Accent gradient for progress fills
    static var progressGradient: LinearGradient {
        LinearGradient(
            colors: [Color.appAccent, Color.appAccentGradientEnd],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

