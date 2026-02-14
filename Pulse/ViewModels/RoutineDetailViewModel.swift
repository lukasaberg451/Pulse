//
//  RoutineDetailViewModel.swift
//  Pulse
//
//  Created by lukasaberg on 2/8/26.
//

import Foundation
import Combine

@MainActor
class RoutineDetailViewModel: ObservableObject {
    @Published var routineExercises: [RoutineExercise] = []
    @Published var exercises: [Exercise] = [] // For looking up exercise details
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let routine: Routine
    private let routineRepository = RoutineRepository()
    private let exerciseRepository = ExcerciseRepository()
    
    init(routine: Routine) {
        self.routine = routine
    }
    
    func loadRoutineExercises() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load all exercises first
            exercises = try await exerciseRepository.fetchExercises()
            
            // Then load routine exercises
            routineExercises = try await routineRepository.fetchRoutineExercises(routineId: routine.id)
        } catch {
            errorMessage = "Failed to load exercises: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func addExercise(exerciseId: UUID, sets: Int, repsTarget: String, restSeconds: Int) async {
        do {
            let orderIndex = routineExercises.count
            let newRoutineExercise = try await routineRepository.addExerciseToRoutine(
                routineId: routine.id,
                exerciseId: exerciseId,
                orderIndex: orderIndex,
                sets: sets,
                repsTarget: repsTarget,
                restSeconds: restSeconds
            )
            routineExercises.append(newRoutineExercise)
        } catch {
            errorMessage = "Failed to add exercise: \(error.localizedDescription)"
        }
    }
    
    // Helper to get exercise details by ID
    func getExercise(for routineExercise: RoutineExercise) -> Exercise? {
        exercises.first { $0.id == routineExercise.exerciseId }
    }
    
    func updateExercise(routineExercise: RoutineExercise, sets: Int, repsTarget: String, restSeconds: Int) async {
        do {
            try await routineRepository.updateRoutineExercise(
                id: routineExercise.id,
                sets: sets,
                repsTarget: repsTarget,
                restSeconds: restSeconds
            )
            await loadRoutineExercises()
        } catch {
            errorMessage = "Failed to update exercise: \(error.localizedDescription)"
        }
    }
    
    func deleteExercise(_ routineExercise: RoutineExercise) async {
        do {
            try await routineRepository.deleteRoutine(id: routineExercise.id)
            routineExercises.removeAll { $0.id == routineExercise.id }
        } catch {
            errorMessage = "Failed to delete exercise: \(error.localizedDescription)"
        }
    }
    
    func updateRoutineName(name: String, description: String?) async {
        do {
            try await routineRepository.updateRoutine(
                id: routine.id,
                name: name,
                description: description
            )
        } catch {
            errorMessage = "Failed to update routine: \(error.localizedDescription)"
        }
    }
}
