//
//  ProgressViewModel.swift
//  Pulse
//
//  Created by lukasaberg on 2/10/26.
//

import Foundation
import Combine

@MainActor
class ProgressViewModel: ObservableObject {
    @Published var todaysWorkouts: [ScheduledWorkout] = []
    @Published var recentSessions: [WorkoutSession] = []
    @Published var routines: [Routine] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var routineExercisesMap: [UUID: [RoutineExercise]] = [:]
    @Published var routineExerciseCounts: [UUID: Int] = [:]
    @Published var exercises: [Exercise] = []
    
    private let workoutRepository = WorkoutRepository()
    private let routineRepository = RoutineRepository()
    private let exerciseRepository = ExcerciseRepository()
    
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
            recentSessions = Array(allSessions.filter { $0.completedAt != nil}.prefix(5))
            
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
}
