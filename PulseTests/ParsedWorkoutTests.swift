//
//  ParsedWorkoutTests.swift
//  PulseTests
//

import XCTest
@testable import Pulse

@MainActor
final class ParsedWorkoutTests: XCTestCase {

    // MARK: - ParsedWorkout Decoding

    func testParsedWorkoutDecodesFromJSON() throws {
        let json = """
        {
            "routine_name": "Push Day",
            "duration_minutes": 60,
            "exercises": [
                {
                    "name": "Bench Press",
                    "sets": 4,
                    "reps": 8,
                    "weight_kg": 80.0,
                    "exercise_type": "strength",
                    "confidence": "high",
                    "note": "Felt strong"
                }
            ]
        }
        """.data(using: .utf8)!

        let workout = try JSONDecoder().decode(ParsedWorkout.self, from: json)

        XCTAssertEqual(workout.routineName, "Push Day")
        XCTAssertEqual(workout.durationMinutes, 60)
        XCTAssertEqual(workout.exercises.count, 1)
        XCTAssertEqual(workout.exercises[0].name, "Bench Press")
        XCTAssertEqual(workout.exercises[0].sets, 4)
        XCTAssertEqual(workout.exercises[0].reps, 8)
        XCTAssertEqual(workout.exercises[0].weightKg, 80.0)
        XCTAssertEqual(workout.exercises[0].confidence, .high)
        XCTAssertEqual(workout.exercises[0].note, "Felt strong")
    }

    func testParsedWorkoutDecodesWithNullOptionals() throws {
        let json = """
        {
            "routine_name": null,
            "duration_minutes": null,
            "exercises": [
                {
                    "name": "Running",
                    "sets": 1,
                    "reps": null,
                    "weight_kg": null,
                    "duration_seconds": 1800,
                    "exercise_type": "cardio",
                    "confidence": "medium",
                    "note": null
                }
            ]
        }
        """.data(using: .utf8)!

        let workout = try JSONDecoder().decode(ParsedWorkout.self, from: json)

        XCTAssertNil(workout.routineName)
        XCTAssertNil(workout.durationMinutes)
        XCTAssertEqual(workout.exercises[0].name, "Running")
        XCTAssertNil(workout.exercises[0].reps)
        XCTAssertNil(workout.exercises[0].weightKg)
        XCTAssertEqual(workout.exercises[0].durationSeconds, 1800)
        XCTAssertTrue(workout.exercises[0].isCardio)
    }

    func testParsedWorkoutMultipleExercises() throws {
        let json = """
        {
            "routine_name": "Full Body",
            "duration_minutes": 45,
            "exercises": [
                {"name": "Squat", "sets": 3, "reps": 10, "weight_kg": 100, "confidence": "high"},
                {"name": "Bench Press", "sets": 3, "reps": 8, "weight_kg": 80, "confidence": "high"},
                {"name": "Deadlift", "sets": 3, "reps": 5, "weight_kg": 120, "confidence": "medium"}
            ]
        }
        """.data(using: .utf8)!

        let workout = try JSONDecoder().decode(ParsedWorkout.self, from: json)
        XCTAssertEqual(workout.exercises.count, 3)
        XCTAssertEqual(workout.exercises[0].name, "Squat")
        XCTAssertEqual(workout.exercises[2].confidence, .medium)
    }

    // MARK: - ParsedExercise.isCardio

    func testIsCardioTrueForCardioType() {
        let exercise = ParsedExercise(name: "Running", sets: 1, reps: nil, weightKg: nil, durationSeconds: 1800, exerciseType: "cardio", confidence: .high, note: nil)
        XCTAssertTrue(exercise.isCardio)
    }

    func testIsCardioFalseForStrengthType() {
        let exercise = ParsedExercise(name: "Bench Press", sets: 4, reps: 8, weightKg: 80, exerciseType: "strength", confidence: .high, note: nil)
        XCTAssertFalse(exercise.isCardio)
    }

    func testIsCardioFalseForNilType() {
        let exercise = ParsedExercise(name: "Custom", sets: 3, reps: 10, weightKg: nil, exerciseType: nil, confidence: .low, note: nil)
        XCTAssertFalse(exercise.isCardio)
    }

    // MARK: - ParsedExercise.isBodyweight / tracksWeight

    func testIsBodyweightTrueForBodyweightType() {
        let exercise = ParsedExercise(name: "Push Ups", sets: 3, reps: 15, weightKg: nil, exerciseType: "bodyweight", confidence: .high, note: nil)
        XCTAssertTrue(exercise.isBodyweight)
        XCTAssertFalse(exercise.isCardio)
        XCTAssertFalse(exercise.tracksWeight)
    }

    func testIsBodyweightFalseForStrengthType() {
        let exercise = ParsedExercise(name: "Bench Press", sets: 4, reps: 8, weightKg: 80, exerciseType: "strength", confidence: .high, note: nil)
        XCTAssertFalse(exercise.isBodyweight)
        XCTAssertTrue(exercise.tracksWeight)
    }

    func testTracksWeightOnlyForStrength() {
        let strength = ParsedExercise(name: "Squat", sets: 3, reps: 5, weightKg: 100, exerciseType: "strength", confidence: .high, note: nil)
        let bodyweight = ParsedExercise(name: "Pull Up", sets: 3, reps: 10, weightKg: nil, exerciseType: "bodyweight", confidence: .high, note: nil)
        let cardio = ParsedExercise(name: "Running", sets: 1, reps: nil, weightKg: nil, durationSeconds: 1800, exerciseType: "cardio", confidence: .high, note: nil)
        let unknown = ParsedExercise(name: "Other", sets: 1, reps: 10, weightKg: nil, exerciseType: nil, confidence: .low, note: nil)

        XCTAssertTrue(strength.tracksWeight)
        XCTAssertFalse(bodyweight.tracksWeight)
        XCTAssertFalse(cardio.tracksWeight)
        XCTAssertFalse(unknown.tracksWeight)
    }

