//
//  RoutineListViewModel.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/8/26.
//

import Foundation
import Combine
import SwiftData

@MainActor
class RoutineListViewModel: ObservableObject {
    @Published var routines: [Routine] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var routineExerciseCounts: [UUID: Int] = [:]
    private let routineRepository = RoutineRepository()
    
    private let repository = RoutineRepository()
    private let workoutRepository = WorkoutRepository()
    private let syncService = WorkoutSyncService.shared
    
    var modelContext: ModelContext?
    
    func loadRoutines() async {
        isLoading = true
        errorMessage = nil
        
        do {
            if let modelContext = modelContext {
                let offlineRepo = OfflineExerciseRepository(modelContext: modelContext)
                
                routines = try await offlineRepo.getRoutines(
                    forceRefresh: syncService.isOnline
                )
                
                for routine in routines {
                    let exercises = try await offlineRepo.getRoutineExercises(
                        routineId: routine.id,
                        forceRefresh: syncService.isOnline
                    )
                    routineExerciseCounts[routine.id] = exercises.count
                }
            } else {
                routines = try await routineRepository.fetchRoutines()
                
                for routine in routines {
                    let exercises = try await routineRepository.fetchRoutineExercises(routineId: routine.id)
                    routineExerciseCounts[routine.id] = exercises.count
                }
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
    
    func duplicateRoutine(_ routine: Routine) async -> Routine? {
        do {
            let newRoutine = try await routineRepository.duplicateRoutine(
                fromRoutineId: routine.id,
                newName: "\(routine.name) - Copy"
            )
            routines.append(newRoutine)
            
            // Load exercise count for the new routine
            let exercises = try await routineRepository.fetchRoutineExercises(routineId: newRoutine.id)
            routineExerciseCounts[newRoutine.id] = exercises.count
            
            return newRoutine
        } catch {
            errorMessage = "Failed to duplicate routine: \(error.localizedDescription)"
            return nil
        }
    }
    
    func deleteRoutine(_ routine: Routine) async {
        do {
            // Delete uncompleted scheduled workouts (and their sessions) for this routine
            try await workoutRepository.deleteUncompletedScheduledWorkouts(routineId: routine.id)
            
            // Mark remaining (completed) scheduled workouts and sessions as routine_deleted
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
