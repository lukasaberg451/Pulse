//
//  RoutineExercise.swift
//  Pulse
//
//  Created by lukasaberg on 2/8/26.
//

import Foundation

struct RoutineExercise: Codable, Identifiable {
    let id: UUID
    let routineId: UUID
    let exerciseId: UUID
    let orderIndex: Int
    let sets: Int
    let repsTarget: String?
    let restSeconds: Int
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case routineId = "routine_id"
        case exerciseId = "exercise_id"
        case orderIndex = "order_index"
        case sets
        case repsTarget = "reps_target"
        case restSeconds = "rest_seconds"
        case notes
    }
}
