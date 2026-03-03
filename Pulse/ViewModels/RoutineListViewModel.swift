//
//  RoutineListViewModel.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/8/26.
//

import Foundation
import Combine

@MainActor
class RoutineListViewModel: ObservableObject {
    @Published var routines: [Routine] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var routineExerciseCounts: [UUID: Int] = [:]
    private let routineRepository = RoutineRepository()
    
    private let repository = RoutineRepository()
    private let workoutRepository = WorkoutRepository()
    
    func loadRoutines() async {
        isLoading = true
        errorMessage = nil
        
        do {
            routines = try await routineRepository.fetchRoutines()
            
            // Load exercise counts for each routine
            for routine in routines {
                let exercises = try await routineRepository.fetchRoutineExercises(routineId: routine.id)
                routineExerciseCounts[routine.id] = exercises.count
            }
        } catch {
            errorMessage = "Failed to load routines: \(error.localizedDescription)"
        }
        
        isLoading = false
    }

    func exerciseCount(for routineId: UUID) -> Int {
        routineExerciseCounts[routineId] ?? 0
    }
    
    func createRoutine(name: String, description: String) async -> Routine? {
        do {
            let newRoutine = try await routineRepository.createRoutine(name: name, description: description)
            routines.append(newRoutine)
            return newRoutine
        } catch {
            errorMessage = "Failed to create routine: \(error.localizedDescription)"
            return nil
        }
    }
    
    func deleteRoutine(_ routine: Routine) async {
        do {
            // Mark all scheduled workouts and sessions for this routine as routine_deleted
            // so they are preserved for training history
            try await workoutRepository.markScheduledWorkoutsAsRoutineDeleted(routineId: routine.id)
            try await workoutRepository.markSessionsAsRoutineDeleted(routineId: routine.id)
            
            try await repository.deleteRoutine(id: routine.id)
            routines.removeAll { $0.id == routine.id}
        } catch {
            errorMessage = "Failed to delete routine: \(error.localizedDescription)"
        }
    }
}
