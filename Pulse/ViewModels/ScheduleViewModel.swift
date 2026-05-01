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
    @Published var workoutSessions: [UUID: WorkoutSession] = [:]
    @Published var sessionExerciseCounts: [UUID: Int] = [:]
    
    /// Exercises are accessed via the singleton cache to avoid storing a
    /// duplicate copy of the entire exercises table in this view model.
    var exercises: [Exercise] { exerciseRepository.exercises }
    
    private(set) var hasLoaded = false
    private(set) var userProfile: Profile?
    
    var userCalendar: Calendar {
        userProfile?.userCalendar ?? Calendar.current
    }
    private let exerciseRepository = ExerciseRepository.shared
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
        let formatter = SharedFormatters.monthYear
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
        } catch is CancellationError {
            // Ignore — a newer refresh replaced this one
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            // Ignore URL session cancellation
        } catch {
            debugLog("Failed to fetch user profile: \(error)")
        }
    }
    
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            await fetchUserProfile()
            
            // Warm the exercise cache (shared singleton — no local copy stored)
            _ = try await exerciseRepository.fetchAllExercises()
            
            // Load routines
            routines = try await routineRepository.fetchRoutines()
            
            // Load all routine exercises in a single batch query
            let routineIds = routines.map { $0.id }
            let allRoutineExercises = try await routineRepository.fetchRoutineExercises(routineIds: routineIds)
            routineExerciseMap = allRoutineExercises
            for (routineId, exercises) in allRoutineExercises {
                routineExerciseCounts[routineId] = exercises.count
            }

            // Load scheduled workouts for current month
            let calendar = userProfile?.userCalendar ?? Calendar.current
            let components = calendar.dateComponents([.year, .month], from: currentMonth)
            guard let startOfMonth = calendar.date(from: components),
                  let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
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
            
            for sessionId in completedSessionIds {
                let sessions: [WorkoutSession] = try await SupabaseManager.shared.client
                    .from("workout_sessions")
                    .select()
                    .eq("id", value: sessionId.uuidString)
                    .limit(1)
                    .execute()
                    .value
                if let session = sessions.first {
                    workoutSessions[session.id] = session
                }

                let sets = try await workoutRepository.fetchSets(sessionId: sessionId)
                let uniqueExerciseIds = Set(sets.map(\.exerciseId))
                sessionExerciseCounts[sessionId] = uniqueExerciseIds.count
            }
            hasLoaded = true
        } catch {
            errorMessage = String(localized: "Failed to load data: \(error.localizedDescription)")
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
            errorMessage = String(localized: "Failed to schedule workout: \(error.localizedDescription)")
        }
    }
    
    func scheduledWorkouts(for date: Date) -> [ScheduledWorkout] {
        let formatter = SharedFormatters.yearMonthDay
        formatter.timeZone = userProfile?.resolvedTimeZone ?? TimeZone.current
        let dateString = formatter.string(from: date)
        
        return scheduledWorkouts
            .filter { $0.scheduledDate == dateString }
            .sorted { a, b in
                // Uncompleted first, then completed sorted by most recently completed
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
    }
    
    func hasScheduledWorkout(on date: Date) -> Bool {
        !scheduledWorkouts(for: date).isEmpty
    }
    
    func isWorkoutCompleted(on date: Date) -> Bool {
        scheduledWorkouts(for: date).contains { $0.completed }
    }
    
    func formattedDate(_ date: Date) -> String {
        let formatter = SharedFormatters.mediumDate
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
            errorMessage = String(localized: "Failed to delete: \(error.localizedDescription)")
        }
    }
    
    func deleteScheduledWorkouts(_ workoutsToDelete: [ScheduledWorkout]) async {
        for workout in workoutsToDelete {
            do {
                try await workoutRepository.deleteScheduledWorkout(id: workout.id)
            } catch {
                errorMessage = String(localized: "Failed to delete: \(error.localizedDescription)")
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
