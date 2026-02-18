//
//  ActiveWorkoutViewModel.swift
//  Pulse
//
//  Created by lukasaberg on 2/8/26.
//

import Foundation
import Combine
import Supabase

@MainActor
class ActiveWorkoutViewModel: ObservableObject {
    @Published var sets: [WorkoutSet] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var elapsedTime: TimeInterval = 0
    @Published var isRestTimerActive = false
    @Published var restTimeRemaining: Int = 0
    
    private let scheduledWorkoutId: UUID?
    private let exercises: [Exercise]
    
    let routine: Routine
    var routineExercises: [RoutineExercise]
    
    private var sessionId: UUID?
    private var startTime: Date?
    private var workoutTimer: Timer?
    private var restTimer: Timer?
    private let repository = WorkoutRepository()
    
    init(routine: Routine, routineExercises: [RoutineExercise], scheduledWorkoutId: UUID? = nil, exercises: [Exercise]) {
            self.routine = routine
            self.routineExercises = routineExercises
            self.scheduledWorkoutId = scheduledWorkoutId
            self.exercises = exercises
            

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
                    await self.handleWatchSetCompleted(exerciseId: exerciseId, setNumber: setNumber, reps: reps, weight: weight)
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
    
    private func handleWatchSetCompleted(exerciseId: UUID, setNumber: Int, reps: Int, weight: Double) async {
        // Find the current exercise and set
        guard let currentRoutineExercise = routineExercises.first,
              currentRoutineExercise.exerciseId == exerciseId else {
            print("📱 Exercise mismatch from Watch")
            return
        }
        
        // Find the set to complete - match by exerciseId and setNumber
        if let setIndex = sets.firstIndex(where: {
            $0.exerciseId == exerciseId &&  // Changed to exerciseId
            $0.setNumber == setNumber &&
            !$0.completed
        }) {
            let set = sets[setIndex]
            
            // Update the set with Watch data
            await updateSet(
                id: set.id,
                reps: reps,
                weight: weight,
                durationSeconds: nil,
                completed: true
            )
            
            print("📱 Set logged from Watch: \(reps) reps @ \(weight)kg")
        }
    }
    
    func startWorkout() async {
        print("📱 Starting workout...")
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
            WorkoutSyncManager.shared.sendWorkoutToWatch(
                    routine: routine,
                    routineExercises: routineExercises,
                    exercises: exercises
                    )
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
        guard let index = sets.firstIndex(where: { $0.id == id }) else { return }
        
        let updatedSet = WorkoutSet(
            id: sets[index].id,  // Changed to 'sets'
            sessionId: sets[index].sessionId,
            exerciseId: sets[index].exerciseId,
            setNumber: sets[index].setNumber,
            reps: reps,
            weight: weight,
            durationSeconds: durationSeconds,
            completed: completed,
            createdAt: sets[index].createdAt
        )
        
        sets[index] = updatedSet  // Changed to 'sets'
        
        do {
            try await repository.updateSet(
                id: id,
                reps: reps,
                weight: weight,
                durationSeconds: durationSeconds,
                completed: completed
            )
            
            if completed {
                // Check if this was the last set of current exercise
                let currentRoutineExercise = routineExercises.first
                let setsForCurrentExercise = sets.filter { $0.exerciseId == currentRoutineExercise?.exerciseId }  // Changed to exerciseId
                let allSetsCompleted = setsForCurrentExercise.allSatisfy { $0.completed }
                
                if allSetsCompleted {
                    // Move to next exercise
                    moveToNextExercise()
                } else {
                    // Start rest timer
                    startRestTimer(seconds: currentRoutineExercise?.restSeconds ?? 60)
                }
            }
        } catch {
            errorMessage = "Failed to update set: \(error.localizedDescription)"
        }
    }

    private func moveToNextExercise() {
        // Remove first exercise (completed)
        if !routineExercises.isEmpty {
            routineExercises.removeFirst()
        }
        
        // Send new current exercise to Watch
        sendCurrentExerciseToWatch()
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
            
            if let scheduledWorkoutId = scheduledWorkoutId {
                try await markScheduledWorkoutComplete(id: scheduledWorkoutId)
            }
            
        } catch {
            errorMessage = "Failed to finish workout: \(error.localizedDescription)"
        }
    }
    
    private func markScheduledWorkoutComplete(id: UUID) async throws {
        let supabase = SupabaseManager.shared.client
        
        struct UpdateCompleted: Encodable {
            let completed: Bool
        }
        
        try await supabase
            .from("scheduled_workouts")
            .update(UpdateCompleted(completed: true))
            .eq("id", value: id.uuidString)
            .execute()
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
    
    private func sendCurrentExerciseToWatch() {
        guard let currentRoutineExercise = routineExercises.first,
              let currentExercise = exercises.first(where: { $0.id == currentRoutineExercise.exerciseId }) else {
            return
        }
        
        WorkoutSyncManager.shared.sendCurrentExercise(
            exercise: currentExercise,
            routineExercise: currentRoutineExercise
        )
    }
}
