//
//  SmartInsight.swift
//  Pulse
//

import Foundation

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
        "chest", "back", "shoulders", "delts", "biceps", "triceps", "forearms", "abs", "core"
    ]

    private static let lowerBodyGroups: Set<String> = [
        "legs", "quadriceps", "quads", "hamstrings", "glutes", "calves", "adductors", "hip"
    ]
    
    /// Generates insights from already-loaded progress stats.
    /// Returns insights sorted by priority (highest first).
    static func generateInsights(
        currentStreak: Int,
        bestStreak: Int,
        previousStreak: Int,
        monthlyWorkouts: Int,
        lastMonthWorkouts: Int,
        weeklyVolume: Int,
        monthlyVolume: Int,
        lastMonthVolume: Int,
        avgDuration: Int,
        muscleGroupNames: [String],
        topMuscleGroupName: String?,
        topMuscleGroupPercentage: Double,
        muscleGroupCount: Int,
        improvingExerciseCount: Int,
        daysSinceLastWorkout: Int?,
        lifetimeWorkouts: Int,
        weekdayIndex: Int,
        dayOfMonth: Int
    ) -> [SmartInsight] {
        var insights: [SmartInsight] = []
        
        // 1. High streak — suggest rest
        if currentStreak >= 4 {
            insights.append(SmartInsight(
                title: "Recovery Matters",
                message: "You've trained \(currentStreak) days straight. Muscle tissue repairs and grows during rest — scheduling a recovery day can actually accelerate your progress.",
                iconAsset: "moon",
                priority: 90
            ))
        }
        
        // 2. Inactivity — encourage return
        if let daysSince = daysSinceLastWorkout, daysSince >= 4 {
            insights.append(SmartInsight(
                title: "Time to Get Back",
                message: "It's been \(daysSince) days since your last session. Strength can decline after 72 hours of inactivity — even a light workout helps maintain your gains.",
                iconAsset: "flame",
                priority: 95
            ))
        } else if lifetimeWorkouts == 0 {
            insights.append(SmartInsight(
                title: "Start Your Journey",
                message: "Complete your first workout to unlock personalized training insights based on your activity.",
                iconAsset: "flame",
                priority: 100
            ))
        }
        
        // 3. Monthly workout frequency increase (skip first week — not enough data)
        if dayOfMonth >= 8 && lastMonthWorkouts > 0 && monthlyWorkouts > lastMonthWorkouts {
            let increase = Int(Double(monthlyWorkouts - lastMonthWorkouts) / Double(lastMonthWorkouts) * 100)
            if increase >= 20 {
                insights.append(SmartInsight(
                    title: "Consistency Pays Off",
                    message: "You've completed \(monthlyWorkouts) workouts this month vs \(lastMonthWorkouts) last month. Consistency is the strongest predictor of long-term strength gains.",
                    iconAsset: "progressup",
                    priority: 75
                ))
            }
        }
        
        // 4. Monthly workout frequency decrease (skip first week — not enough data)
        if dayOfMonth >= 8 && lastMonthWorkouts > 0 && monthlyWorkouts < lastMonthWorkouts {
            let decrease = Int(Double(lastMonthWorkouts - monthlyWorkouts) / Double(lastMonthWorkouts) * 100)
            if decrease >= 30 {
                insights.append(SmartInsight(
                    title: "Dropping Off?",
                    message: "Your workout count is down from \(lastMonthWorkouts) last month to \(monthlyWorkouts) so far. Training at least 2–3 times per week is enough to maintain and build strength.",
                    iconAsset: "progressup",
                    priority: 80
                ))
            }
        }
        
        // 5. Volume progressive overload (skip first week — not enough data)
        if dayOfMonth >= 8 && lastMonthVolume > 0 && monthlyVolume > lastMonthVolume {
            let increase = Int(Double(monthlyVolume - lastMonthVolume) / Double(lastMonthVolume) * 100)
            if increase >= 10 {
                insights.append(SmartInsight(
                    title: "Volume Is Climbing",
                    message: "Your training volume is up \(increase)% from last month. Gradual progressive overload is the primary driver of muscle hypertrophy.",
                    iconAsset: "scale",
                    priority: 70
                ))
            }
        }
        
        // 6. Volume declining (skip first week — not enough data)
        if dayOfMonth >= 8 && lastMonthVolume > 0 && monthlyVolume < lastMonthVolume {
            let decrease = Int(Double(lastMonthVolume - monthlyVolume) / Double(lastMonthVolume) * 100)
            if decrease >= 20 {
                insights.append(SmartInsight(
                    title: "Volume Dipping",
                    message: "Your training volume is down \(decrease)% from last month. If you're deloading intentionally that's great — otherwise try to maintain or gradually increase load.",
                    iconAsset: "scale",
                    priority: 58
                ))
            }
        }
        
        // 7. Muscle imbalance — one group dominates (need enough workouts for meaningful distribution)
        if let topName = topMuscleGroupName, topMuscleGroupPercentage > 0.40 && muscleGroupCount >= 2 && monthlyWorkouts >= 4 {
            let pct = Int(topMuscleGroupPercentage * 100)
            insights.append(SmartInsight(
                title: "Balance Your Training",
                message: "\(topName) makes up \(pct)% of your sets this month. Uneven training can create strength imbalances — consider adding work for opposing muscle groups.",
                iconAsset: "scale",
                priority: 65
            ))
        }
        
        // 8. Too few muscle groups
        if muscleGroupCount == 1 && monthlyWorkouts >= 3, let topName = topMuscleGroupName {
            insights.append(SmartInsight(
                title: "Add Some Variety",
                message: "You've only trained \(topName) this month. Full-body balance reduces injury risk and improves overall functional strength.",
                iconAsset: "strengthtraining",
                priority: 60
            ))
        }
        
        // 9. All upper body, no lower body
        if muscleGroupCount >= 2 && monthlyWorkouts >= 3 {
            let lowerNames = muscleGroupNames.map { $0.lowercased() }
            let hasLower = lowerNames.contains { lowerBodyGroups.contains($0) }
            let hasUpper = lowerNames.contains { upperBodyGroups.contains($0) }
            if hasUpper && !hasLower {
                insights.append(SmartInsight(
                    title: "Don't Neglect Your Legs",
                    message: "All your training this month targets upper body. Lower-body exercises like squats and deadlifts boost testosterone, burn more calories, and prevent muscular imbalances.",
                    iconAsset: "strengthtraining",
                    priority: 63
                ))
            }
        }
        
        // 10. Long session duration
        if avgDuration > 90 && monthlyWorkouts >= 2 {
            insights.append(SmartInsight(
                title: "Quality Over Quantity",
                message: "Your average session is \(avgDuration) minutes. Research shows diminishing returns after 60–75 minutes as cortisol rises — consider higher-intensity, shorter sessions.",
                iconAsset: "stopwatch",
                priority: 55
            ))
        }
        
        // 11. Short session duration
        if avgDuration > 0 && avgDuration < 20 && monthlyWorkouts >= 3 {
            insights.append(SmartInsight(
                title: "Make Each Session Count",
                message: "Your average session is \(avgDuration) minutes. Sessions under 20 minutes may not provide enough stimulus — aim for at least 30–45 minutes to maximize your results.",
                iconAsset: "stopwatch",
                priority: 52
            ))
        }
        
        // 12. Strength PR momentum
        if improvingExerciseCount >= 3 {
            insights.append(SmartInsight(
                title: "Strength Trending Up",
                message: "You've improved on \(improvingExerciseCount) exercises since you started. Keep following progressive overload principles to sustain these gains.",
                iconAsset: "trophy",
                priority: 68
            ))
        }
        
        // 13. Best streak achievement
        if currentStreak > 0 && currentStreak >= bestStreak && bestStreak >= 3 {
            insights.append(SmartInsight(
                title: "New Personal Best",
                message: "You're on your longest workout streak ever at \(currentStreak) days. Building a training habit is the foundation of lasting results.",
                iconAsset: "flame",
                priority: 85
            ))
        }
        
        // 14. Streak just broken
        if currentStreak == 0 && previousStreak >= 3 {
            insights.append(SmartInsight(
                title: "Streak Paused — Not Lost",
                message: "Your \(previousStreak)-day streak ended, but the strength you built didn't disappear. One session is all it takes to start a new one.",
                iconAsset: "flame",
                priority: 82
            ))
        }
        
        // 15. Lifetime workout milestones
        let milestones = [10, 25, 50, 100, 150, 200, 250, 500]
        if let milestone = milestones.last(where: { lifetimeWorkouts >= $0 }) {
            // Only show if they recently hit it (within 3 workouts of the milestone)
            if lifetimeWorkouts - milestone < 3 {
                insights.append(SmartInsight(
                    title: "\(milestone) Workouts Strong",
                    message: "You've completed \(lifetimeWorkouts) workouts. Most people quit within the first few weeks — you've proven real commitment to your fitness.",
                    iconAsset: "trophy",
                    priority: 72
                ))
            }
        }
        
        // 16. Mid-week nudge (Thursday or later, no workouts this week)
        // weekdayIndex: 1=Sunday, 2=Monday ... 5=Thursday, 6=Friday, 7=Saturday
        if weekdayIndex >= 5 && weeklyVolume == 0 && lifetimeWorkouts > 0 {
            insights.append(SmartInsight(
                title: "Week's Not Over Yet",
                message: "You haven't trained this week yet. Even one session before the weekend helps maintain the progress you've built.",
                iconAsset: "flame",
                priority: 78
            ))
        }
        
        // Fallback for active users when no other rule triggers
        if insights.isEmpty && lifetimeWorkouts > 0 {
            if monthlyWorkouts > 0 {
                insights.append(SmartInsight(
                    title: "Keep It Up",
                    message: "You've logged \(monthlyWorkouts) workout\(monthlyWorkouts == 1 ? "" : "s") this month and \(lifetimeWorkouts) overall. Staying consistent is what separates short-term effort from lasting results.",
                    iconAsset: "strengthtraining",
                    priority: 10
                ))
            } else {
                insights.append(SmartInsight(
                    title: "New Month, Fresh Start",
                    message: "You have \(lifetimeWorkouts) workout\(lifetimeWorkouts == 1 ? "" : "s") under your belt. Kick this month off with a session — momentum builds fast once you start.",
                    iconAsset: "flame",
                    priority: 10
                ))
            }
        }
        
        return insights.sorted { $0.priority > $1.priority }
    }
}
