//
//  RoutineDetailViewModel.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/8/26.
//

import Foundation
import Combine
import SwiftUI
import Supabase
import SwiftData

@MainActor
class RoutineDetailViewModel: ObservableObject {
    @Published var routineExercises: [RoutineExercise] = []
    @Published var exercises: [Exercise] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var actionError: String?
    @Published var routine: Routine
    
    private let routineRepository = RoutineRepository()
    private let exerciseRepository = ExerciseRepository.shared
    private let syncService = WorkoutSyncService.shared
    
    // Optional: Inject model context for offline support
    var modelContext: ModelContext?
    
    init(routine: Routine) {
        self.routine = routine
    }
    
    func loadRoutineExercises(forceRefresh: Bool = false, silent: Bool = false) async {
        if !silent {
            isLoading = true
        }
        errorMessage = nil
        
        do {
            // Try to use offline repository if available
            if let modelContext = modelContext {
                let offlineRepo = OfflineExerciseRepository(modelContext: modelContext)
                
                // Load routine exercises (from cache or Supabase)
                routineExercises = try await offlineRepo.getRoutineExercises(
                    routineId: routine.id,
                    forceRefresh: forceRefresh || syncService.isOnline
                )
                
                // Load exercises (from cache) - this should now include newly cached exercises
                exercises = try offlineRepo.getCachedExercises()
                
                // Ensure all exercises for the routine exercises are loaded
                for routineExercise in routineExercises {
                    if !exercises.contains(where: { $0.id == routineExercise.exerciseId }) {
                        // Fetch and cache this exercise if it's missing
                        do {
                            let exercise = try await offlineRepo.getExercise(id: routineExercise.exerciseId)
                            exercises.append(exercise)
                        } catch {
                            debugLog("⚠️ Failed to load exercise \(routineExercise.exerciseId): \(error)")
                        }
                    }
                }
            } else {
                // Fallback to direct Supabase queries
                exercises = try await exerciseRepository.fetchAllExercises()
                routineExercises = try await routineRepository.fetchRoutineExercises(routineId: routine.id)
                
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
        } catch {
            errorMessage = String(localized: "Failed to load exercises: \(error.localizedDescription)")
        }

        if !silent {
            isLoading = false
        }
    }
    
    func addExercise(exerciseId: UUID, sets: Int, repsTarget: String?, targetWeight: Double?, durationSeconds: Int?, restSeconds: Int, notes: String? = nil) async {
        do {
            let nextOrderIndex = (routineExercises.map(\.orderIndex).max() ?? -1) + 1
            let newExercise = try await routineRepository.addExerciseToRoutine(
                routineId: routine.id,
                exerciseId: exerciseId,
                sets: sets,
                repsTarget: repsTarget,
                targetWeight: targetWeight,
                durationSeconds: durationSeconds,
                restSeconds: restSeconds,
                orderIndex: nextOrderIndex,
                notes: notes
            )
            routineExercises.append(newExercise)
            NotificationCenter.default.post(name: .routineDataChanged, object: nil)
        } catch {
            actionError = String(localized: "Failed to add exercise. Please try again.")
        }
    }
    
    // Helper to get exercise details by ID
    func getExercise(for routineExercise: RoutineExercise) -> Exercise? {
        exercises.first { $0.id == routineExercise.exerciseId }
    }
    
    func updateExercise(id: UUID, sets: Int, repsTarget: String?, targetWeight: Double?, durationSeconds: Int?, restSeconds: Int, notes: String? = nil) async {
        do {
            try await routineRepository.updateRoutineExercise(
                id: id,
                sets: sets,
                repsTarget: repsTarget,
                targetWeight: targetWeight,
                durationSeconds: durationSeconds,
                restSeconds: restSeconds,
                notes: notes
            )
            
            // Reload exercises
            await loadRoutineExercises()
        } catch {
            actionError = String(localized: "Failed to update exercise. Please try again.")
        }
    }
    
    func deleteExercise(_ routineExercise: RoutineExercise) async {
        do {
            try await routineRepository.deleteRoutineExercise(id: routineExercise.id)
            routineExercises.removeAll { $0.id == routineExercise.id }
            NotificationCenter.default.post(name: .routineDataChanged, object: nil)
        } catch {
            actionError = String(localized: "Failed to delete exercise. Please try again.")
        }
    }

    func updateRoutine(name: String, description: String) async {
        do {
            try await routineRepository.updateRoutine(id: routine.id, name: name, description: description)
            
            // Reload the routine to get fresh data
            let updatedRoutine = try await routineRepository.fetchRoutine(id: routine.id)
            self.routine = updatedRoutine
            
            NotificationCenter.default.post(name: .routineDataChanged, object: nil)
            
        } catch {
            actionError = String(localized: "Failed to update routine. Please try again.")
        }
    }
    
    func duplicateRoutine() async -> Routine? {
        do {
            let newRoutine = try await routineRepository.duplicateRoutine(
                fromRoutineId: routine.id,
                newName: String(localized: "\(routine.name) - Copy")
            )
            NotificationCenter.default.post(name: .routineDataChanged, object: nil)
            return newRoutine
        } catch {
            actionError = String(localized: "Failed to duplicate routine. Please try again.")
            return nil
        }
    }
    
    func loadExercises() async {
        do {
            // Try to use offline repository if available
            if let modelContext = modelContext {
                let offlineRepo = OfflineExerciseRepository(modelContext: modelContext)
                exercises = try offlineRepo.getCachedExercises()
            } else {
                // Fallback to direct Supabase query
                exercises = try await exerciseRepository.fetchAllExercises()
            }
        } catch {
            errorMessage = String(localized: "Failed to load exercises: \(error.localizedDescription)")
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
            actionError = String(localized: "Failed to reorder exercises. Please try again.")
        }
    }
    
    func saveExerciseOrder(_ orderedExercises: [RoutineExercise]) async {
        do {
            for (index, exercise) in orderedExercises.enumerated() {
                try await routineRepository.updateExerciseOrder(
                    id: exercise.id,
                    orderIndex: index
                )
            }

            routineExercises = orderedExercises

            // Silent reload to ensure consistency — skip isLoading to avoid a flash
            await loadRoutineExercises(silent: true)
        } catch {
            actionError = String(localized: "Failed to save exercise order. Please try again.")
        }
    }
}
