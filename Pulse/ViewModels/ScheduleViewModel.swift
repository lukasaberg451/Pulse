//
//  ScheduleViewModel.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/8/26.
//

import Foundation
import Combine

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
    
    private let exerciseRepository = ExerciseRepository()
    private let workoutRepository = WorkoutRepository()
    private let routineRepository = RoutineRepository()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Listen for workout data changes
        NotificationCenter.default.publisher(for: .workoutDataChanged)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    print("📅 Schedule: Received workout data change notification, reloading...")
                    await self?.loadData()
                }
            }
            .store(in: &cancellables)
    }
    
    var currentMonthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }
    
    var calendarDays: [Date?] {
        var days: [Date?] = []
        
        let calendar = Calendar.current
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
    
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            //Load exercises first
            exercises = try await exerciseRepository.fetchExercises()
            
            // Load routines
            routines = try await routineRepository.fetchRoutines()
            
            // Load exercise counts for each routine
            for routine in routines {
                let routineExercises = try await routineRepository.fetchRoutineExercises(routineId: routine.id)
                routineExerciseCounts[routine.id] = routineExercises.count
                routineExerciseMap[routine.id] = routineExercises
            }

            // Load scheduled workouts for current month
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month], from: currentMonth)
            guard let startOfMonth = calendar.date(from: components),
                  let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
                return
            }
            
            scheduledWorkouts = try await workoutRepository.fetchScheduledWorkouts(
                startDate: startOfMonth,
                endDate: endOfMonth
            )
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
        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        Task { await loadData() }
    }
    
    func nextMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        Task { await loadData() }
    }
    
    func scheduleWorkout(routineId: UUID, date: Date) async {
        do {
            let scheduled = try await workoutRepository.scheduleWorkout(routineId: routineId, date: date)
            scheduledWorkouts.append(scheduled)
        } catch {
            errorMessage = "Failed to schedule workout: \(error.localizedDescription)"
        }
    }
    
    func scheduledWorkouts(for date: Date) -> [ScheduledWorkout] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        return scheduledWorkouts.filter { $0.scheduledDate == dateString }
    }
    
    func hasScheduledWorkout(on date: Date) -> Bool {
        !scheduledWorkouts(for: date).isEmpty
    }
    
    func isWorkoutCompleted(on date: Date) -> Bool {
        scheduledWorkouts(for: date).contains { $0.completed }
    }
    
    func routine(for id: UUID) -> Routine? {
        routines.first { $0.id == id }
    }
    
    func deleteScheduled(_ scheduled: ScheduledWorkout) async {
        do {
            try await workoutRepository.deleteScheduledWorkout(id: scheduled.id)
            scheduledWorkouts.removeAll { $0.id == scheduled.id }
        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }
}
