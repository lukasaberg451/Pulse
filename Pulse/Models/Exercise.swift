//
//  Exercise.swift
//  Pulse
//
//  Created by lukasaberg on 2/7/26.
//

import Foundation

struct  Exercise: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let description: String?
    let muscleGroup: String
    let equipment: String?
    let createdBy: UUID?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case muscleGroup = "muscle_group"
        case equipment
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}
