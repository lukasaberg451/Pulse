//
//  ThemeManager.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-21.
//

import SwiftUI
import Combine

enum AppTheme: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var displayName: String {
        switch self {
        case .system: String(localized: "System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

class ThemeManager: ObservableObject {
    @Published var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: "selectedTheme")
            applyToAllWindows()
        }
    }
    
    init() {
        let saved = UserDefaults.standard.string(forKey: "selectedTheme") ?? AppTheme.system.rawValue
        self.selectedTheme = AppTheme(rawValue: saved) ?? .system
    }
    
    /// Applies the selected theme to every window in the app, including
    /// sheet presentation windows that SwiftUI's preferredColorScheme
    /// doesn't reliably update when switching to "system" (nil).
    func applyToAllWindows() {
        let style: UIUserInterfaceStyle
        switch selectedTheme {
        case .light: style = .light
        case .dark: style = .dark
        case .system: style = .unspecified
        }
        
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
