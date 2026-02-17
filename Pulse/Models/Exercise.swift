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
    let description: String?
    let muscleGroup: String?
    let secondaryMuscleGroup: String?
    let equipment: String?
    let instructions: String?
    let exerciseType: String?
    let createdBy: UUID?
    let createdAt: Date?
    let difficulty: String?
    let isCustom: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case muscleGroup = "muscle_group"
        case secondaryMuscleGroup = "secondary_muscle_group"
        case equipment
        case instructions
        case exerciseType = "exercise_type"
        case difficulty
        case createdBy = "created_by"
        case createdAt = "created_at"
        case isCustom = "is_custom"
    }
}
