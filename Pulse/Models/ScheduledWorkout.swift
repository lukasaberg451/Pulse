//
//  ScheduledWorkout.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/8/26.
//

import Foundation

struct ScheduledWorkout: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let routineId: UUID?
    let scheduledDate: String // Format: "2024-04-07"
    let completed: Bool
    let workoutSessionId: UUID?
    let notes: String?
    let createdAt: Date
    let routineDeleted: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case routineId = "routine_id"
        case scheduledDate = "scheduled_date"
        case completed
        case workoutSessionId = "workout_session_id"
        case notes
        case createdAt = "created_at"
        case routineDeleted = "routine_deleted"
    }
    
    func date(in timeZone: TimeZone) -> Date? {
        let formatter = SharedFormatters.yearMonthDay
        formatter.timeZone = timeZone
        return formatter.date(from: scheduledDate)
    }
}
