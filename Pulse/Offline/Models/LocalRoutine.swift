//
//  LocalRoutine.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-24.
//

import Foundation
import SwiftData

@Model
class LocalRoutine {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var name: String
    var routineDescription: String?
    var createdAt: Date
    var lastSyncedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \LocalRoutineExercise.routine)
    var exercises: [LocalRoutineExercise]?
    
    init(
        id: UUID,
        userId: UUID,
        name: String,
        routineDescription: String? = nil,
        createdAt: Date = Date(),
        lastSyncedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.routineDescription = routineDescription
        self.createdAt = createdAt
        self.lastSyncedAt = lastSyncedAt
    }
    
    // Convert to Routine struct
    func toRoutine() -> Routine {
        Routine(
            id: id,
            userId: userId,
            name: name,
            description: routineDescription,
            createdAt: createdAt
        )
    }
    
    // Create from Routine struct
    static func from(_ routine: Routine) -> LocalRoutine {
        LocalRoutine(
            id: routine.id,
            userId: routine.userId,
            name: routine.name,
            routineDescription: routine.description,
            createdAt: routine.createdAt,
            lastSyncedAt: Date()
        )
    }
}
