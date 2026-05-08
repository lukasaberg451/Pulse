//
//  RoutineExercise.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/8/26.
//

import Foundation

struct RoutineExercise: Codable, Identifiable {
    let id: UUID
    let routineId: UUID
    let exerciseId: UUID
    let sets: Int
    let repsTarget: String?
    let targetWeight: Double?
    let durationSeconds: Int?
    let restSeconds: Int
    var orderIndex: Int
    let notes: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case routineId = "routine_id"
        case exerciseId = "exercise_id"
        case sets
        case repsTarget = "reps_target"
        case targetWeight = "target_weight"
        case durationSeconds = "duration_seconds"
        case restSeconds = "rest_seconds"
        case orderIndex = "order_index"
        case notes
        case createdAt = "created_at"
    }
}
