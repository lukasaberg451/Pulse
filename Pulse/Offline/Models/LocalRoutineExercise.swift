//
//  LocalRoutineExercise.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-24.
//

import Foundation
import SwiftData

@Model
class LocalRoutineExercise {
    @Attribute(.unique) var id: UUID
    var routineId: UUID
    var exerciseId: UUID
    var sets: Int
    var repsTarget: String?
    var targetWeight: Double?
    var durationSeconds: Int?
    var restSeconds: Int
    var orderIndex: Int
    var createdAt: Date
    
    // Relationships
    @Relationship var routine: LocalRoutine?
    @Relationship var exercise: LocalExercise?
    
    init(
        id: UUID,
        routineId: UUID,
        exerciseId: UUID,
        sets: Int,
        repsTarget: String? = nil,
        targetWeight: Double? = nil,
        durationSeconds: Int? = nil,
        restSeconds: Int = 60,
        orderIndex: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.routineId = routineId
        self.exerciseId = exerciseId
        self.sets = sets
        self.repsTarget = repsTarget
        self.targetWeight = targetWeight
        self.durationSeconds = durationSeconds
        self.restSeconds = restSeconds
        self.orderIndex = orderIndex
        self.createdAt = createdAt
    }
    
    // Convert to RoutineExercise struct
    func toRoutineExercise() -> RoutineExercise {
        RoutineExercise(
            id: id,
            routineId: routineId,
            exerciseId: exerciseId,
            sets: sets,
            repsTarget: repsTarget,
            targetWeight: targetWeight,
            durationSeconds: durationSeconds,
            restSeconds: restSeconds,
            orderIndex: orderIndex,
            createdAt: createdAt
        )
    }
    
    // Create from RoutineExercise struct
    static func from(_ routineExercise: RoutineExercise) -> LocalRoutineExercise {
        LocalRoutineExercise(
            id: routineExercise.id,
            routineId: routineExercise.routineId,
            exerciseId: routineExercise.exerciseId,
            sets: routineExercise.sets,
            repsTarget: routineExercise.repsTarget,
            targetWeight: routineExercise.targetWeight,
            durationSeconds: routineExercise.durationSeconds,
            restSeconds: routineExercise.restSeconds,
            orderIndex: routineExercise.orderIndex,
            createdAt: routineExercise.createdAt
        )
    }
}
