//
//  AggregateStats.swift
//  Pulse
//
//  Codable structs for server-side RPC aggregate stat responses.
//

import Foundation

/// Response from `refresh_user_streak` RPC
struct UserStreak: Codable {
    let currentStreak: Int
    let bestStreak: Int
    let weekCompleted: Bool
    let workoutsThisWeek: Int
    let workoutsRequired: Int

    enum CodingKeys: String, CodingKey {
        case currentStreak = "current_streak"
        case bestStreak = "best_streak"
        case weekCompleted = "week_completed"
        case workoutsThisWeek = "workouts_this_week"
        case workoutsRequired = "workouts_required"
    }
}

/// Response from `get_dashboard_stats` RPC
struct DashboardStats: Codable {
    let currentStreak: Int
    let bestStreak: Int
    let totalWorkoutCount: Int
    let weeklyWorkoutMinutes: Int
    let latestPrExerciseName: String?
    let latestPrWeight: Double?
    let latestPrReps: Int?
    let latestPrDate: Date?

    enum CodingKeys: String, CodingKey {
        case currentStreak = "current_streak"
        case bestStreak = "best_streak"
        case totalWorkoutCount = "total_workout_count"
        case weeklyWorkoutMinutes = "weekly_workout_minutes"
        case latestPrExerciseName = "latest_pr_exercise_name"
        case latestPrWeight = "latest_pr_weight"
        case latestPrReps = "latest_pr_reps"
        case latestPrDate = "latest_pr_date"
    }
}

/// Response from `get_progress_stats` RPC
struct ProgressStats: Codable {
    let weeklyVolume: Int
    let monthlyVolume: Int
    let monthlyWorkouts: Int
    let avgDurationMinutes: Int
    let lastMonthVolume: Int
    let lastMonthWorkouts: Int
    let lastMonthAvgDuration: Int
    let lifetimeWorkouts: Int
    let lifetimeVolume: Int
    let lifetimeHours: Int
    let currentStreak: Int
    let bestStreak: Int
    let improvingExerciseCount: Int
    let weeklyDurationMinutes: Int
    let weeklyWorkouts: Int?
    let lastWeekVolume: Int?
    let lastWeekWorkouts: Int?
    let lastWeekDurationMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case weeklyVolume = "weekly_volume"
        case monthlyVolume = "monthly_volume"
        case monthlyWorkouts = "monthly_workouts"
        case avgDurationMinutes = "avg_duration_minutes"
        case lastMonthVolume = "last_month_volume"
        case lastMonthWorkouts = "last_month_workouts"
        case lastMonthAvgDuration = "last_month_avg_duration"
        case lifetimeWorkouts = "lifetime_workouts"
        case lifetimeVolume = "lifetime_volume"
        case lifetimeHours = "lifetime_hours"
        case currentStreak = "current_streak"
        case bestStreak = "best_streak"
        case improvingExerciseCount = "improving_exercise_count"
        case weeklyDurationMinutes = "weekly_duration_minutes"
        case weeklyWorkouts = "weekly_workouts"
        case lastWeekVolume = "last_week_volume"
        case lastWeekWorkouts = "last_week_workouts"
        case lastWeekDurationMinutes = "last_week_duration_minutes"
    }
}

/// Row from `get_muscle_group_stats` RPC
struct MuscleGroupStatRow: Codable {
    let name: String
    let sets: Int
    let percentage: Double
}

/// Row from `get_exercise_1rm_stats` RPC
struct Exercise1RMRow: Codable, Identifiable {
    var id: UUID { exerciseId }
    let exerciseId: UUID
    let exerciseName: String
    let bestEstimated1rm: Double
    let bestWeight: Double
    let bestReps: Int
    let achievedAt: Date
    let latestEstimated1rm: Double?
    let latestWeight: Double?
    let latestReps: Int?
    let latestRecordedAt: Date?

    enum CodingKeys: String, CodingKey {
        case exerciseId = "exercise_id"
        case exerciseName = "exercise_name"
        case bestEstimated1rm = "best_estimated_1rm"
        case bestWeight = "best_weight"
        case bestReps = "best_reps"
        case achievedAt = "achieved_at"
        case latestEstimated1rm = "latest_estimated_1rm"
        case latestWeight = "latest_weight"
        case latestReps = "latest_reps"
        case latestRecordedAt = "latest_recorded_at"
    }
}

/// Row from `get_exercise_1rm_history` RPC
struct Exercise1RMHistoryRow: Codable, Identifiable {
    let id: UUID
    let estimated1rm: Double
    let weight: Double
    let reps: Int
    let recordedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case estimated1rm = "estimated_1rm"
        case weight
        case reps
        case recordedAt = "recorded_at"
    }
}

/// Response from `update_exercise_1rm` RPC
struct Update1RMResponse: Sendable {
    let isNewPr: Bool
    let estimated1rm: Double?
    let previousBest: Double?

    enum CodingKeys: String, CodingKey {
        case isNewPr = "is_new_pr"
        case estimated1rm = "estimated_1rm"
        case previousBest = "previous_best"
    }
}

extension Update1RMResponse: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isNewPr = try container.decodeIfPresent(Bool.self, forKey: .isNewPr) ?? false
        estimated1rm = try container.decodeIfPresent(Double.self, forKey: .estimated1rm)
        previousBest = try container.decodeIfPresent(Double.self, forKey: .previousBest)
    }
}

/// A 1RM highlight for display on the workout summary screen.
struct Strength1RMHighlight: Identifiable {
    let id: UUID
    let exerciseName: String
    let estimated1rm: Double
    let isNewPr: Bool
    let previousBest: Double
}

/// Row from `get_strength_progress` RPC
struct StrengthProgressRow: Codable {
    let exerciseName: String
    let bestWeight: Double
    let lastWeight: Double
    let firstWeight: Double
    let improvementPercent: Double

    enum CodingKeys: String, CodingKey {
        case exerciseName = "exercise_name"
        case bestWeight = "best_weight"
        case lastWeight = "last_weight"
        case firstWeight = "first_weight"
        case improvementPercent = "improvement_percent"
    }
}
