//
//  LocalExercise.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-24.
//

import Foundation
import SwiftData

@Model
class LocalExercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var exerciseDescription: String?
    var muscleGroup: String?
    var secondaryMuscleGroup: String?
    var equipment: String?
    var instructions: String?
    var exerciseType: String?
    var difficulty: String?
    var isCustom: Bool
    var lastSyncedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .nullify, inverse: \LocalWorkoutSet.exercise)
    var sets: [LocalWorkoutSet]?
    
    @Relationship(deleteRule: .nullify, inverse: \LocalRoutineExercise.exercise)
    var routineExercises: [LocalRoutineExercise]?
    
    init(
        id: UUID,
        name: String,
        exerciseDescription: String? = nil,
        muscleGroup: String? = nil,
        secondaryMuscleGroup: String? = nil,
        equipment: String? = nil,
        instructions: String? = nil,
        exerciseType: String? = nil,
        difficulty: String? = nil,
        isCustom: Bool = false,
        lastSyncedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.exerciseDescription = exerciseDescription
        self.muscleGroup = muscleGroup
        self.secondaryMuscleGroup = secondaryMuscleGroup
        self.equipment = equipment
        self.instructions = instructions
        self.exerciseType = exerciseType
        self.difficulty = difficulty
        self.isCustom = isCustom
        self.lastSyncedAt = lastSyncedAt
    }
    
    var isCardio: Bool { exerciseType == "cardio" }
    var isBodyweight: Bool { exerciseType == "bodyweight" }
    var tracksWeight: Bool { exerciseType == "strength" }

    // Convert to Exercise struct
    func toExercise() -> Exercise {
        Exercise(
            id: id,
            name: name,
            description: exerciseDescription,
            muscleGroup: muscleGroup,
            secondaryMuscleGroup: secondaryMuscleGroup,
            equipment: equipment,
            instructions: instructions,
            exerciseType: exerciseType,
            createdBy: nil,
            createdAt: lastSyncedAt,
            difficulty: difficulty,
            isCustom: isCustom
        )
    }
    
    // Create from Exercise struct
    static func from(_ exercise: Exercise) -> LocalExercise {
        LocalExercise(
            id: exercise.id,
            name: exercise.name,
            exerciseDescription: exercise.description,
            muscleGroup: exercise.muscleGroup,
            secondaryMuscleGroup: exercise.secondaryMuscleGroup,
            equipment: exercise.equipment,
            instructions: exercise.instructions,
            exerciseType: exercise.exerciseType,
            difficulty: exercise.difficulty,
            isCustom: exercise.isCustom ?? false,
            lastSyncedAt: Date()
        )
    }
}
