//
//  WorkoutSessionTests.swift
//  PulseTests
//
//  Created by Lukas Åberg on 2026-03-20.
//

import XCTest
@testable import Pulse

@MainActor
final class WorkoutSessionTests: XCTestCase {

    // MARK: - WorkoutSession JSON Decoding

    func testWorkoutSessionDecodesFromJSON() throws {
        let json = """
        {
            "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
            "user_id": "B1B2C3D4-E5F6-7890-ABCD-EF1234567890",
            "routine_id": "C1B2C3D4-E5F6-7890-ABCD-EF1234567890",
            "name": "Push Day",
            "started_at": "2026-03-20T10:00:00Z",
            "completed_at": "2026-03-20T11:00:00Z",
            "duration_seconds": 3600,
            "notes": "Felt strong",
            "created_at": "2026-03-20T10:00:00Z",
            "routine_deleted": false
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let session = try decoder.decode(WorkoutSession.self, from: json)

        XCTAssertEqual(session.name, "Push Day")
        XCTAssertEqual(session.durationSeconds, 3600)
        XCTAssertEqual(session.notes, "Felt strong")
        XCTAssertNotNil(session.completedAt)
        XCTAssertEqual(session.routineDeleted, false)
    }

    func testWorkoutSessionDecodesWithNullOptionals() throws {
        let json = """
        {
            "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
            "user_id": "B1B2C3D4-E5F6-7890-ABCD-EF1234567890",
            "routine_id": null,
            "name": "Quick Workout",
            "started_at": "2026-03-20T10:00:00Z",
            "completed_at": null,
            "duration_seconds": null,
            "notes": null,
            "created_at": "2026-03-20T10:00:00Z",
            "routine_deleted": null
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let session = try decoder.decode(WorkoutSession.self, from: json)

        XCTAssertEqual(session.name, "Quick Workout")
        XCTAssertNil(session.routineId)
        XCTAssertNil(session.completedAt)
        XCTAssertNil(session.durationSeconds)
        XCTAssertNil(session.notes)
        XCTAssertNil(session.routineDeleted)
    }

    // MARK: - WorkoutSet JSON Decoding

    func testWorkoutSetDecodesStrengthSet() throws {
        let json = """
        {
            "id": "D1B2C3D4-E5F6-7890-ABCD-EF1234567890",
            "session_id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
            "exercise_id": "E1B2C3D4-E5F6-7890-ABCD-EF1234567890",
            "set_number": 1,
            "reps": 10,
            "weight": 80.0,
            "duration_seconds": null,
            "completed": true,
            "order_index": 0,
            "created_at": "2026-03-20T10:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let set = try decoder.decode(WorkoutSet.self, from: json)

        XCTAssertEqual(set.setNumber, 1)
        XCTAssertEqual(set.reps, 10)
        XCTAssertEqual(set.weight, 80.0)
        XCTAssertNil(set.durationSeconds)
        XCTAssertTrue(set.completed)
    }

    func testWorkoutSetDecodesCardioSet() throws {
        let json = """
        {
            "id": "D1B2C3D4-E5F6-7890-ABCD-EF1234567890",
            "session_id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
            "exercise_id": "E1B2C3D4-E5F6-7890-ABCD-EF1234567890",
            "set_number": 1,
            "reps": null,
            "weight": null,
            "duration_seconds": 1800,
            "completed": true,
            "order_index": 0,
            "created_at": "2026-03-20T10:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let set = try decoder.decode(WorkoutSet.self, from: json)

        XCTAssertNil(set.reps)
        XCTAssertNil(set.weight)
        XCTAssertEqual(set.durationSeconds, 1800)
    }

    // MARK: - Exercise JSON Decoding

    func testExerciseDecodesFromJSON() throws {
        let json = """
        {
            "id": "F1B2C3D4-E5F6-7890-ABCD-EF1234567890",
            "name": "Bench Press",
            "description": "Flat barbell bench press",
            "muscle_group": "Chest",
            "secondary_muscle_group": "Triceps",
            "equipment": "Barbell",
            "instructions": "Lie flat on bench",
            "exercise_type": "strength",
            "difficulty": "intermediate",
            "created_by": null,
            "created_at": "2026-01-01T00:00:00Z",
            "is_custom": false
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exercise = try decoder.decode(Exercise.self, from: json)

        XCTAssertEqual(exercise.name, "Bench Press")
        XCTAssertEqual(exercise.muscleGroup, "Chest")
        XCTAssertEqual(exercise.secondaryMuscleGroup, "Triceps")
        XCTAssertEqual(exercise.equipment, "Barbell")
        XCTAssertEqual(exercise.exerciseType, "strength")
        XCTAssertEqual(exercise.isCustom, false)
    }

    // MARK: - Routine Equality

    func testRoutineEqualityById() {
        let id = UUID()
        let r1 = Routine(id: id, userId: UUID(), name: "A", description: nil, createdAt: Date())
        let r2 = Routine(id: id, userId: UUID(), name: "B", description: "desc", createdAt: Date())
        XCTAssertEqual(r1, r2, "Routines with the same id should be equal")
    }

    func testRoutineInequalityByDifferentId() {
        let r1 = Routine(id: UUID(), userId: UUID(), name: "Same", description: nil, createdAt: Date())
        let r2 = Routine(id: UUID(), userId: UUID(), name: "Same", description: nil, createdAt: Date())
        XCTAssertNotEqual(r1, r2)
    }

    // MARK: - ScheduledWorkout Date Parsing

    func testScheduledWorkoutDateParsing() {
        let sw = ScheduledWorkout(
            id: UUID(),
            userId: UUID(),
            routineId: nil,
            scheduledDate: "2026-04-15",
            completed: false,
            workoutSessionId: nil,
            notes: nil,
            createdAt: Date(),
            routineDeleted: nil
        )

        let tz = TimeZone(identifier: "UTC")!
        let date = sw.date(in: tz)
        XCTAssertNotNil(date)

        let calendar = Calendar.current
        var cal = calendar
        cal.timeZone = tz
        let components = cal.dateComponents([.year, .month, .day], from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 4)
        XCTAssertEqual(components.day, 15)
    }
}
