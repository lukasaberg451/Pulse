//
//  Profile.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-15.
//

import Foundation

struct Profile: Codable, Identifiable {
    let id: UUID
    let email: String?
    let firstName: String?
    let lastName: String?
    let fullName: String?
    let weeklyGoalMinutes: Int?
    let createdAt: Date
    let termsAcceptedAt: Date?
    let weightKg: Double?
    let heightCm: Double?
    let timezone: String?
    let unitSystem: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case firstName = "first_name"
        case lastName = "last_name"
        case fullName = "full_name"
        case weeklyGoalMinutes = "weekly_goal_minutes"
        case createdAt = "created_at"
        case termsAcceptedAt = "terms_accepted_at"
        case weightKg = "weight_kg"
        case heightCm = "height_cm"
        case timezone
        case unitSystem = "unit_system"
    }
    
    // Resolved TimeZone from stored identifier, falls back to device timezone
    var resolvedTimeZone: TimeZone {
        if let tz = timezone, let timeZone = TimeZone(identifier: tz) {
            return timeZone
        }
        return TimeZone.current
    }
    
    // Calendar configured with the user's timezone
    var userCalendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = resolvedTimeZone
        return cal
    }
    
    // Computed property for BMI
    var bmi: Double? {
        guard let weight = weightKg,
              let height = heightCm,
              height > 0 else { return nil }
        
        let heightInMeters = height / 100.0
        return weight / (heightInMeters * heightInMeters)
    }
    
    var bmiCategory: String? {
        guard let bmi = bmi else { return nil }
        
        switch bmi {
        case ..<18.5:
            return "Underweight"
        case 18.5..<25:
            return "Normal"
        case 25..<30:
            return "Overweight"
        default:
            return "Obese"
        }
    }
}
