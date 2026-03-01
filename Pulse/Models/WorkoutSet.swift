//
//  WorkoutSet.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/8/26.
//

import Foundation

struct WorkoutSet: Codable, Identifiable {
    let id: UUID
    let sessionId: UUID
    let exerciseId: UUID
    let setNumber: Int
    let reps: Int?  // For strength exercises
    let weight: Double?  // For strength exercises
    let durationSeconds: Int?  // For cardio exercises
    let completed: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case exerciseId = "exercise_id"
        case setNumber = "set_number"
        case reps
        case weight
        case durationSeconds = "duration_seconds"
        case completed
        case createdAt = "created_at"
    }
}
