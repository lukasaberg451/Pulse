//
//  AggregateStats.swift
//  Pulse
//
//  Codable structs for server-side RPC aggregate stat responses.
//

import Foundation

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
    }
}

/// Row from `get_muscle_group_stats` RPC
struct MuscleGroupStatRow: Codable {
    let name: String
    let sets: Int
    let percentage: Double
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
