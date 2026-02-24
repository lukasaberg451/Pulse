//
//  DashboardViewModel.swift
//  Pulse
//
//  Created by lukasaberg on 2/10/26.
//

import Foundation
import Combine
import Supabase

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
            exercises = try await exerciseRepository.fetchExercises()
            
            // Load routines
            routines = try await routineRepository.fetchRoutines()
            
            // Load exercise counts for each routine
            for routine in routines {
                let routineExercises = try await routineRepository.fetchRoutineExercises(routineId: routine.id)
                routineExerciseCounts[routine.id] = routineExercises.count
                routineExercisesMap[routine.id] = routineExercises
            }
            
            // Load todays workouts
            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: Date())
            guard let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
                isLoading = false
                return
            }
            
            todaysWorkouts = try await workoutRepository.fetchScheduledWorkouts(
                startDate: startOfToday,
                endDate: endOfToday
            )
            
            //Load recently completed (last 5)
            let allSessions = try await workoutRepository.fetchSessions()
            print("📊 Loaded \(allSessions.count) total sessions from server")
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
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
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
        let calendar = Calendar.current
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
}
