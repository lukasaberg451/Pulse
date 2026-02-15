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
    let weeklyGoalMinutes: Int?  // Add this
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case firstName = "first_name"
        case lastName = "last_name"
        case weeklyGoalMinutes = "weekly_goal_minutes"  // Add this
        case createdAt = "created_at"
    }
}
