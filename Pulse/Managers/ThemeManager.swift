//
//  ThemeManager.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-21.
//

import SwiftUI
import Combine

enum AppTheme: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
    
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
        }
    }
    
    init() {
        let saved = UserDefaults.standard.string(forKey: "selectedTheme") ?? AppTheme.system.rawValue
        self.selectedTheme = AppTheme(rawValue: saved) ?? .system
    }
}
