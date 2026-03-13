//
//  SpotlightTarget.swift
//  Pulse
//
//  PreferenceKey system that lets any view register itself as a spotlight
//  target by providing its frame in global coordinates.
//

import SwiftUI

// MARK: - Preference value

/// Holds the frame and identifier for a single spotlight target.
struct SpotlightItem: Equatable {
    let id: String
    let frame: CGRect
}

// MARK: - Preference key

struct SpotlightPreferenceKey: PreferenceKey {
    static var defaultValue: [SpotlightItem] = []
    static func reduce(value: inout [SpotlightItem], nextValue: () -> [SpotlightItem]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - View modifier

/// Attach `.spotlightTarget("stepId")` to any view to make it highlightable.
struct SpotlightTargetModifier: ViewModifier {
    let id: String

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: SpotlightPreferenceKey.self,
                            value: [SpotlightItem(id: id, frame: geo.frame(in: .global))]
                        )
                }
            )
    }
}

extension View {
    /// Mark this view as a spotlight target for the onboarding tour.
    func spotlightTarget(_ id: String) -> some View {
        modifier(SpotlightTargetModifier(id: id))
    }
}
