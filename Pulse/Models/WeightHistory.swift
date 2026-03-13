//
//  WeightHistory.swift
//  Pulse
//

import Foundation

struct WeightHistory: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let weightKg: Double
    let recordedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case weightKg = "weight_kg"
        case recordedAt = "recorded_at"
    }
}
