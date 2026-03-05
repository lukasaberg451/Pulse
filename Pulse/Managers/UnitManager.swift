//
//  UnitManager.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-03-05.
//

import SwiftUI
import Combine

enum UnitSystem: String, CaseIterable, Codable {
    case metric = "metric"
    case imperial = "imperial"
    
    var displayName: String {
        switch self {
        case .metric: return "Metric"
        case .imperial: return "Imperial"
        }
    }
    
    var subtitle: String {
        switch self {
        case .metric: return "kg / cm"
        case .imperial: return "lb / ft, in"
        }
    }
}

class UnitManager: ObservableObject {
    static let shared = UnitManager()
    
    private static let kgToLb = 2.20462
    private static let cmToIn = 0.393701
    
    @Published var unitSystem: UnitSystem {
        didSet {
            UserDefaults.standard.set(unitSystem.rawValue, forKey: "unitSystem")
        }
    }
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: "unitSystem") ?? UnitSystem.metric.rawValue
        self.unitSystem = UnitSystem(rawValue: saved) ?? .metric
    }
    
    // MARK: - Display Labels
    
    var weightUnit: String {
        unitSystem == .metric ? "kg" : "lb"
    }
    
    var heightUnit: String {
        unitSystem == .metric ? "cm" : "ft"
    }
    
    // MARK: - Display Conversions (metric → display)
    
    func displayWeight(_ kg: Double) -> Double {
        unitSystem == .metric ? kg : kg * Self.kgToLb
    }
    
    /// Returns total inches when imperial, cm when metric
    func displayHeight(_ cm: Double) -> Double {
        unitSystem == .metric ? cm : cm * Self.cmToIn
    }
    
    /// Returns height as a formatted string: "180" (cm) or "5'11\"" (ft/in)
    func displayHeightFormatted(_ cm: Double) -> String {
        if unitSystem == .metric {
            return String(format: "%.0f", cm)
        } else {
            let totalInches = cm * Self.cmToIn
            let feet = Int(totalInches) / 12
            let inches = Int(totalInches.rounded()) % 12
            return "\(feet)'\(inches)\""
        }
    }
    
    /// Feet component from cm (imperial only)
    func feetFromCm(_ cm: Double) -> Int {
        let totalInches = cm * Self.cmToIn
        return Int(totalInches) / 12
    }
    
    /// Remaining inches component from cm (imperial only)
    func inchesFromCm(_ cm: Double) -> Int {
        let totalInches = cm * Self.cmToIn
        return Int(totalInches.rounded()) % 12
    }
    
    // MARK: - Input Conversions (display → metric)
    
    func toKg(_ displayValue: Double) -> Double {
        unitSystem == .metric ? displayValue : displayValue / Self.kgToLb
    }
    
    func toCm(_ displayValue: Double) -> Double {
        unitSystem == .metric ? displayValue : displayValue / Self.cmToIn
    }
    
    /// Convert feet + inches to cm
    func toCmFromFeetInches(feet: Int, inches: Int) -> Double {
        let totalInches = Double(feet * 12 + inches)
        return totalInches / Self.cmToIn
    }
}
