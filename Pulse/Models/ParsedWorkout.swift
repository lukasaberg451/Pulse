//
//  ParsedWorkout.swift
//  Pulse
//

import Foundation

// MARK: - Parsed Workout Models

struct ParsedWorkout: Codable {
    let routineName: String?
    let durationMinutes: Int?
    var exercises: [ParsedExercise]
    
    enum CodingKeys: String, CodingKey {
        case routineName = "routine_name"
        case durationMinutes = "duration_minutes"
        case exercises
    }
}

struct ParsedExercise: Codable, Identifiable {
    var id: UUID
    var name: String
    var sets: Int
    var reps: Int?
    var weightKg: Double?
    var durationSeconds: Int?
    var exerciseType: String?
    var confidence: Confidence
    var note: String?
    
    var isCardio: Bool {
        exerciseType == "cardio"
    }
    
    enum Confidence: String, Codable {
        case high
        case medium
        case low
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case sets
        case reps
        case weight_kg
        case duration_seconds
        case exercise_type
        case confidence
        case note
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // The edge function won't send an id - generate one locally
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.sets = try container.decode(Int.self, forKey: .sets)
        self.reps = try container.decodeIfPresent(Int.self, forKey: .reps)
        self.weightKg = try container.decodeIfPresent(Double.self, forKey: .weight_kg)
        self.durationSeconds = try container.decodeIfPresent(Int.self, forKey: .duration_seconds)
        self.exerciseType = try container.decodeIfPresent(String.self, forKey: .exercise_type)
        self.confidence = try container.decode(Confidence.self, forKey: .confidence)
        self.note = try container.decodeIfPresent(String.self, forKey: .note)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(sets, forKey: .sets)
        try container.encodeIfPresent(reps, forKey: .reps)
        try container.encodeIfPresent(weightKg, forKey: .weight_kg)
        try container.encodeIfPresent(durationSeconds, forKey: .duration_seconds)
        try container.encodeIfPresent(exerciseType, forKey: .exercise_type)
        try container.encode(confidence, forKey: .confidence)
        try container.encodeIfPresent(note, forKey: .note)
    }
    
    init(id: UUID = UUID(), name: String, sets: Int, reps: Int?, weightKg: Double?, durationSeconds: Int? = nil, exerciseType: String? = "strength", confidence: Confidence, note: String?) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.weightKg = weightKg
        self.durationSeconds = durationSeconds
        self.exerciseType = exerciseType
        self.confidence = confidence
        self.note = note
    }
}

// MARK: - Parsed Routine Models

struct ParsedRoutine: Codable {
    let routineName: String
    let description: String?
    var exercises: [ParsedRoutineExercise]
    
    enum CodingKeys: String, CodingKey {
        case routineName = "routine_name"
        case description
        case exercises
    }
}

struct ParsedRoutineExercise: Codable, Identifiable {
    var id: UUID
    var name: String
    var sets: Int
    var repsTarget: String?
    var targetWeight: Double?
    var durationSeconds: Int?
    var exerciseType: String?
    var restSeconds: Int
    var confidence: ParsedExercise.Confidence
    var note: String?
    
    var isCardio: Bool {
        exerciseType == "cardio"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case sets
        case reps_target
        case target_weight
        case duration_seconds
        case exercise_type
        case rest_seconds
        case confidence
        case note
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.sets = try container.decode(Int.self, forKey: .sets)
        self.repsTarget = try container.decodeIfPresent(String.self, forKey: .reps_target)
        self.targetWeight = try container.decodeIfPresent(Double.self, forKey: .target_weight)
        self.durationSeconds = try container.decodeIfPresent(Int.self, forKey: .duration_seconds)
        self.exerciseType = try container.decodeIfPresent(String.self, forKey: .exercise_type)
        self.restSeconds = (try? container.decode(Int.self, forKey: .rest_seconds)) ?? 60
        self.confidence = try container.decode(ParsedExercise.Confidence.self, forKey: .confidence)
        self.note = try container.decodeIfPresent(String.self, forKey: .note)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(sets, forKey: .sets)
        try container.encodeIfPresent(repsTarget, forKey: .reps_target)
        try container.encodeIfPresent(targetWeight, forKey: .target_weight)
        try container.encodeIfPresent(durationSeconds, forKey: .duration_seconds)
        try container.encodeIfPresent(exerciseType, forKey: .exercise_type)
        try container.encode(restSeconds, forKey: .rest_seconds)
        try container.encode(confidence, forKey: .confidence)
        try container.encodeIfPresent(note, forKey: .note)
    }
    
    init(id: UUID = UUID(), name: String, sets: Int, repsTarget: String?, targetWeight: Double?, durationSeconds: Int? = nil, exerciseType: String? = "strength", restSeconds: Int = 60, confidence: ParsedExercise.Confidence, note: String?) {
        self.id = id
        self.name = name
        self.sets = sets
        self.repsTarget = repsTarget
        self.targetWeight = targetWeight
        self.durationSeconds = durationSeconds
        self.exerciseType = exerciseType
        self.restSeconds = restSeconds
        self.confidence = confidence
        self.note = note
    }
}

// MARK: - API Response Models

struct ParseResponse: Codable {
    let success: Bool?
    let data: ParsedWorkout?
    let error: String?
    let message: String?
    let usage: UsageInfo?
}

struct ParseRoutineResponse: Codable {
    let success: Bool?
    let data: ParsedRoutine?
    let error: String?
    let message: String?
    let usage: UsageInfo?
}

struct UsageInfo: Codable {
    let callsToday: Int
    let limit: Int
    
    enum CodingKeys: String, CodingKey {
        case callsToday = "calls_today"
        case limit
    }
}
