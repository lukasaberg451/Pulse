//
//  SmartInsight.swift
//  Pulse
//

import Foundation
import SwiftUI

struct SmartInsight: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let iconAsset: String
    let priority: Int // higher = more important
}

// MARK: - Smart Insight Engine

enum SmartInsightEngine {
    
    private static let upperBodyGroups: Set<String> = [
        "chest", "back", "shoulders", "delts", "biceps", "triceps", "forearms", "abs", "core", "lats"
    ]

    private static let lowerBodyGroups: Set<String> = [
        "legs", "quadriceps", "quads", "hamstrings", "glutes", "calves", "adductors", "hips"
    ]
    
    /// Generates insights from already-loaded progress stats.
    /// Returns insights sorted by priority (highest first).
    static func generateInsights(
        userStreak: UserStreak?,
        previousWeekStreak: Int,
        monthlyWorkouts: Int,
        lastMonthWorkouts: Int,
        weeklyVolume: Int,
        weeklyWorkouts: Int?,
        lastWeekWorkouts: Int?,
        monthlyVolume: Int,
        lastMonthVolume: Int,
        avgDuration: Int,
        muscleGroupNames: [String],
        topMuscleGroupName: String?,
        topMuscleGroupPercentage: Double,
        muscleGroupCount: Int,
        improvingExerciseCount: Int,
        recentPRCount: Int,
        daysSinceLastWorkout: Int?,
        lifetimeWorkouts: Int,
        weekdayIndex: Int,
        dayOfMonth: Int
    ) -> [SmartInsight] {
        var insights: [SmartInsight] = []
        
        let currentStreak = userStreak?.currentStreak ?? 0
        let bestStreak = userStreak?.bestStreak ?? 0
        let workoutsThisWeek = userStreak?.workoutsThisWeek ?? 0
        let workoutsRequired = userStreak?.workoutsRequired ?? 3
        let weekCompleted = userStreak?.weekCompleted ?? false

        // 1. Week goal completed — celebrate
        if weekCompleted {
            insights.append(SmartInsight(
                title: String(localized: "Week Goal Smashed"),
                message: String(localized: "You hit your target of \(workoutsRequired) workouts this week. Consistency like this is what drives real results. Enjoy the rest of the week or keep pushing!"),
                iconAsset: "trophy",
                priority: 88
            ))
        }

        // 2. High training frequency this week — suggest rest
        if workoutsThisWeek >= 5 {
            insights.append(SmartInsight(
                title: String(localized: "Recovery Matters"),
                message: String(localized: "You've trained \(workoutsThisWeek) times this week. Muscle tissue repairs and grows during rest, scheduling a recovery day can actually accelerate your progress."),
                iconAsset: "moon",
                priority: 90
            ))
        }

        // 3. Inactivity — encourage return
        if let daysSince = daysSinceLastWorkout, daysSince >= 4 {
            insights.append(SmartInsight(
                title: String(localized: "Time to Get Back"),
                message: String(localized: "It's been \(daysSince) days since your last session. Strength can decline after 72 hours of inactivity. Even a light workout helps maintain your gains."),
                iconAsset: "flame",
                priority: 95
            ))
        } else if lifetimeWorkouts == 0 {
            insights.append(SmartInsight(
                title: String(localized: "Start Your Journey"),
                message: String(localized: "Complete your first workout to unlock personalized training insights based on your activity."),
                iconAsset: "flame",
                priority: 100
            ))
        }

        // 4. Almost there — one workout away from completing weekly goal
        if !weekCompleted && workoutsThisWeek == workoutsRequired - 1 && workoutsRequired > 1 {
            let remaining = workoutsRequired - workoutsThisWeek
            insights.append(SmartInsight(
                title: String(localized: "Almost There"),
                message: currentStreak > 0
                    ? String(localized: "Just \(remaining) more workout to keep your \(currentStreak)-week streak alive. You've got this!")
                    : String(localized: "Just \(remaining) more workout this week to hit your goal and start building a streak."),
                iconAsset: "flame",
                priority: 83
            ))
        }

        // 5. Monthly workout frequency increase (skip first week — not enough data)
        if dayOfMonth >= 8 && lastMonthWorkouts > 0 && monthlyWorkouts > lastMonthWorkouts {
            let increase = Int(Double(monthlyWorkouts - lastMonthWorkouts) / Double(lastMonthWorkouts) * 100)
            if increase >= 20 {
                insights.append(SmartInsight(
                    title: String(localized: "Consistency Pays Off"),
                    message: String(localized: "You've completed \(monthlyWorkouts) workouts this month vs \(lastMonthWorkouts) last month. Consistency is the strongest predictor of long-term strength gains."),
                    iconAsset: "progressup",
                    priority: 75
                ))
            }
        }

        // 6. Monthly workout frequency decrease (skip first week — not enough data)
        if dayOfMonth >= 8 && lastMonthWorkouts > 0 && monthlyWorkouts < lastMonthWorkouts {
            let decrease = Int(Double(lastMonthWorkouts - monthlyWorkouts) / Double(lastMonthWorkouts) * 100)
            if decrease >= 30 {
                insights.append(SmartInsight(
                    title: String(localized: "Dropping Off?"),
                    message: String(localized: "Your workout count is down from \(lastMonthWorkouts) last month to \(monthlyWorkouts) so far. Training at least 2–3 times per week is enough to maintain and build strength."),
                    iconAsset: "progressup",
                    priority: 80
                ))
            }
        }

        // 7. Volume progressive overload (skip first week — not enough data)
        if dayOfMonth >= 8 && lastMonthVolume > 0 && monthlyVolume > lastMonthVolume {
            let increase = Int(Double(monthlyVolume - lastMonthVolume) / Double(lastMonthVolume) * 100)
            if increase >= 10 {
                let formattedIncrease = (Double(increase) / 100).formatted(.percent)
                insights.append(SmartInsight(
                    title: String(localized: "Volume Is Climbing"),
                    message: String(localized: "Your training volume is up \(formattedIncrease) from last month. Gradual progressive overload is the primary driver of muscle hypertrophy."),
                    iconAsset: "scale",
                    priority: 70
                ))
            }
        }

        // 8. Volume declining (skip first week — not enough data)
        if dayOfMonth >= 8 && lastMonthVolume > 0 && monthlyVolume < lastMonthVolume {
            let decrease = Int(Double(lastMonthVolume - monthlyVolume) / Double(lastMonthVolume) * 100)
            if decrease >= 20 {
                let formattedDecrease = (Double(decrease) / 100).formatted(.percent)
                insights.append(SmartInsight(
                    title: String(localized: "Volume Dipping"),
                    message: String(localized: "Your training volume is down \(formattedDecrease) from last month. If you're deloading intentionally that's great, otherwise try to maintain or gradually increase load."),
                    iconAsset: "scale",
                    priority: 58
                ))
            }
        }

        // 9. Muscle imbalance — one group dominates (need enough workouts for meaningful distribution)
        if let topName = topMuscleGroupName, topMuscleGroupPercentage > 0.40 && muscleGroupCount >= 2 && monthlyWorkouts >= 4 {
            let formattedPct = topMuscleGroupPercentage.formatted(.percent.precision(.fractionLength(0)))
            insights.append(SmartInsight(
                title: String(localized: "Balance Your Training"),
                message: String(localized: "\(topName) makes up \(formattedPct) of your sets this month. Uneven training can create strength imbalances. Consider adding work for opposing muscle groups."),
                iconAsset: "scale",
                priority: 65
            ))
        }

        // 10. Too few muscle groups
        if muscleGroupCount == 1 && monthlyWorkouts >= 3, let topName = topMuscleGroupName {
            insights.append(SmartInsight(
                title: String(localized: "Add Some Variety"),
                message: String(localized: "You've only trained \(topName) this month. Full-body balance reduces injury risk and improves overall functional strength."),
                iconAsset: "strengthtraining",
                priority: 60
            ))
        }

        // 11. All upper body, no lower body
        if muscleGroupCount >= 2 && monthlyWorkouts >= 3 {
            let lowerNames = muscleGroupNames.map { $0.lowercased() }
            let hasLower = lowerNames.contains { lowerBodyGroups.contains($0) }
            let hasUpper = lowerNames.contains { upperBodyGroups.contains($0) }
            if hasUpper && !hasLower {
                insights.append(SmartInsight(
                    title: String(localized: "Don't Neglect Your Legs"),
                    message: String(localized: "All your training this month targets upper body. Lower-body exercises like squats and deadlifts boost testosterone, burn more calories, and prevent muscular imbalances."),
                    iconAsset: "strengthtraining",
                    priority: 63
                ))
            }
        }

        // 12. Long session duration
        if avgDuration > 90 && monthlyWorkouts >= 2 {
            insights.append(SmartInsight(
                title: String(localized: "Quality Over Quantity"),
                message: String(localized: "Your average session is \(avgDuration) minutes. Research shows diminishing returns after 60–75 minutes as cortisol rises. Consider higher-intensity, shorter sessions."),
                iconAsset: "stopwatch",
                priority: 55
            ))
        }

        // 13. Short session duration
        if avgDuration > 0 && avgDuration < 20 && monthlyWorkouts >= 3 {
            insights.append(SmartInsight(
                title: String(localized: "Make Each Session Count"),
                message: String(localized: "Your average session is \(avgDuration) minutes. Sessions under 20 minutes may not provide enough stimulus. Aim for at least 30–45 minutes to maximize your results."),
                iconAsset: "stopwatch",
                priority: 52
            ))
        }

        // 14. Recent PRs this week
        if recentPRCount >= 1 {
            insights.append(SmartInsight(
                title: recentPRCount == 1
                    ? String(localized: "New Personal Record")
                    : String(localized: "PRs Rolling In"),
                message: recentPRCount == 1
                    ? String(localized: "You set a new estimated 1RM record this week. Progressive overload in action — keep challenging yourself.")
                    : String(localized: "You've hit \(recentPRCount) new 1RM records this week. Your training is clearly paying off."),
                iconAsset: "trophy",
                priority: 76
            ))
        }

        // 15. Strength PR momentum
        if improvingExerciseCount >= 3 {
            insights.append(SmartInsight(
                title: String(localized: "Strength Trending Up"),
                message: String(localized: "You've improved on \(improvingExerciseCount) exercises since you started. Keep following progressive overload principles to sustain these gains."),
                iconAsset: "trophy",
                priority: 68
            ))
        }

        // 16. Best streak achievement (weekly)
        if currentStreak > 0 && currentStreak >= bestStreak && bestStreak >= 3 {
            insights.append(SmartInsight(
                title: String(localized: "New Personal Best"),
                message: String(localized: "You're on your longest streak ever at \(currentStreak) weeks. Building a training habit is the foundation of lasting results."),
                iconAsset: "flame",
                priority: 85
            ))
        }

        // 17. Streak just broken (weekly)
        if currentStreak == 0 && previousWeekStreak >= 3 {
            insights.append(SmartInsight(
                title: String(localized: "Streak Paused, Not Lost"),
                message: String(localized: "Your \(previousWeekStreak)-week streak ended, but the strength you built didn't disappear. Hit your \(workoutsRequired) workouts this week to start a new one."),
                iconAsset: "flame",
                priority: 82
            ))
        }

        // 18. Lifetime workout milestones
        let milestones = [10, 25, 50, 100, 150, 200, 250, 500]
        if let milestone = milestones.last(where: { lifetimeWorkouts >= $0 }) {
            if lifetimeWorkouts - milestone < 3 {
                insights.append(SmartInsight(
                    title: String(localized: "\(milestone) Workouts Strong"),
                    message: String(localized: "You've completed \(lifetimeWorkouts) workouts. Most people quit within the first few weeks. You've proven real commitment to your fitness."),
                    iconAsset: "trophy",
                    priority: 72
                ))
            }
        }

        // 19. Mid-week nudge (Thursday or later, no workouts this week)
        // weekdayIndex: 1=Sunday, 2=Monday ... 5=Thursday, 6=Friday, 7=Saturday
        if weekdayIndex >= 5 && workoutsThisWeek == 0 && lifetimeWorkouts > 0 {
            insights.append(SmartInsight(
                title: String(localized: "Week's Not Over Yet"),
                message: currentStreak > 0
                    ? String(localized: "You haven't trained this week yet and your \(currentStreak)-week streak is on the line. Even one session before the weekend keeps your momentum going.")
                    : String(localized: "You haven't trained this week yet. Even one session before the weekend helps maintain the progress you've built."),
                iconAsset: "flame",
                priority: 78
            ))
        }

        // Fallback for active users when no other rule triggers
        if insights.isEmpty && lifetimeWorkouts > 0 {
            if monthlyWorkouts > 0 {
                insights.append(SmartInsight(
                    title: String(localized: "Keep It Up"),
                    message: String(localized: "You've logged \(monthlyWorkouts) workout\(monthlyWorkouts == 1 ? "" : "s") this month and \(lifetimeWorkouts) overall. Staying consistent is what separates short-term effort from lasting results."),
                    iconAsset: "strengthtraining",
                    priority: 10
                ))
            } else {
                insights.append(SmartInsight(
                    title: String(localized: "New Month, Fresh Start"),
                    message: String(localized: "You have \(lifetimeWorkouts) workout\(lifetimeWorkouts == 1 ? "" : "s") under your belt. Kick this month off with a session. Momentum builds fast once you start."),
                    iconAsset: "flame",
                    priority: 10
                ))
            }
        }
        
        return insights.sorted { $0.priority > $1.priority }
    }
}
