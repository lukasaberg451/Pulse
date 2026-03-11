//
//  ProgressStatsViewModel.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-15.
//

import Foundation
import Supabase
import Combine

struct PersonalRecord: Identifiable {
    let id = UUID()
    let exerciseName: String
    let weight: Double
    let reps: Int
    let date: Date
}

struct MuscleGroupStat {
    let name: String
    let sets: Int
    let percentage: Double
}

@MainActor
class ProgressStatsViewModel: ObservableObject {
    @Published var monthlyVolume: Int = 0
    @Published var monthlyWorkouts: Int = 0
    @Published var monthlyPRs: Int = 0
    @Published var avgDuration: Int = 0
    @Published var currentStreak: Int = 0
    
    @Published var lastMonthVolume: Int = 0
    @Published var lastMonthWorkouts: Int = 0
    @Published var lastMonthAvgDuration: Int = 0
    
    @Published var recentPRs: [PersonalRecord] = []
    @Published var topMuscleGroups: [MuscleGroupStat] = []
    
    @Published var lifetimeWorkouts: Int = 0
    @Published var lifetimeVolume: Int = 0
    @Published var lifetimeHours: Int = 0
    @Published var bestStreak: Int = 0
    
    @Published var recentSessions: [WorkoutSession] = []
    
    // Pagination state for AllRecentWorkoutsView
    @Published var allRecentSessions: [WorkoutSession] = []
    @Published var hasMoreSessions: Bool = true
    @Published var isLoadingMore: Bool = false
    private var paginationOffset: Int = 0
    private let pageSize: Int = 20
    
    private var userProfile: Profile?
    private let supabase = SupabaseManager.shared.client
    private let workoutRepository = WorkoutRepository()
    private(set) var hasLoaded = false
    private var loadTask: Task<Void, Never>?
    
