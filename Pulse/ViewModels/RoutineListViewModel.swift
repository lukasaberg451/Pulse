//
//  RoutineListViewModel.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/8/26.
//

import Foundation
import Combine
import SwiftUI
import SwiftData

@MainActor
class RoutineListViewModel: ObservableObject {
    @Published var routines: [Routine] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var actionError: String?
    @Published var routineExerciseCounts: [UUID: Int] = [:]
    private(set) var hasLoaded = false
    private let routineRepository = RoutineRepository()
    
    private let repository = RoutineRepository()
    private let workoutRepository = WorkoutRepository()
    private let syncService = WorkoutSyncService.shared
    private var cancellables = Set<AnyCancellable>()

    var modelContext: ModelContext?

    init() {
        NotificationCenter.default.publisher(for: .networkRestored)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.loadRoutines()
                }
            }
            .store(in: &cancellables)
    }

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
                
                let routineIds = routines.map { $0.id }
                let allRoutineExercises = try await routineRepository.fetchRoutineExercises(routineIds: routineIds)
                for (routineId, exercises) in allRoutineExercises {
                    routineExerciseCounts[routineId] = exercises.count
                }
            }
            hasLoaded = true
        } catch {
            errorMessage = String(localized: "Failed to load routines: \(error.localizedDescription)")
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
            NotificationCenter.default.post(name: .routineDataChanged, object: nil)
            return newRoutine
        } catch {
            actionError = String(localized: "Failed to create routine. Please try again.")
            return nil
        }
    }
    
    func duplicateRoutine(_ routine: Routine) async -> Routine? {
        do {
            let newRoutine = try await routineRepository.duplicateRoutine(
                fromRoutineId: routine.id,
                newName: String(localized: "\(routine.name) - Copy")
            )
            routines.append(newRoutine)
            
            // Load exercise count for the new routine
            let exercises = try await routineRepository.fetchRoutineExercises(routineId: newRoutine.id)
            routineExerciseCounts[newRoutine.id] = exercises.count
            
            NotificationCenter.default.post(name: .routineDataChanged, object: nil)
            return newRoutine
        } catch {
            actionError = String(localized: "Failed to duplicate routine. Please try again.")
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
            
            // Notify other views: schedule needs to remove deleted scheduled workouts,
            // dashboard needs to update today's workouts
            NotificationCenter.default.post(name: .routineDataChanged, object: nil)
            NotificationCenter.default.post(name: .workoutDataChanged, object: nil)
        } catch {
            actionError = String(localized: "Failed to delete routine. Please try again.")
        }
    }
    
    func deleteRoutines(_ routinesToDelete: [Routine]) async {
        // Remove all routines from the local list immediately to avoid
        // flickering reloads between individual deletions
        let idsToDelete = Set(routinesToDelete.map(\.id))
        withAnimation(.easeInOut(duration: 0.35)) {
            routines.removeAll { idsToDelete.contains($0.id) }
        }
        
        for routine in routinesToDelete {
            do {
                try await workoutRepository.deleteUncompletedScheduledWorkouts(routineId: routine.id)
                try await workoutRepository.markScheduledWorkoutsAsRoutineDeleted(routineId: routine.id)
                try await workoutRepository.markSessionsAsRoutineDeleted(routineId: routine.id)
                try await repository.deleteRoutine(id: routine.id)
            } catch {
                actionError = String(localized: "Failed to delete routine. Please try again.")
            }
        }
        
        // Notify other views once after all deletions are complete.
        // Pass self so RoutineContentView can ignore its own ViewModel's notifications.
        NotificationCenter.default.post(name: .routineDataChanged, object: self)
        NotificationCenter.default.post(name: .workoutDataChanged, object: nil)
    }
}
