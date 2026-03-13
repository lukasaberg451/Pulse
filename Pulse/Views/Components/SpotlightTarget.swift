//
//  SpotlightTarget.swift
//  Pulse
//
//  PreferenceKey system that lets any view register itself as a spotlight
//  target by providing its bounds anchor in the view hierarchy.
//

import SwiftUI

// MARK: - Preference key (anchor-based)

struct SpotlightAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - View modifier

extension View {
    /// Mark this view as a spotlight target for the onboarding tour.
    func spotlightTarget(_ id: String) -> some View {
        self.anchorPreference(key: SpotlightAnchorKey.self, value: .bounds) { anchor in
            [id: anchor]
        }
    }
}
