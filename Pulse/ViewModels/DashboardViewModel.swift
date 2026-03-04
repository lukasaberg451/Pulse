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
    @Published var currentInsight: SmartInsight?
    
    private var insightQueue: [SmartInsight] = []
    private var insightIndex: Int = 0
    private var insightTimer: Timer?
    
    private let workoutRepository = WorkoutRepository()
    private let routineRepository = RoutineRepository()
    private let exerciseRepository = ExerciseRepository()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Listen for workout data changes
        NotificationCenter.default.publisher(for: .workoutDataChanged)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    print("📢 Received workout data change notification, reloading...")
                    await self?.loadData()
                    await self?.loadWeeklyProgress()
                    await self?.calculateStreak()
                    await self?.loadLatestPR()
                    self?.loadInsights()
                }
            }
            .store(in: &cancellables)
    }
    
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            await fetchUserProfile()
            //Load exercises first
            exercises = try await exerciseRepository.fetchAllExercises()
            
            // Load routines
            routines = try await routineRepository.fetchRoutines()
            
            // Load exercise counts for each routine
            for routine in routines {
                let routineExercises = try await routineRepository.fetchRoutineExercises(routineId: routine.id)
                routineExerciseCounts[routine.id] = routineExercises.count
                routineExercisesMap[routine.id] = routineExercises
                
                // Ensure all exercises referenced by routine exercises are loaded
                for routineExercise in routineExercises {
                    if !exercises.contains(where: { $0.id == routineExercise.exerciseId }) {
                        do {
                            let exercise = try await exerciseRepository.fetchExercise(id: routineExercise.exerciseId)
                            exercises.append(exercise)
                        } catch {
                            print("⚠️ Failed to load exercise \(routineExercise.exerciseId): \(error)")
                        }
                    }
                }
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
            
            //Load recently completed (last 5)
            let allSessions = try await workoutRepository.fetchSessions()
            print("📊 Loaded \(allSessions.count) total sessions from server")
            
            // Build session lookup for today's workouts
            let todaySessionIds = Set(todaysWorkouts.compactMap { $0.workoutSessionId })
            for session in allSessions where todaySessionIds.contains(session.id) {
                workoutSessions[session.id] = session
            }
            
            recentSessions = Array(allSessions.filter { $0.completedAt != nil}.prefix(5))
            print("📊 Filtered to \(recentSessions.count) recent completed sessions")
            if !recentSessions.isEmpty {
                print("📊 Recent sessions: \(recentSessions.map { "\($0.name) (ID: \($0.id))" }.joined(separator: ", "))")
            }
            
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
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
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
        } catch {
            print("Failed to fetch user profile: \(error)")
        }
    }
    
    func loadWeeklyProgress() async {
        // Get start of current week (Monday)
        let calendar = userProfile?.userCalendar ?? Calendar.current
        let now = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
              let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
            return
        }
        
        do {
            let supabase = SupabaseManager.shared.client
            
            // Fetch all completed sessions from this week
            let sessions: [WorkoutSession] = try await supabase
                .from("workout_sessions")
                .select()
                .eq("user_id", value: supabase.auth.currentUser?.id.uuidString ?? "")
                .gte("started_at", value: ISO8601DateFormatter().string(from: weekStart))
                .lt("started_at", value: ISO8601DateFormatter().string(from: weekEnd))
                .not("completed_at", operator: .is, value: "null")
                .execute()
                .value
            
            // Sum up the duration
            weeklyWorkoutMinutes = sessions.reduce(0) { total, session in
                total + ((session.durationSeconds ?? 0) / 60)
            }
            
            // Get user's weekly goal
            if let profile = userProfile {
                weeklyGoalMinutes = profile.weeklyGoalMinutes ?? 150
            }
        } catch {
            print("Failed to load weekly progress: \(error)")
        }
    }

    func calculateStreak() async {
        let supabase = SupabaseManager.shared.client
        guard let userId = supabase.auth.currentUser?.id else { return }
        
        do {
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
            
            for session in sessions {
                let date = session.completedAt ?? session.startedAt
                let dayStart = calendar.startOfDay(for: date)
                workoutDates.insert(dayStart)
            }
            
            let sortedDates = workoutDates.sorted(by: >)
            
            // Calculate current streak
            let today = calendar.startOfDay(for: Date())
            var streak = 0
            var checkDate = today
            
            for date in sortedDates {
                if date == checkDate {
                    streak += 1
                    checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
                } else if calendar.dateComponents([.day], from: date, to: checkDate).day == 1 {
                    streak += 1
                    checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
                } else {
                    break
                }
            }
            
            if let firstDate = sortedDates.first {
                let daysDiff = calendar.dateComponents([.day], from: firstDate, to: today).day ?? 0
                if daysDiff > 1 {
                    streak = 0
                }
            }
            
            currentStreak = streak
            
            // Calculate best streak
            var maxStreak = 0
            var tempStreak = 0
            var previousDate: Date? = nil
            
            for date in sortedDates.reversed() {
                if let prev = previousDate {
                    let daysDiff = calendar.dateComponents([.day], from: prev, to: date).day ?? 0
                    if daysDiff <= 1 {
                        tempStreak += 1
                    } else {
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
            print("Failed to calculate streak: \(error)")
            currentStreak = 0
            bestStreak = 0
        }
    }
    
    func loadLatestPR() async {
        let supabase = SupabaseManager.shared.client
        guard let userId = supabase.auth.currentUser?.id else { return }
        
        do {
            let sessions: [WorkoutSession] = try await supabase
                .from("workout_sessions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .not("completed_at", operator: .is, value: "null")
                .execute()
                .value
            
            guard !sessions.isEmpty else {
                latestPR = nil
                return
            }
            
            let sets: [WorkoutSet] = try await supabase
                .from("workout_sets")
                .select()
                .in("session_id", values: sessions.map { $0.id.uuidString })
                .eq("completed", value: true)
                .not("weight", operator: .is, value: "null")
                .not("reps", operator: .is, value: "null")
                .execute()
                .value
            
            let allExercises: [Exercise] = try await supabase
                .from("exercises")
                .select()
                .execute()
                .value
            
            let exerciseDict = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.id, $0) })
            
            // Group sets by exercise and find the best set per exercise
            let setsByExercise = Dictionary(grouping: sets, by: { $0.exerciseId })
            var personalRecords: [PersonalRecord] = []
            
            for (exerciseId, exerciseSets) in setsByExercise {
                guard let exercise = exerciseDict[exerciseId],
                      exercise.exerciseType?.lowercased() != "cardio" else { continue }
                
                let sortedSets = exerciseSets.sorted { set1, set2 in
                    let score1 = (set1.weight ?? 0) * Double(set1.reps ?? 0)
                    let score2 = (set2.weight ?? 0) * Double(set2.reps ?? 0)
                    return score1 > score2
                }
                
                if let bestSet = sortedSets.first,
                   let weight = bestSet.weight,
                   let reps = bestSet.reps,
                   let session = sessions.first(where: { $0.id == bestSet.sessionId }) {
                    personalRecords.append(PersonalRecord(
                        exerciseName: exercise.name,
                        weight: weight,
                        reps: reps,
                        date: session.completedAt ?? session.startedAt
                    ))
                }
            }
            
            // Get the most recent PR
            latestPR = personalRecords.sorted { $0.date > $1.date }.first
            
        } catch {
            print("Failed to load latest PR: \(error)")
            latestPR = nil
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
            print("Failed to update weekly goal: \(error)")
        }
    }
    
    // MARK: - Smart Insights
    
    func loadInsights() {
        insightQueue = generatePlaceholderInsights().shuffled()
        insightIndex = 0
        if !insightQueue.isEmpty {
            currentInsight = insightQueue[0]
        }
    }
    
    func advanceInsight() {
        guard !insightQueue.isEmpty else { return }
        insightIndex = (insightIndex + 1) % insightQueue.count
        withAnimation(.easeInOut(duration: 0.4)) {
            currentInsight = insightQueue[insightIndex]
        }
    }
    
    func startInsightRotation() {
        stopInsightRotation()
        insightTimer = Timer.scheduledTimer(withTimeInterval: 45.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.advanceInsight()
            }
        }
    }
    
    func stopInsightRotation() {
        insightTimer?.invalidate()
        insightTimer = nil
    }
    
    private func generatePlaceholderInsights() -> [SmartInsight] {
        [
            SmartInsight(
                type: .consistencyPattern,
                icon: "calendar.badge.checkmark",
                text: "Consistency beats intensity. Show up today and results will follow",
                accentColor: .blue
            ),
            SmartInsight(
                type: .streakProtection,
                icon: "flame.fill",
                text: "Even a short session counts. Keep your momentum going today",
                accentColor: .orange
            ),
            SmartInsight(
                type: .progressiveOverload,
                icon: "arrow.up.circle.fill",
                text: "Try adding a little more weight or one extra rep today",
                accentColor: .green
            ),
            SmartInsight(
                type: .recoveryIntelligence,
                icon: "bed.double.fill",
                text: "Rest days build muscle too. Listen to your body",
                accentColor: .purple
            ),
            SmartInsight(
                type: .momentumHighlight,
                icon: "bolt.fill",
                text: "Every rep brings you closer to your goals. Keep pushing",
                accentColor: .yellow
            ),
            SmartInsight(
                type: .habitTimeDetection,
                icon: "clock.fill",
                text: "The best time to work out is the time you'll actually do it",
                accentColor: .cyan
            ),
            SmartInsight(
                type: .weakPointDetection,
                icon: "figure.strengthtraining.traditional",
                text: "A balanced routine builds a stronger body. Mix it up",
                accentColor: .red
            ),
            SmartInsight(
                type: .microGoalMotivation,
                icon: "figure.walk",
                text: "Small steps lead to big results. Start with what feels easy",
                accentColor: .mint
            ),
            SmartInsight(
                type: .performanceTrend,
                icon: "chart.line.uptrend.xyaxis",
                text: "Progress isn't always visible. Trust the process",
                accentColor: .green
            ),
            SmartInsight(
                type: .returnMotivation,
                icon: "hand.wave.fill",
                text: "The hardest part is starting. You've got this",
                accentColor: .orange
            ),
        ]
    }
}
