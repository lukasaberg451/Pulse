//
//  SentryScreenTracker.swift
//  Pulse
//

import SwiftUI
import Sentry

struct SentryScreenTracker: ViewModifier {
    let screenName: String

    func body(content: Content) -> some View {
        content
            .onAppear {
                SentrySDK.configureScope { scope in
                    scope.setTag(value: screenName, key: "current_screen")
                }

                let breadcrumb = Breadcrumb(level: .info, category: "navigation")
                breadcrumb.message = "Appeared: \(screenName)"
                SentrySDK.addBreadcrumb(breadcrumb)
            }
    }
}

extension View {
    func sentryScreen(_ name: String) -> some View {
        modifier(SentryScreenTracker(screenName: name))
    }
}
