//
//  LocalWorkoutModels.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-24.
//

import Foundation
import SwiftData

@Model
final class LocalWorkoutSession {
    var id: UUID
    var userId: UUID?
    var routineId: UUID?
    var scheduledWorkoutId: UUID?
    var name: String
    var startedAt: Date
    var completedAt: Date?
    var durationSeconds: Int?
    var notes: String?
    var createdAt: Date
    var needsSync: Bool
    var syncedAt: Date?
    /// Whether the scheduled_workouts entry has already been created/updated for this session.
    /// Prevents duplicate entries when both finishWorkout() and syncSession() run.
    var scheduledEntryCreated: Bool
    
    @Relationship(deleteRule: .cascade, inverse: \LocalWorkoutSet.session)
    var sets: [LocalWorkoutSet]?
    
    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        routineId: UUID? = nil,
        scheduledWorkoutId: UUID? = nil,
        name: String,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        durationSeconds: Int? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        needsSync: Bool = true,
        syncedAt: Date? = nil,
        scheduledEntryCreated: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.routineId = routineId
        self.scheduledWorkoutId = scheduledWorkoutId
        self.name = name
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.durationSeconds = durationSeconds
        self.notes = notes
        self.createdAt = createdAt
        self.needsSync = needsSync
        self.syncedAt = syncedAt
        self.scheduledEntryCreated = scheduledEntryCreated
    }
    
    // Convert from Supabase model
    static func from(_ session: WorkoutSession) -> LocalWorkoutSession {
        LocalWorkoutSession(
            id: session.id,
            userId: session.userId,
            routineId: session.routineId,
            name: session.name,
            startedAt: session.startedAt,
            completedAt: session.completedAt,
            durationSeconds: session.durationSeconds,
            notes: session.notes,
            createdAt: session.createdAt,
            needsSync: false,
            syncedAt: Date()
        )
    }
}

@Model
final class LocalWorkoutSet {
    var id: UUID
    var sessionId: UUID
    var exerciseId: UUID
    var setNumber: Int
    var reps: Int?
    var weight: Double?
    var durationSeconds: Int?
    var completed: Bool
    var orderIndex: Int?
    var createdAt: Date
    var needsSync: Bool
    var syncedAt: Date?
    
    @Relationship var session: LocalWorkoutSession?
    @Relationship var exercise: LocalExercise?
    
    init(
        id: UUID = UUID(),
        sessionId: UUID,
        exerciseId: UUID,
        setNumber: Int,
        reps: Int? = nil,
        weight: Double? = nil,
        durationSeconds: Int? = nil,
        completed: Bool = false,
        orderIndex: Int? = nil,
        createdAt: Date = Date(),
        needsSync: Bool = true,
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.exerciseId = exerciseId
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.durationSeconds = durationSeconds
        self.completed = completed
        self.orderIndex = orderIndex
        self.createdAt = createdAt
        self.needsSync = needsSync
        self.syncedAt = syncedAt
    }
    
    // Convert from Supabase model
    static func from(_ set: WorkoutSet) -> LocalWorkoutSet {
        LocalWorkoutSet(
            id: set.id,
            sessionId: set.sessionId,
            exerciseId: set.exerciseId,
            setNumber: set.setNumber,
            reps: set.reps,
            weight: set.weight,
            durationSeconds: set.durationSeconds,
            completed: set.completed,
            orderIndex: set.orderIndex,
            createdAt: set.createdAt,
            needsSync: false,
            syncedAt: Date()
        )
    }
}
