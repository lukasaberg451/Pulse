//
//  ActiveWorkoutViewModel.swift
//  Pulse
//
//  Created by lukasaberg on 2/8/26.
//

import Foundation
import Combine

@MainActor
class ActiveWorkoutViewModel: ObservableObject {
    @Published var sets: [WorkoutSet] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var elapsedTime: TimeInterval = 0
    @Published var isRestTimerActive = false
    @Published var restTimeRemaining: Int = 0
    
    let routine: Routine
    let routineExercises: [RoutineExercise]
    
    private var sessionId: UUID?
    private var startTime: Date?
    private var workoutTimer: Timer?
    private var restTimer: Timer?
    private let repository = WorkoutRepository()
    
    init(routine: Routine, routineExercises: [RoutineExercise]) {
        self.routine = routine
        self.routineExercises = routineExercises
    }
    
    func startWorkout() async {
        isLoading = true
        startTime = Date()
        
        // Start elapsed time timer
        startWorkoutTimer()
        
        do {
            // Create the workout session
            let session = try await repository.createSession(
                name: routine.name,
                routineId: routine.id
            )
            sessionId = session.id
            
            // Create placeholder sets for each exercise
            for routineExercise in routineExercises {
                for setNumber in 1...routineExercise.sets {
                    let set = try await repository.createSet(
                        sessionId: session.id,
                        exerciseId: routineExercise.exerciseId,
                        setNumber: setNumber,
                        reps: nil,
                        weight: nil
                    )
                    sets.append(set)
                }
            }
        } catch {
            errorMessage = "Failed to start workout: \(error.localizedDescription)"
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
    
    func updateSet(id: UUID, reps: Int?, weight: Double?, durationSeconds: Int?, completed: Bool) async {
        do {
            try await repository.updateSet(
                id: id,
                reps: reps,
                weight: weight,
                durationSeconds: durationSeconds,
                completed: completed
            )
            
            // Update local state
            if let index = sets.firstIndex(where: { $0.id == id }) {
                sets[index] = WorkoutSet(
                    id: sets[index].id,
                    sessionId: sets[index].sessionId,
                    exerciseId: sets[index].exerciseId,
                    setNumber: sets[index].setNumber,
                    reps: reps,
                    weight: weight,
                    durationSeconds: durationSeconds,
                    completed: completed,
                    notes: sets[index].notes,
                    createdAt: sets[index].createdAt
                )
                
                // Start rest timer if set was completed
                if completed, let routineExercise = routineExercises.first(where: { $0.exerciseId == sets[index].exerciseId }) {
                    startRestTimer(seconds: routineExercise.restSeconds)
                }
            }
        } catch {
            errorMessage = "Failed to update set: \(error.localizedDescription)"
        }
    }
    
    func addSet(exerciseId: UUID, targetSets: Int) async {
        guard let sessionId = sessionId else { return }
        
        let existingSets = sets.filter { $0.exerciseId == exerciseId }
        let nextSetNumber = existingSets.count + 1
        
        do {
            let newSet = try await repository.createSet(
                sessionId: sessionId,
                exerciseId: exerciseId,
                setNumber: nextSetNumber,
                reps: nil,
                weight: nil
            )
            sets.append(newSet)
        } catch {
            errorMessage = "Failed to add set: \(error.localizedDescription)"
        }
    }
    
    func finishWorkout() async {
        guard let sessionId = sessionId, let startTime = startTime else { return }
        
        // Stop timers
        workoutTimer?.invalidate()
        stopRestTimer()
        
        let durationSeconds = Int(Date().timeIntervalSince(startTime))
        
        do {
            try await repository.completeSession(
                id: sessionId,
                durationSeconds: durationSeconds
            )
        } catch {
            errorMessage = "Failed to finish workout: \(error.localizedDescription)"
        }
    }
    
    func cancelWorkout() async {
        guard let sessionId = sessionId else { return }
        
        // Stop timers
        workoutTimer?.invalidate()
        stopRestTimer()
        
        // Delete the session and all its sets
        do {
            try await repository.deleteSession(id: sessionId)
        } catch {
            errorMessage = "Failed to cancel workout: \(error.localizedDescription)"
        }
    }
    
    deinit {
        workoutTimer?.invalidate()
        restTimer?.invalidate()
    }
}
