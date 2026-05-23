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

struct StrengthProgress: Identifiable {
    let id = UUID()
    let exerciseName: String
    let bestWeight: Double
    let lastWeight: Double
    let firstWeight: Double
    let improvementPercent: Double
}

struct MuscleGroupStat {
    let name: String
    let sets: Int
    let percentage: Double
}

@MainActor
class ProgressStatsViewModel: ObservableObject {
    @Published var weeklyVolume: Int = 0
    @Published var weeklyDurationMinutes: Int = 0
    @Published var weeklyWorkouts: Int?
    @Published var monthlyVolume: Int = 0
    @Published var monthlyWorkouts: Int = 0

    @Published var avgDuration: Int = 0
    @Published var currentStreak: Int = 0
    private var previousStreak: Int = 0
    private var previousWeekStreak: Int = 0

    @Published var lastMonthVolume: Int = 0
    @Published var lastMonthWorkouts: Int = 0
    @Published var lastMonthAvgDuration: Int = 0
    @Published var lastWeekVolume: Int?
    @Published var lastWeekWorkouts: Int?
    @Published var lastWeekDurationMinutes: Int?
    @Published var weeklySets: Int?
    @Published var lastWeekSets: Int?
    
    @Published var strengthProgress: [StrengthProgress] = []
    @Published var topMuscleGroups: [MuscleGroupStat] = []
    @Published var exercise1RMStats: [Exercise1RMRow] = []
    
    @Published var lifetimeWorkouts: Int = 0
    @Published var lifetimeVolume: Int = 0
    @Published var lifetimeHours: Int = 0
    @Published var bestStreak: Int = 0
    
    @Published var userStreak: UserStreak?
    @Published var recentSessions: [WorkoutSession] = []
    @Published var currentInsight: SmartInsight?
    
    // Pagination state for AllRecentWorkoutsView
    @Published var allRecentSessions: [WorkoutSession] = []
    @Published var hasMoreSessions: Bool = true
    @Published var isLoadingMore: Bool = false
    private var paginationOffset: Int = 0
    private let pageSize: Int = 20
    private var isLoadingInitialPage: Bool = false
    
    var recentPRCount: Int {
        guard let sevenDaysAgo = (userProfile?.userCalendar ?? Calendar.current).date(byAdding: .day, value: -7, to: Date()) else { return 0 }
        return exercise1RMStats.filter { $0.achievedAt >= sevenDaysAgo }.count
    }

