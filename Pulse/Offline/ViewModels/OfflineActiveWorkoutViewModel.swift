//
//  OfflineActiveWorkoutViewModel.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-24.
//

import Foundation
import SwiftData
import Combine

@MainActor
class OfflineActiveWorkoutViewModel: ObservableObject {
    @Published var sets: [LocalWorkoutSet] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var elapsedTime: TimeInterval = 0
    @Published var isRestTimerActive = false
    @Published var restTimeRemaining: Int = 0
    @Published var isOfflineMode = false
    
    private let scheduledWorkoutId: UUID?
    private let exercises: [Exercise]
    
    let routine: Routine
    var routineExercises: [RoutineExercise]
    
    private var currentSession: LocalWorkoutSession?
    private var startTime: Date?
    private var workoutTimer: Timer?
    private var restTimer: Timer?
    private let offlineRepository: OfflineWorkoutRepository
    private let syncService: WorkoutSyncService
    
    init(
        routine: Routine,
        routineExercises: [RoutineExercise],
        scheduledWorkoutId: UUID? = nil,
        exercises: [Exercise],
        modelContext: ModelContext
    ) {
        self.routine = routine
        self.routineExercises = routineExercises
        self.scheduledWorkoutId = scheduledWorkoutId
        self.exercises = exercises
        self.offlineRepository = OfflineWorkoutRepository(modelContext: modelContext)
        self.syncService = WorkoutSyncService.shared
        
        // Monitor network status
        self.isOfflineMode = !syncService.isOnline
        
        NotificationCenter.default.addObserver(
            forName: .setCompletedFromWatch,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let exerciseIdString = userInfo["exerciseId"] as? String,
                  let exerciseId = UUID(uuidString: exerciseIdString),
                  let setNumber = userInfo["setNumber"] as? Int,
                  let reps = userInfo["reps"] as? Int,
                  let weight = userInfo["weight"] as? Double else { return }
            
            Task { @MainActor in
                await self.handleWatchSetCompleted(
                    exerciseId: exerciseId,
                    setNumber: setNumber,
                    reps: reps,
                    weight: weight
                )
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .skipRestFromWatch,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.stopRestTimer()
            }
        }
    }
    
    private func handleWatchSetCompleted(
        exerciseId: UUID,
        setNumber: Int,
        reps: Int,
        weight: Double
    ) async {
        guard let currentRoutineExercise = routineExercises.first,
              currentRoutineExercise.exerciseId == exerciseId else {
            return
        }
        
        if let setIndex = sets.firstIndex(where: {
            $0.exerciseId == exerciseId &&
            $0.setNumber == setNumber &&
            !$0.completed
        }) {
            let set = sets[setIndex]
            updateSet(
                set: set,
                reps: reps,
                weight: weight,
                durationSeconds: nil,
                completed: true
            )
        }
    }
    
    func startWorkout() async {
        isLoading = true
        startTime = Date()
        
        // Start elapsed time timer
        startWorkoutTimer()
        
        // Create the workout session locally
        let session = offlineRepository.createSession(
            name: routine.name,
            routineId: routine.id
        )
        currentSession = session
        
        // Create placeholder sets for each exercise
        for routineExercise in routineExercises {
            for setNumber in 1...routineExercise.sets {
                let set = offlineRepository.createSet(
                    session: session,
                    exerciseId: routineExercise.exerciseId,
                    setNumber: setNumber,
                    reps: nil,
                    weight: nil
                )
                sets.append(set)
            }
        }
        
        // Send to Watch with start time
        if let startTime = startTime {
            WorkoutSyncManager.shared.sendWorkoutToWatch(
                routine: routine,
                routineExercises: routineExercises,
                exercises: exercises,
                startTime: startTime
            )
        }
        
        isLoading = false
    }
    
