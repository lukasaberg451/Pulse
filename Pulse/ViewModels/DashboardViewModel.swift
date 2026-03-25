//
//  DashboardViewModel.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/10/26.
//

import Foundation
import Combine
import Supabase
import SwiftUI

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var todaysWorkouts: [ScheduledWorkout] = []
    @Published var recentSessions: [WorkoutSession] = []
    @Published var routines: [Routine] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var routineExercisesMap: [UUID: [RoutineExercise]] = [:]
    @Published var routineExerciseCounts: [UUID: Int] = [:]
    @Published var exercises: [Exercise] = []
    @Published var weeklyWorkoutMinutes: Int = 0
    @Published var weeklyGoalMinutes: Int = 150
    @Published var userProfile: Profile?
    @Published var workoutSessions: [UUID: WorkoutSession] = [:]
    @Published var currentStreak: Int = 0
    @Published var bestStreak: Int = 0
    @Published var latestPR: PersonalRecord?
    @Published var totalWorkoutCount: Int = 0
    
    private let workoutRepository = WorkoutRepository()
    private let routineRepository = RoutineRepository()
    private let exerciseRepository = ExerciseRepository.shared
    private var cancellables = Set<AnyCancellable>()
    private var refreshTask: Task<Void, Never>?
    
    init() {
        // Listen for workout data changes
        NotificationCenter.default.publisher(for: .workoutDataChanged)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    debugLog("📢 Received workout data change notification, reloading...")
                    await self?.refreshAll()
                }
            }
            .store(in: &cancellables)
    }
    
    func refreshAll() async {
        // Cancel any in-flight refresh to avoid request cancellation errors
        refreshTask?.cancel()
        
        let task = Task {
            await loadData()
            
            guard !Task.isCancelled else { return }
            
            await loadDashboardStats()
        }
        refreshTask = task
        await task.value
    }
    
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            await fetchUserProfile()
            guard !Task.isCancelled else { isLoading = false; return }
            //Load exercises first
            exercises = try await exerciseRepository.fetchAllExercises()
            
            // Load routines
            routines = try await routineRepository.fetchRoutines()
            
            // Load all routine exercises in a single batch query
            let routineIds = routines.map { $0.id }
            let allRoutineExercises = try await routineRepository.fetchRoutineExercises(routineIds: routineIds)
            routineExercisesMap = allRoutineExercises
            for (routineId, exercises) in allRoutineExercises {
                routineExerciseCounts[routineId] = exercises.count
            }
            
            // Load todays workouts
            let calendar = userProfile?.userCalendar ?? Calendar.current
            let startOfToday = calendar.startOfDay(for: Date())
            guard let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
                isLoading = false
                return
            }
            
            let tz = userProfile?.resolvedTimeZone ?? .current
            todaysWorkouts = try await workoutRepository.fetchScheduledWorkouts(
                startDate: startOfToday,
                endDate: endOfToday,
                timeZone: tz
            )
            
            // Build session lookup for today's scheduled workouts
            let todaySessionIds = Set(todaysWorkouts.compactMap { $0.workoutSessionId })
            for id in todaySessionIds {
                let sessions: [WorkoutSession] = try await SupabaseManager.shared.client
                    .from("workout_sessions")
                    .select()
                    .eq("id", value: id.uuidString)
                    .execute()
                    .value
                if let session = sessions.first {
                    workoutSessions[session.id] = session
                }
            }
            
            // Sort: uncompleted first, then completed by most recently completed
            todaysWorkouts.sort { a, b in
                if a.completed != b.completed {
                    return !a.completed
                }
                if a.completed && b.completed {
                    let aDate = a.workoutSessionId.flatMap { workoutSessions[$0]?.completedAt }
                    let bDate = b.workoutSessionId.flatMap { workoutSessions[$0]?.completedAt }
                    if let aDate, let bDate {
                        return aDate > bDate
                    }
                    return aDate != nil
                }
                return false
            }
            
            // Load recently completed (last 5) using pagination
            recentSessions = try await workoutRepository.fetchCompletedSessions(limit: 5, offset: 0)
            debugLog("📊 Loaded \(recentSessions.count) recent completed sessions")
            
        } catch is CancellationError {
            // Ignore — view was dismissed or a newer refresh replaced this one
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            // Ignore URL session cancellation
        } catch {
            errorMessage = "Failed to load data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func routineExercises(for routineId: UUID) -> [RoutineExercise] {
        routineExercisesMap[routineId] ?? []
    }
    
    func exerciseCount(for routineId: UUID) -> Int {
        routineExerciseCounts[routineId] ?? 0
    }
    
    func routine(for id: UUID) -> Routine? {
        routines.first { $0.id == id }
    }
    
    func sessionName(for scheduled: ScheduledWorkout) -> String {
        if let sessionId = scheduled.workoutSessionId,
           let session = workoutSessions[sessionId] {
            return session.name
        }
        return "Deleted Routine"
    }
    
    var formattedToday: String {
        let formatter = SharedFormatters.dayMonthYear
        formatter.timeZone = userProfile?.resolvedTimeZone ?? .current
        return formatter.string(from: Date())
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = SharedFormatters.mediumDate
        formatter.timeZone = userProfile?.resolvedTimeZone ?? TimeZone.current
        return formatter.string(from: date)
    }
    
    func formatDuration(_ seconds: Int?) -> String {
        guard let seconds = seconds else { return "N/A"}
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
    
    func fetchUserProfile() async {
        let supabase = SupabaseManager.shared.client
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
        } catch is CancellationError {
            // Ignore — a newer refresh replaced this one
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            // Ignore URL session cancellation (e.g. a newer refresh replaced this one)
        } catch {
            debugLog("Failed to fetch user profile: \(error)")
        }
    }
    
    /// Fetches dashboard aggregate stats from the server-side RPC.
    /// Replaces the previous loadWeeklyProgress(), calculateStreak(), and loadLatestPR() methods.
    private func loadDashboardStats() async {
        let supabase = SupabaseManager.shared.client
        guard let userId = supabase.auth.currentUser?.id else { return }
        
        let calendar = userProfile?.userCalendar ?? Calendar.current
        let now = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
              let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
            return
        }
        
        do {
            let stats = try await workoutRepository.fetchDashboardStats(
                userId: userId,
                weekStart: weekStart,
                weekEnd: weekEnd
            )
            
            currentStreak = stats.currentStreak
            bestStreak = stats.bestStreak
            totalWorkoutCount = stats.totalWorkoutCount
            weeklyWorkoutMinutes = stats.weeklyWorkoutMinutes
            
            // Update weekly goal from profile
            if let profile = userProfile {
                weeklyGoalMinutes = profile.weeklyGoalMinutes ?? 150
            }
            
            // Map the latest PR
            if let prName = stats.latestPrExerciseName,
               let prWeight = stats.latestPrWeight,
               let prReps = stats.latestPrReps,
               let prDate = stats.latestPrDate {
                latestPR = PersonalRecord(
                    exerciseName: prName,
                    weight: prWeight,
                    reps: prReps,
                    date: prDate
                )
            } else {
                latestPR = nil
            }
        } catch is CancellationError {
            // Ignore — view was dismissed or a newer refresh replaced this one
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            // Ignore URL session cancellation (e.g. view dismissed mid-request)
        } catch {
            debugLog("Failed to load dashboard stats: \(error)")
        }
    }
    
    func updateWeeklyGoal(minutes: Int) async {
        let supabase = SupabaseManager.shared.client
        guard let userId = supabase.auth.currentUser?.id else { return }
        
        do {
            struct UpdateGoal: Encodable {
                let weekly_goal_minutes: Int
            }
            
            try await supabase
                .from("profiles")
                .update(UpdateGoal(weekly_goal_minutes: minutes))
                .eq("id", value: userId.uuidString)
                .execute()
            
            weeklyGoalMinutes = minutes
            
            // Reload profile
            await fetchUserProfile()
        } catch {
            debugLog("Failed to update weekly goal: \(error)")
        }
    }
}

