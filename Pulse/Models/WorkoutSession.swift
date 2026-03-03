//
//  WorkoutSession.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/8/26.
//

import Foundation

struct WorkoutSession: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let routineId: UUID?
    let name: String
    let startedAt: Date
    let completedAt: Date?
    let durationSeconds: Int?
    let notes: String?
    let createdAt: Date
    let routineDeleted: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case routineId = "routine_id"
        case name
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case durationSeconds = "duration_seconds"
        case notes
        case createdAt = "created_at"
        case routineDeleted = "routine_deleted"
    }
}
