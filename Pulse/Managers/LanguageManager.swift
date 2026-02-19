//
//  LanguageManager.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-18.
//

import Foundation
import SwiftUI
import Combine

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var currentLanguage: String {
        didSet {
            applyLanguage()
        }
    }
    
    let supportedLanguages = [
        ("en", "English", "flag.fill"),
        ("sv", "Svenska", "flag.fill"),
        ("de", "Deutch", "flag.fill"),
        ("es", "Español", "flag.fill")
    ]
    
    private init() {
        // Get saved language or default to device language
        if let saved = UserDefaults.standard.string(forKey: "app_language") {
            self.currentLanguage = saved
        } else {
            // Use device language
            let deviceLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            self.currentLanguage = supportedLanguages.contains(where: { $0.0 == deviceLanguage }) ? deviceLanguage : "en"
        }
        applyLanguage()
    }
    
    func setLanguage(_ code: String) {
        currentLanguage = code
        UserDefaults.standard.set(code, forKey: "app_language")
        UserDefaults.standard.synchronize()
    }
    
    private func applyLanguage() {
        UserDefaults.standard.set([currentLanguage], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
    
    func getCurrentLanguageName() -> String {
        supportedLanguages.first(where: { $0.0 == currentLanguage })?.1 ?? "English"
    }
}
