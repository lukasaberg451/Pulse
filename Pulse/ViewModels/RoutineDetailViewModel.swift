//
//  RoutineDetailViewModel.swift
//  Pulse
//
//  Created by lukasaberg on 2/8/26.
//

import Foundation
import Combine
import SwiftUI
import Supabase

@MainActor
class RoutineDetailViewModel: ObservableObject {
    @Published var routineExercises: [RoutineExercise] = []
    @Published var exercises: [Exercise] = [] // For looking up exercise details
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var routine: Routine
    
    private let routineRepository = RoutineRepository()
    private let exerciseRepository = ExerciseRepository()
    
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
    
    func addExercise(exerciseId: UUID, sets: Int, repsTarget: String?, targetWeight: Double?, durationSeconds: Int?, restSeconds: Int) async {
        do {
            let newExercise = try await routineRepository.addExerciseToRoutine(
                routineId: routine.id,
                exerciseId: exerciseId,
                sets: sets,
                repsTarget: repsTarget,
                targetWeight: targetWeight,
                durationSeconds: durationSeconds,
                restSeconds: restSeconds,
                orderIndex: routineExercises.count
            )
            routineExercises.append(newExercise)
        } catch {
            errorMessage = "Failed to add exercise: \(error.localizedDescription)"
        }
    }
    
    // Helper to get exercise details by ID
    func getExercise(for routineExercise: RoutineExercise) -> Exercise? {
        exercises.first { $0.id == routineExercise.exerciseId }
    }
    
    func updateExercise(id: UUID, sets: Int, repsTarget: String?, targetWeight: Double?, durationSeconds: Int?, restSeconds: Int) async {
        do {
            try await routineRepository.updateRoutineExercise(
                id: id,
                sets: sets,
                repsTarget: repsTarget,
                targetWeight: targetWeight,
                durationSeconds: durationSeconds,
                restSeconds: restSeconds
            )
            
            // Reload exercises
            await loadRoutineExercises()
        } catch {
            errorMessage = "Failed to update exercise: \(error.localizedDescription)"
        }
    }
    
    func deleteExercise(_ routineExercise: RoutineExercise) async {
        do {
            try await routineRepository.deleteRoutineExercise(id: routineExercise.id)
            routineExercises.removeAll { $0.id == routineExercise.id }
        } catch {
            errorMessage = "Failed to delete exercise: \(error.localizedDescription)"
        }
    }

    func updateRoutine(name: String, description: String) async {
        do {
            try await routineRepository.updateRoutine(id: routine.id, name: name, description: description)
            
            // Reload the routine to get fresh data
            let updatedRoutine = try await routineRepository.fetchRoutine(id: routine.id)
            self.routine = updatedRoutine
            
        } catch {
            errorMessage = "Failed to update routine: \(error.localizedDescription)"
        }
    }
    
    func loadExercises() async {
        do {
            exercises = try await exerciseRepository.fetchAllExercises()
        } catch {
            errorMessage = "Failed to load exercises: \(error.localizedDescription)"
        }
    }
    
    func moveExercise(from source: IndexSet, to destination: Int) async {
        var exercises = routineExercises
        exercises.move(fromOffsets: source, toOffset: destination)
        
        // Update order_index for all exercises
        do {
            for (index, exercise) in exercises.enumerated() {
                try await routineRepository.updateExerciseOrder(
                    id: exercise.id,
                    orderIndex: index
                )
            }
            
            // Reload to reflect new order
            await loadRoutineExercises()
        } catch {
            errorMessage = "Failed to reorder exercises: \(error.localizedDescription)"
        }
    }
}
