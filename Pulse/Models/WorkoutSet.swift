//
//  WorkoutSet.swift
//  Pulse
//
//  Created by lukasaberg on 2/8/26.
//

import Foundation

struct WorkoutSet: Codable, Identifiable {
    let id: UUID
    let sessionId: UUID
    let exerciseId: UUID
    let setNumber: Int
    let reps: Int?
    let weight: Double?
    let completed: Bool
    let notes: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case exerciseId = "exercise_id"
        case setNumber = "set_number"
        case reps
        case weight
        case completed
        case notes
        case createdAt = "created_at"
    }
}