    private func startWorkoutTimer() {
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                guard let startTime = self.startTime else { return }
                self.elapsedTime = Date().timeIntervalSince(startTime)
            }
        }
    }
        
    func startRestTimer(seconds: Int) {
        restTimeRemaining = seconds
        isRestTimerActive = true
        
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            Task { @MainActor in
                if self.restTimeRemaining > 0 {
                    self.restTimeRemaining -= 1
                } else {
                    self.stopRestTimer()
                }
            }
        }
    }
    
    func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        isRestTimerActive = false
        restTimeRemaining = 0
    }
    
    func formatElapsedTime() -> String {
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) / 60 % 60
        let seconds = Int(elapsedTime) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    func updateSet(
        set: LocalWorkoutSet,
        reps: Int?,
        weight: Double?,
        durationSeconds: Int?,
        completed: Bool
    ) {
        guard let index = sets.firstIndex(where: { $0.id == set.id }) else { return }
        
        offlineRepository.updateSet(
            set,
            reps: reps,
            weight: weight,
            durationSeconds: durationSeconds,
            completed: completed
        )
        
        // Update local array
        sets[index].reps = reps
        sets[index].weight = weight
        sets[index].durationSeconds = durationSeconds
        sets[index].completed = completed
        
        if completed {
            // Check if this was the last set of current exercise
            let currentRoutineExercise = routineExercises.first
            let setsForCurrentExercise = sets.filter {
                $0.exerciseId == currentRoutineExercise?.exerciseId
            }
            let completedSetsCount = setsForCurrentExercise.filter { $0.completed }.count
            let allSetsCompleted = setsForCurrentExercise.allSatisfy { $0.completed }
            
            if allSetsCompleted {
                moveToNextExercise()
            } else {
                // Send updated set number to Watch
                if let currentRoutineExercise = currentRoutineExercise,
                   let currentExercise = exercises.first(where: { $0.id == currentRoutineExercise.exerciseId }) {
                    WorkoutSyncManager.shared.sendCurrentExercise(
                        exercise: currentExercise,
                        routineExercise: currentRoutineExercise,
                        currentSetNumber: completedSetsCount + 1
                    )
                }
                startRestTimer(seconds: currentRoutineExercise?.restSeconds ?? 60)
            }
        }
    }

    private func moveToNextExercise() {
        if !routineExercises.isEmpty {
            routineExercises.removeFirst()
        }
        sendCurrentExerciseToWatch()
    }
    
    func addSet(exerciseId: UUID, targetSets: Int) async {
        guard let session = currentSession else { return }
        
        let existingSets = sets.filter { $0.exerciseId == exerciseId }
        let nextSetNumber = existingSets.count + 1
        
        let newSet = offlineRepository.createSet(
            session: session,
            exerciseId: exerciseId,
            setNumber: nextSetNumber,
            reps: nil,
            weight: nil
        )
        sets.append(newSet)
    }
    
    func finishWorkout() async {
        guard let session = currentSession, let startTime = startTime else { return }
        
        // Stop timers
        workoutTimer?.invalidate()
        stopRestTimer()
        
        let durationSeconds = Int(Date().timeIntervalSince(startTime))
        
        offlineRepository.completeSession(session, durationSeconds: durationSeconds)
        
        // Sync if online
        if syncService.isOnline {
            await syncService.syncPendingWorkouts()
        }
        
        WorkoutSyncManager.shared.sendWorkoutEnded()
    }
    
    func cancelWorkout() async {
        guard let session = currentSession else { return }
        
        // Stop timers
        workoutTimer?.invalidate()
        stopRestTimer()
        
        offlineRepository.deleteSession(session)
        WorkoutSyncManager.shared.sendWorkoutEnded()
    }
    
    deinit {
        workoutTimer?.invalidate()
        restTimer?.invalidate()
    }
    
    private func sendCurrentExerciseToWatch() {
        guard let currentRoutineExercise = routineExercises.first,
              let currentExercise = exercises.first(where: {
                  $0.id == currentRoutineExercise.exerciseId
              }) else {
            WorkoutSyncManager.shared.sendWorkoutEnded()
            return
        }
        
        WorkoutSyncManager.shared.sendCurrentExercise(
            exercise: currentExercise,
            routineExercise: currentRoutineExercise
        )
    }
}