    private func fetchUserProfile() async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        do {
            let profile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            userProfile = profile
        } catch {
            debugLog("Failed to fetch user profile: \(error)")
        }
    }
    
    func loadStats() async {
        loadTask?.cancel()
        await fetchUserProfile()
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            async let monthly: Void = self.loadMonthlyStats()
            async let lastMonth: Void = self.loadLastMonthStats()
            async let prs: Void = self.loadRecentPRs()
            async let muscles: Void = self.loadMuscleGroupStats()
            async let lifetime: Void = self.loadLifetimeStats()
            async let streak: Void = self.calculateStreak()
            async let recent: Void = self.loadRecentSessions()
            _ = await (monthly, lastMonth, prs, muscles, lifetime, streak, recent)
        }
        loadTask = task
        await task.value
        hasLoaded = true
    }
    
    private func loadMonthlyStats() async {
        let calendar = userProfile?.userCalendar ?? Calendar.current
        let now = Date()
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return
        }
        
        do {
            guard let userId = supabase.auth.currentUser?.id else { return }
            
            // Get completed sessions this month
            let sessions: [WorkoutSession] = try await supabase
                .from("workout_sessions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("started_at", value: ISO8601DateFormatter().string(from: monthStart))
                .lt("started_at", value: ISO8601DateFormatter().string(from: monthEnd))
                .not("completed_at", operator: .is, value: "null")
                .execute()
                .value
            
            monthlyWorkouts = sessions.count
            
            // Calculate average duration
            let totalDuration = sessions.reduce(0) { $0 + ($1.durationSeconds ?? 0) }
            avgDuration = sessions.isEmpty ? 0 : (totalDuration / sessions.count) / 60
            
            guard !sessions.isEmpty else {
                monthlyVolume = 0
                return
            }
            
            // Get all sets from this month to calculate volume
            let sets: [WorkoutSet] = try await supabase
                .from("workout_sets")
                .select()
                .in("session_id", values: sessions.map { $0.id.uuidString })
                .not("weight", operator: .is, value: "null")
                .not("reps", operator: .is, value: "null")
                .execute()
                .value
            
            // Calculate total volume (weight × reps)
            monthlyVolume = sets.reduce(0) { total, set in
                let weight = set.weight ?? 0
                let reps = set.reps ?? 0
                return total + Int(weight * Double(reps))
            }
            
        } catch {
            debugLog("Failed to load monthly stats: \(error)")
        }
    }
    
    private func loadLastMonthStats() async {
        let calendar = userProfile?.userCalendar ?? Calendar.current
        let now = Date()
            guard let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
            let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart) else {
                
            return
        
        
        
        
        
        }
        
        let lastMonthEnd = thisMonthStart
        
        do {
            guard let userId = supabase.auth.currentUser?.id else { return }
            
            let sessions: [WorkoutSession] = try await supabase
                .from("workout_sessions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("started_at", value: ISO8601DateFormatter().string(from: lastMonthStart))
                .lt("started_at", value: ISO8601DateFormatter().string(from: lastMonthEnd))
                .not("completed_at", operator: .is, value: "null")
                .execute()
                .value
            
            lastMonthWorkouts = sessions.count
            
            let totalDuration = sessions.reduce(0) { $0 + ($1.durationSeconds ?? 0) }
            lastMonthAvgDuration = sessions.isEmpty ? 0 : (totalDuration / sessions.count) / 60
            
            guard !sessions.isEmpty else {
                lastMonthVolume = 0
                return
            }
            
            let sets: [WorkoutSet] = try await supabase
                .from("workout_sets")
                .select()
                .in("session_id", values: sessions.map { $0.id.uuidString })
                .not("weight", operator: .is, value: "null")
                .not("reps", operator: .is, value: "null")
                .execute()
                .value
            
            lastMonthVolume = sets.reduce(0) { total, set in
                let weight = set.weight ?? 0
                let reps = set.reps ?? 0
                return total + Int(weight * Double(reps))
            }
            
        } catch {
            debugLog("Failed to load last month stats: \(error)")
        }
    }
    
    private func loadRecentPRs() async {
        do {
            guard let userId = supabase.auth.currentUser?.id else { return }
            
            // Get all completed workout sessions
            let sessions: [WorkoutSession] = try await supabase
                .from("workout_sessions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .not("completed_at", operator: .is, value: "null")
                .execute()
                .value
            
            guard !sessions.isEmpty else {
                monthlyPRs = 0
                recentPRs = []
                return
            }
            
            // Get all sets from all sessions
            let sets: [WorkoutSet] = try await supabase
                .from("workout_sets")
                .select()
                .in("session_id", values: sessions.map { $0.id.uuidString })
                .eq("completed", value: true)
                .not("weight", operator: .is, value: "null")
                .not("reps", operator: .is, value: "null")
                .execute()
                .value
            
            // Get all exercises to map exercise IDs to names
            let exercises: [Exercise] = try await supabase
                .from("exercises")
                .select()
                .execute()
                .value
            
            let exerciseDict = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
            
            // Group sets by exercise and find PRs (strength exercises only)
            let setsByExercise = Dictionary(grouping: sets, by: { $0.exerciseId })
            var personalRecords: [PersonalRecord] = []
            
            for (exerciseId, exerciseSets) in setsByExercise {
                guard let exercise = exerciseDict[exerciseId],
                      exercise.exerciseType?.lowercased() != "cardio" else { continue }
                let exerciseName = exercise.name
                
                // Sort by one-rep max (weight * reps as a simple approximation)
                let sortedSets = exerciseSets.sorted { set1, set2 in
                    let score1 = (set1.weight ?? 0) * Double(set1.reps ?? 0)
                    let score2 = (set2.weight ?? 0) * Double(set2.reps ?? 0)
                    return score1 > score2
                }
                
                // Get the best set for this exercise
                if let bestSet = sortedSets.first,
                   let weight = bestSet.weight,
                   let reps = bestSet.reps,
                   let session = sessions.first(where: { $0.id == bestSet.sessionId }) {
                    
                    personalRecords.append(PersonalRecord(
                        exerciseName: exerciseName,
                        weight: weight,
                        reps: reps,
                        date: session.completedAt ?? session.startedAt
                    ))
                }
            }
            
            // Sort by date to get most recent PRs
            recentPRs = personalRecords.sorted { $0.date > $1.date }
            
            // Calculate PRs from this month
            let calendar = userProfile?.userCalendar ?? Calendar.current
            let now = Date()
            guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
                monthlyPRs = 0
                return
            }
            
            monthlyPRs = recentPRs.filter { $0.date >= monthStart }.count
            
        } catch {
            debugLog("Failed to load PRs: \(error)")
            monthlyPRs = 0
            recentPRs = []
        }
    }
    
    private func loadMuscleGroupStats() async {
        let calendar = userProfile?.userCalendar ?? Calendar.current
        let now = Date()
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            topMuscleGroups = []
            return
        }
        
        do {
            guard let userId = supabase.auth.currentUser?.id else { return }
            
            // Get completed sessions this month
            let sessions: [WorkoutSession] = try await supabase
                .from("workout_sessions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("started_at", value: ISO8601DateFormatter().string(from: monthStart))
                .lt("started_at", value: ISO8601DateFormatter().string(from: monthEnd))
                .not("completed_at", operator: .is, value: "null")
                .execute()
                .value
            
            guard !sessions.isEmpty else {
                topMuscleGroups = []
                return
            }
            
            // Get all sets from this month
            let sets: [WorkoutSet] = try await supabase
                .from("workout_sets")
                .select()
                .in("session_id", values: sessions.map { $0.id.uuidString })
                .eq("completed", value: true)
                .execute()
                .value
            
            // Get all exercises to map exercise IDs to muscle groups
            let exercises: [Exercise] = try await supabase
                .from("exercises")
                .select()
                .execute()
                .value
            
            let exerciseDict = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
            
            // Count sets per muscle group
            var muscleGroupCounts: [String: Int] = [:]
            
            for set in sets {
                if let exercise = exerciseDict[set.exerciseId],
                   exercise.exerciseType?.lowercased() != "cardio",
                   let primaryMuscle = exercise.muscleGroup {
                    muscleGroupCounts[primaryMuscle, default: 0] += 1
                    
                    // Also count secondary muscle groups with half weight and exclude None
                    if let secondaryMuscle = exercise.secondaryMuscleGroup,
                       secondaryMuscle.lowercased() != "none" {
                        muscleGroupCounts[secondaryMuscle, default: 0] += 1
                    }
                }
            }
            
            let totalSets = muscleGroupCounts.values.reduce(0, +)
            
            guard totalSets > 0 else {
                topMuscleGroups = []
                return
            }
            
            // Convert to MuscleGroupStat and sort by count
            let stats = muscleGroupCounts.map { name, sets in
                MuscleGroupStat(
                    name: name.capitalized,
                    sets: sets,
                    percentage: Double(sets) / Double(totalSets)
                )
            }.sorted { $0.sets > $1.sets }
            
            // Take top 5
            topMuscleGroups = Array(stats.prefix(5))
            
        } catch {
            debugLog("Failed to load muscle group stats: \(error)")
            topMuscleGroups = []
        }
    }
    
    private func loadLifetimeStats() async {
        do {
            guard let userId = supabase.auth.currentUser?.id else { return }
            
            let sessions: [WorkoutSession] = try await supabase
                .from("workout_sessions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .not("completed_at", operator: .is, value: "null")
                .execute()
                .value
            
            lifetimeWorkouts = sessions.count
            
            let totalSeconds = sessions.reduce(0) { $0 + ($1.durationSeconds ?? 0) }
            lifetimeHours = totalSeconds / 3600
            
            guard !sessions.isEmpty else {
                lifetimeVolume = 0
                return
            }
            
            let sets: [WorkoutSet] = try await supabase
                .from("workout_sets")
                .select()
                .in("session_id", values: sessions.map { $0.id.uuidString })
                .not("weight", operator: .is, value: "null")
                .not("reps", operator: .is, value: "null")
                .execute()
                .value
            
            lifetimeVolume = sets.reduce(0) { total, set in
                let weight = set.weight ?? 0
                let reps = set.reps ?? 0
                return total + Int(weight * Double(reps))
            }
            
        } catch {
            debugLog("Failed to load lifetime stats: \(error)")
        }
    }
    
    private func calculateStreak() async {
        do {
            guard let userId = supabase.auth.currentUser?.id else { return }
            
            // Get all completed workout sessions, sorted by date (newest first)
            let sessions: [WorkoutSession] = try await supabase
                .from("workout_sessions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .not("completed_at", operator: .is, value: "null")
                .order("completed_at", ascending: false)
                .execute()
                .value
            
            guard !sessions.isEmpty else {
                currentStreak = 0
                bestStreak = 0
                return
            }
            
            let calendar = userProfile?.userCalendar ?? Calendar.current
            var workoutDates = Set<Date>()
            
            // Extract unique workout dates (ignoring time)
            for session in sessions {
                let date = session.completedAt ?? session.startedAt
                if let dayStart = calendar.startOfDay(for: date) as Date? {
                    workoutDates.insert(dayStart)
                }
            }
            
            let sortedDates = workoutDates.sorted(by: >)
            
            // Calculate current streak
            let today = calendar.startOfDay(for: Date())
            var streak = 0
            var checkDate = today
            
            for date in sortedDates {
                // Check if this date is the current check date or yesterday
                if date == checkDate {
                    streak += 1
                    checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
                } else if calendar.dateComponents([.day], from: date, to: checkDate).day == 1 {
                    // Workout was yesterday, continue streak
                    streak += 1
                    checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
                } else {
                    // Gap in streak, stop counting
                    break
                }
            }
            
            // If today has no workout and yesterday doesn't either, streak is 0
            if let firstDate = sortedDates.first {
                let daysDiff = calendar.dateComponents([.day], from: firstDate, to: today).day ?? 0
                if daysDiff > 1 {
                    streak = 0
                }
            }
            
            currentStreak = streak
            
            // Calculate best streak ever
            var maxStreak = 0
            var tempStreak = 0
            var previousDate: Date? = nil
            
            for date in sortedDates.reversed() {
                if let prev = previousDate {
                    let daysDiff = calendar.dateComponents([.day], from: prev, to: date).day ?? 0
                    
                    if daysDiff <= 1 {
                        // Continue streak (same day or next day)
                        tempStreak += 1
                    } else {
                        // Streak broken
                        maxStreak = max(maxStreak, tempStreak)
                        tempStreak = 1
                    }
                } else {
                    tempStreak = 1
                }
                
                previousDate = date
            }
            
            maxStreak = max(maxStreak, tempStreak)
            bestStreak = maxStreak
            
        } catch {
            debugLog("Failed to calculate streak: \(error)")
            currentStreak = 0
            bestStreak = 0
        }
    }
    
    private func loadRecentSessions() async {
        do {
            recentSessions = try await workoutRepository.fetchCompletedSessions(limit: 3, offset: 0)
        } catch {
            debugLog("Failed to load recent sessions: \(error)")
            recentSessions = []
        }
    }
    
    // Load first page of sessions for AllRecentWorkoutsView
    func loadRecentSessionsPaginated() async {
        paginationOffset = 0
        hasMoreSessions = true
        do {
            let sessions = try await workoutRepository.fetchCompletedSessions(limit: pageSize, offset: 0)
            allRecentSessions = sessions
            hasMoreSessions = sessions.count >= pageSize
            paginationOffset = sessions.count
        } catch is CancellationError {
            // Ignore cancellation from refreshable
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            // Ignore URL session cancellation
        } catch {
            debugLog("Failed to load paginated sessions: \(error)")
            allRecentSessions = []
            hasMoreSessions = false
        }
    }
    
    // Load next page of sessions
    func loadMoreSessions() async {
        guard hasMoreSessions, !isLoadingMore else { return }
        isLoadingMore = true
        do {
            let sessions = try await workoutRepository.fetchCompletedSessions(limit: pageSize, offset: paginationOffset)
            allRecentSessions.append(contentsOf: sessions)
            hasMoreSessions = sessions.count >= pageSize
            paginationOffset += sessions.count
        } catch is CancellationError {
            // Ignore cancellation
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            // Ignore URL session cancellation
        } catch {
            debugLog("Failed to load more sessions: \(error)")
        }
        isLoadingMore = false
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.timeZone = userProfile?.resolvedTimeZone ?? TimeZone.current
        return formatter.string(from: date)
    }
    
    func formatDuration(_ seconds: Int?) -> String {
        guard let seconds = seconds else { return "N/A" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, secs)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }
}