    var daysSinceLastWorkout: Int? {
        guard let lastSession = recentSessions.first else { return nil }
        let date = lastSession.completedAt ?? lastSession.startedAt
        let calendar = userProfile?.userCalendar ?? Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfWorkout = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: startOfWorkout, to: startOfToday).day
    }

    private(set) var userProfile: Profile?
    private let supabase = SupabaseManager.shared.client
    private let workoutRepository = WorkoutRepository()
    private(set) var hasLoaded = false
    private var loadTask: Task<Void, Never>?
    
    init() {
        NotificationCenter.default.addObserver(forName: Notification.Name("workoutDataChanged"), object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.loadStats()
            }
        }
    }
    
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
        previousStreak = currentStreak
        previousWeekStreak = userStreak?.currentStreak ?? 0
        await fetchUserProfile()
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            // Run RPC calls and recent sessions concurrently
            async let stats: Void = self.loadProgressStats()
            async let muscles: Void = self.loadMuscleGroupStatsRPC()
            async let strength: Void = self.loadStrengthProgressRPC()
            async let recent: Void = self.loadRecentSessions()
            async let oneRM: Void = self.loadExercise1RMStats()
            async let streak: Void = self.loadUserStreak()
            _ = await (stats, muscles, strength, recent, oneRM, streak)
        }
        loadTask = task
        await task.value
        hasLoaded = true
        generateInsight()
    }
    
    private func generateInsight() {
        let calendar = userProfile?.userCalendar ?? Calendar.current

        var daysSinceLastWorkout: Int? = nil
        if let lastSession = recentSessions.first {
            let lastDate = lastSession.completedAt ?? lastSession.startedAt
            daysSinceLastWorkout = calendar.dateComponents([.day], from: lastDate, to: Date()).day
        }

        let weekdayIndex = calendar.component(.weekday, from: Date())
        let dayOfMonth = calendar.component(.day, from: Date())

        let insights = SmartInsightEngine.generateInsights(
            userStreak: userStreak,
            previousWeekStreak: previousWeekStreak,
            monthlyWorkouts: monthlyWorkouts,
            lastMonthWorkouts: lastMonthWorkouts,
            weeklyVolume: weeklyVolume,
            weeklyWorkouts: weeklyWorkouts,
            lastWeekWorkouts: lastWeekWorkouts,
            monthlyVolume: monthlyVolume,
            lastMonthVolume: lastMonthVolume,
            avgDuration: avgDuration,
            muscleGroupNames: topMuscleGroups.map { $0.name },
            topMuscleGroupName: topMuscleGroups.first?.name,
            topMuscleGroupPercentage: topMuscleGroups.first?.percentage ?? 0,
            muscleGroupCount: topMuscleGroups.count,
            improvingExerciseCount: strengthProgress.filter { $0.improvementPercent > 0 }.count,
            recentPRCount: recentPRCount,
            daysSinceLastWorkout: daysSinceLastWorkout,
            lifetimeWorkouts: lifetimeWorkouts,
            weekdayIndex: weekdayIndex,
            dayOfMonth: dayOfMonth
        )
        currentInsight = insights.first
    }
    
    /// Fetches all numeric progress stats from the server-side RPC.
    /// Replaces loadWeeklyVolume, loadMonthlyStats, loadLastMonthStats, loadLifetimeStats, and calculateStreak.
    private func loadProgressStats() async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        
        let calendar = userProfile?.userCalendar ?? Calendar.current
        let now = Date()
        guard let rolling7Start = calendar.date(byAdding: .day, value: -7, to: now),
              let rolling14Start = calendar.date(byAdding: .day, value: -14, to: now),
              let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart),
              let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: monthStart) else {
            return
        }
        let lastMonthEnd = monthStart

        do {
            let stats = try await workoutRepository.fetchProgressStats(
                userId: userId,
                weekStart: rolling7Start,
                weekEnd: now,
                monthStart: monthStart,
                monthEnd: monthEnd,
                lastMonthStart: lastMonthStart,
                lastMonthEnd: lastMonthEnd,
                lastWeekStart: rolling14Start,
                lastWeekEnd: rolling7Start
            )
            
            weeklyVolume = stats.weeklyVolume
            weeklyDurationMinutes = stats.weeklyDurationMinutes
            weeklyWorkouts = stats.weeklyWorkouts
            monthlyVolume = stats.monthlyVolume
            monthlyWorkouts = stats.monthlyWorkouts
            avgDuration = stats.avgDurationMinutes
            lastMonthVolume = stats.lastMonthVolume
            lastMonthWorkouts = stats.lastMonthWorkouts
            lastMonthAvgDuration = stats.lastMonthAvgDuration
            lastWeekVolume = stats.lastWeekVolume
            lastWeekWorkouts = stats.lastWeekWorkouts
            lastWeekDurationMinutes = stats.lastWeekDurationMinutes
            weeklySets = stats.weeklySets
            lastWeekSets = stats.lastWeekSets
            lifetimeWorkouts = stats.lifetimeWorkouts
            lifetimeVolume = stats.lifetimeVolume
            lifetimeHours = stats.lifetimeHours
            currentStreak = stats.currentStreak
            bestStreak = stats.bestStreak
        } catch is CancellationError {
            // Ignore - a newer refresh replaced this one
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            // Ignore URL session cancellation
        } catch {
            debugLog("Failed to load progress stats: \(error)")
        }
    }
    
    /// Fetches muscle group stats from the server-side RPC.
    private func loadMuscleGroupStatsRPC() async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        
        let calendar = userProfile?.userCalendar ?? Calendar.current
        let now = Date()
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            topMuscleGroups = []
            return
        }
        
        do {
            let rows = try await workoutRepository.fetchMuscleGroupStats(
                userId: userId,
                monthStart: monthStart,
                monthEnd: monthEnd
            )
            topMuscleGroups = rows.map { row in
                MuscleGroupStat(name: row.name, sets: row.sets, percentage: row.percentage)
            }
        } catch is CancellationError {
            // Ignore - a newer refresh replaced this one
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            // Ignore URL session cancellation
        } catch {
            debugLog("Failed to load muscle group stats: \(error)")
            topMuscleGroups = []
        }
    }
    
    /// Fetches strength progress from the server-side RPC.
    private func loadStrengthProgressRPC() async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        
        do {
            let rows = try await workoutRepository.fetchStrengthProgress(userId: userId)
            strengthProgress = rows.map { row in
                StrengthProgress(
                    exerciseName: row.exerciseName,
                    bestWeight: row.bestWeight,
                    lastWeight: row.lastWeight,
                    firstWeight: row.firstWeight,
                    improvementPercent: row.improvementPercent
                )
            }
        } catch is CancellationError {
            // Ignore - a newer refresh replaced this one
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            // Ignore URL session cancellation
        } catch {
            debugLog("Failed to load strength progress: \(error)")
            strengthProgress = []
        }
    }
    
    /// Fetches estimated 1RM stats from the server-side RPC.
    private func loadExercise1RMStats() async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        
        do {
            exercise1RMStats = try await workoutRepository.fetchExercise1RMStats(userId: userId)
        } catch is CancellationError {
            // Ignore - a newer refresh replaced this one
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            // Ignore URL session cancellation
        } catch {
            debugLog("Failed to load 1RM stats: \(error)")
            exercise1RMStats = []
        }
    }
    
    private func loadUserStreak() async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        do {
            userStreak = try await workoutRepository.refreshUserStreak(userId: userId)
        } catch is CancellationError {
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
        } catch {
            debugLog("Failed to load user streak: \(error)")
        }
    }

    private func loadRecentSessions() async {
        do {
            recentSessions = try await workoutRepository.fetchCompletedSessions(limit: 3, offset: 0)
        } catch is CancellationError {
            // Ignore - a newer refresh replaced this one
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            // Ignore URL session cancellation
        } catch {
            debugLog("Failed to load recent sessions: \(error)")
            recentSessions = []
        }
    }
    
    // Load first page of sessions for AllRecentWorkoutsView
    func loadRecentSessionsPaginated() async {
        isLoadingInitialPage = true
        paginationOffset = 0
        hasMoreSessions = false
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
        isLoadingInitialPage = false
    }
    
    // Load next page of sessions
    func loadMoreSessions() async {
        guard hasMoreSessions, !isLoadingMore, !isLoadingInitialPage else { return }
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
        let formatter = SharedFormatters.mediumDate
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