    func testParsedExerciseDecodesBodyweightType() throws {
        let json = """
        {
            "name": "Push Ups",
            "sets": 3,
            "reps": 15,
            "weight_kg": null,
            "exercise_type": "bodyweight",
            "confidence": "high"
        }
        """.data(using: .utf8)!

        let exercise = try JSONDecoder().decode(ParsedExercise.self, from: json)
        XCTAssertEqual(exercise.exerciseType, "bodyweight")
        XCTAssertTrue(exercise.isBodyweight)
        XCTAssertFalse(exercise.tracksWeight)
        XCTAssertNil(exercise.weightKg)
        XCTAssertEqual(exercise.reps, 15)
    }

    func testParsedRoutineExerciseBodyweightHelpers() {
        let bodyweight = ParsedRoutineExercise(name: "Plank", sets: 3, repsTarget: "60", targetWeight: nil, exerciseType: "bodyweight", restSeconds: 30, confidence: .high, note: nil)
        XCTAssertTrue(bodyweight.isBodyweight)
        XCTAssertFalse(bodyweight.isCardio)
        XCTAssertFalse(bodyweight.tracksWeight)
    }

    func testParsedRoutineExerciseDecodesBodyweightType() throws {
        let json = """
        {
            "name": "Pull Ups",
            "sets": 4,
            "reps_target": "8-10",
            "target_weight": null,
            "exercise_type": "bodyweight",
            "rest_seconds": 90,
            "confidence": "high"
        }
        """.data(using: .utf8)!

        let exercise = try JSONDecoder().decode(ParsedRoutineExercise.self, from: json)
        XCTAssertEqual(exercise.exerciseType, "bodyweight")
        XCTAssertTrue(exercise.isBodyweight)
        XCTAssertFalse(exercise.tracksWeight)
        XCTAssertNil(exercise.targetWeight)
        XCTAssertEqual(exercise.repsTarget, "8-10")
    }

    // MARK: - ParsedExercise generates local UUID when missing

    func testParsedExerciseGeneratesIdWhenMissing() throws {
        let json = """
        {
            "name": "Squat",
            "sets": 3,
            "reps": 10,
            "confidence": "high"
        }
        """.data(using: .utf8)!

        let exercise = try JSONDecoder().decode(ParsedExercise.self, from: json)
        // id should be a valid UUID (auto-generated)
        XCTAssertFalse(exercise.id.uuidString.isEmpty)
        XCTAssertEqual(exercise.name, "Squat")
    }

    // MARK: - ParsedRoutine Decoding

    func testParsedRoutineDecodesFromJSON() throws {
        let json = """
        {
            "routine_name": "Upper Body Push",
            "description": "Focus on chest and shoulders",
            "exercises": [
                {
                    "name": "Bench Press",
                    "sets": 4,
                    "reps_target": "8-10",
                    "target_weight": 80.0,
                    "rest_seconds": 90,
                    "exercise_type": "strength",
                    "confidence": "high"
                }
            ]
        }
        """.data(using: .utf8)!

        let routine = try JSONDecoder().decode(ParsedRoutine.self, from: json)

        XCTAssertEqual(routine.routineName, "Upper Body Push")
        XCTAssertEqual(routine.description, "Focus on chest and shoulders")
        XCTAssertEqual(routine.exercises.count, 1)
        XCTAssertEqual(routine.exercises[0].repsTarget, "8-10")
        XCTAssertEqual(routine.exercises[0].targetWeight, 80.0)
        XCTAssertEqual(routine.exercises[0].restSeconds, 90)
    }

    func testParsedRoutineExerciseDefaultsRestTo60() throws {
        let json = """
        {
            "name": "Squat",
            "sets": 3,
            "confidence": "medium"
        }
        """.data(using: .utf8)!

        let exercise = try JSONDecoder().decode(ParsedRoutineExercise.self, from: json)
        XCTAssertEqual(exercise.restSeconds, 60) // default
    }

    // MARK: - ParseResponse Decoding

    func testParseResponseDecodesSuccess() throws {
        let json = """
        {
            "success": true,
            "data": {
                "routine_name": "Test",
                "exercises": [
                    {"name": "Squat", "sets": 3, "reps": 10, "confidence": "high"}
                ]
            },
            "usage": {"calls_today": 1, "limit": 10}
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ParseResponse.self, from: json)
        XCTAssertEqual(response.success, true)
        XCTAssertNotNil(response.data)
        XCTAssertEqual(response.usage?.callsToday, 1)
        XCTAssertEqual(response.usage?.limit, 10)
    }

    func testParseResponseDecodesError() throws {
        let json = """
        {
            "success": false,
            "data": null,
            "error": "off_topic",
            "message": "Describe your workout"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ParseResponse.self, from: json)
        XCTAssertEqual(response.success, false)
        XCTAssertNil(response.data)
        XCTAssertEqual(response.message, "Describe your workout")
    }

    // MARK: - ParserError descriptions

    func testParserErrorDescriptions() {
        XCTAssertEqual(ParserError.offTopic("test").errorDescription, "test")
        XCTAssertEqual(ParserError.rateLimitExceeded("wait").errorDescription, "wait")
        XCTAssertEqual(ParserError.upgradeRequired.errorDescription, "AI features are available on Pro and Coach plans.")
        XCTAssertEqual(ParserError.unauthorized.errorDescription, "Please sign in to use this feature.")
        XCTAssertEqual(ParserError.unknown.errorDescription, "Something went wrong. Please try again.")
    }
}
