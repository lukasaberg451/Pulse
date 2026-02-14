//
//  Exercise.swift
//  Pulse
//
//  Created by lukasaberg on 2/7/26.
//

import Foundation

struct Exercise: Codable, Identifiable {
    let id: UUID
    let name: String
    let muscleGroup: String
    let equipment: String?
    let instructions: String?
    let exerciseType: String  // "strength" or "cardio"
    let createdBy: UUID?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case muscleGroup = "muscle_group"
        case equipment
        case instructions
        case exerciseType = "exercise_type"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}
