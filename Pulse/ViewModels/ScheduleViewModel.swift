//
//  ScheduleViewModel.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/8/26.
//

import Foundation
import Combine
import Supabase

@MainActor
class ScheduleViewModel: ObservableObject {
    @Published var scheduledWorkouts: [ScheduledWorkout] = []
    @Published var routines: [Routine] = []
    @Published var currentMonth = Date()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var routineExerciseCounts: [UUID: Int] = [:]
    @Published var routineExerciseMap: [UUID: [RoutineExercise]] = [:]
    @Published var exercises: [Exercise] = []
    @Published var workoutSessions: [UUID: WorkoutSession] = [:]
    
    private(set) var hasLoaded = false
    private(set) var userProfile: Profile?
    
    var userCalendar: Calendar {
        userProfile?.userCalendar ?? Calendar.current
    }
    private let exerciseRepository = ExerciseRepository()
    private let workoutRepository = WorkoutRepository()
    private let routineRepository = RoutineRepository()
    private var cancellables = Set<AnyCancellable>()
    private var isSelfPosting = false
    
    init() {
        // Listen for workout data changes (skip self-posted notifications)
        NotificationCenter.default.publisher(for: .workoutDataChanged)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, !self.isSelfPosting else { return }
                    debugLog("📅 Schedule: Received workout data change notification, reloading...")
                    await self.loadData()
                }
            }
            .store(in: &cancellables)
        
        // Listen for routine data changes (create, delete, duplicate)
        NotificationCenter.default.publisher(for: .routineDataChanged)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    debugLog("📅 Schedule: Received routine data change notification, reloading...")
                    await self?.loadData()
                }
            }
            .store(in: &cancellables)
    }
    
    var currentMonthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.timeZone = userProfile?.resolvedTimeZone ?? .current
        return formatter.string(from: currentMonth)
    }
    
    var calendarDays: [Date?] {
        var days: [Date?] = []
        
        let calendar = userProfile?.userCalendar ?? Calendar.current
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let firstOfMonth = calendar.date(from: components) else { return [] }
        
        // Get the weekday of the first day (1 = Sunday, 2 = Monday, etc.)
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        
        // Adjust for Monday start (weekday 2 becomes 0, Sunday becomes 6)
        let adjustedFirstWeekday = firstWeekday == 1 ? 6 : firstWeekday - 2
        
        // Add empty cells for days before the first
        for _ in 0..<adjustedFirstWeekday {
            days.append(nil)
        }
        
        // Add all days of the month
        let range = calendar.range(of: .day, in: .month, for: firstOfMonth)!
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private func fetchUserProfile() async {
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
            debugLog("Failed to fetch user profile: \(error)")
        }
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
                routineExerciseMap[routine.id] = routineExercises
                
                // Ensure all exercises referenced by routine exercises are loaded
                for routineExercise in routineExercises {
                    if !exercises.contains(where: { $0.id == routineExercise.exerciseId }) {
                        do {
                            let exercise = try await exerciseRepository.fetchExercise(id: routineExercise.exerciseId)
                            exercises.append(exercise)
                        } catch {
                            debugLog("⚠️ Failed to load exercise \(routineExercise.exerciseId): \(error)")
                        }
                    }
                }
            }

            // Load scheduled workouts for current month
            let calendar = userProfile?.userCalendar ?? Calendar.current
            let components = calendar.dateComponents([.year, .month], from: currentMonth)
            guard let startOfMonth = calendar.date(from: components),
                  let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
                return
            }
            
            let tz = userProfile?.resolvedTimeZone ?? .current
            scheduledWorkouts = try await workoutRepository.fetchScheduledWorkouts(
                startDate: startOfMonth,
                endDate: endOfMonth,
                timeZone: tz
            )
            
            // Load workout sessions for completed scheduled workouts
            let completedSessionIds = scheduledWorkouts
                .filter { $0.completed }
                .compactMap { $0.workoutSessionId }
            
            if !completedSessionIds.isEmpty {
                let allSessions = try await workoutRepository.fetchSessions()
                for session in allSessions {
                    if completedSessionIds.contains(session.id) {
                        workoutSessions[session.id] = session
                    }
                }
            }
            hasLoaded = true
        } catch {
            errorMessage = "Failed to load data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func routineExercises(for routineId: UUID) -> [RoutineExercise] {
        routineExerciseMap[routineId] ?? []
    }

    func exerciseCount(for routineId: UUID) -> Int {
        routineExerciseCounts[routineId] ?? 0
    }
    
    func previousMonth() {
        let calendar = userProfile?.userCalendar ?? Calendar.current
        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        Task { await loadData() }
    }
    
    func nextMonth() {
        let calendar = userProfile?.userCalendar ?? Calendar.current
        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        Task { await loadData() }
    }
    
    func scheduleWorkout(routineId: UUID, date: Date) async {
        do {
            let tz = userProfile?.resolvedTimeZone ?? .current
            let scheduled = try await workoutRepository.scheduleWorkout(routineId: routineId, date: date, timeZone: tz)
            scheduledWorkouts.append(scheduled)
            isSelfPosting = true
            NotificationCenter.default.post(name: .workoutDataChanged, object: nil)
            isSelfPosting = false
        } catch {
            errorMessage = "Failed to schedule workout: \(error.localizedDescription)"
        }
    }
    
    func scheduledWorkouts(for date: Date) -> [ScheduledWorkout] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = userProfile?.resolvedTimeZone ?? TimeZone.current
        let dateString = formatter.string(from: date)
        
        return scheduledWorkouts
            .filter { $0.scheduledDate == dateString }
            .sorted { !$0.completed && $1.completed }
    }
    
    func hasScheduledWorkout(on date: Date) -> Bool {
        !scheduledWorkouts(for: date).isEmpty
    }
    
    func isWorkoutCompleted(on date: Date) -> Bool {
        scheduledWorkouts(for: date).contains { $0.completed }
    }
    
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.timeZone = userProfile?.resolvedTimeZone ?? .current
        return formatter.string(from: date)
    }
    
    func routine(for id: UUID) -> Routine? {
        routines.first { $0.id == id }
    }
    
    func workoutSession(for sessionId: UUID) -> WorkoutSession? {
        workoutSessions[sessionId]
    }
    
    func deleteScheduled(_ scheduled: ScheduledWorkout) async {
        do {
            try await workoutRepository.deleteScheduledWorkout(id: scheduled.id)
            scheduledWorkouts.removeAll { $0.id == scheduled.id }
            isSelfPosting = true
            NotificationCenter.default.post(name: .workoutDataChanged, object: nil)
            isSelfPosting = false
        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }
    
    func deleteScheduledWorkouts(_ workoutsToDelete: [ScheduledWorkout]) async {
        for workout in workoutsToDelete {
            do {
                try await workoutRepository.deleteScheduledWorkout(id: workout.id)
            } catch {
                errorMessage = "Failed to delete: \(error.localizedDescription)"
            }
        }
    }
    
    func removeScheduledLocally(_ ids: Set<UUID>) {
        scheduledWorkouts.removeAll { ids.contains($0.id) }
        isSelfPosting = true
        NotificationCenter.default.post(name: .workoutDataChanged, object: nil)
        isSelfPosting = false
    }
}
