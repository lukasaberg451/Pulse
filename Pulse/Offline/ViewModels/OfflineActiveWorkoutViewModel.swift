//
//  OfflineActiveWorkoutViewModel.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-24.
//

import Foundation
import SwiftData
import Combine
import UIKit
import Supabase

@MainActor
class OfflineActiveWorkoutViewModel: ObservableObject {
    @Published var sets: [LocalWorkoutSet] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var elapsedTime: TimeInterval = 0
    @Published var isRestTimerActive = false
    @Published var restTimeRemaining: Int = 0
    
    private var restEndTime: Date?
    @Published var isOfflineMode = false
    
    private let scheduledWorkoutId: UUID?
    private let workoutSessionId: UUID?
    private let exercises: [Exercise]
    
    let routine: Routine
    @Published var routineExercises: [RoutineExercise]
    @Published private(set) var allWorkoutExercises: [RoutineExercise] // All exercises in this workout session
    private let originalRoutineExercises: [RoutineExercise] // Store original list for watch
    
    private var currentSession: LocalWorkoutSession?
    private var startTime: Date?
    private var workoutTimer: Timer?
    private var restTimer: Timer?
    private let offlineRepository: OfflineWorkoutRepository
    private let syncService: WorkoutSyncService
    private let modelContext: ModelContext
    private var resumingSession: LocalWorkoutSession?
    
    init(
        routine: Routine,
        routineExercises: [RoutineExercise],
        scheduledWorkoutId: UUID? = nil,
        workoutSessionId: UUID? = nil,
        exercises: [Exercise],
        modelContext: ModelContext,
        resumingSession: LocalWorkoutSession? = nil
    ) {
        self.routine = routine
        self.routineExercises = routineExercises
        self.allWorkoutExercises = routineExercises
        self.originalRoutineExercises = routineExercises // Store a copy for watch
        self.scheduledWorkoutId = scheduledWorkoutId
        self.workoutSessionId = workoutSessionId
        self.exercises = exercises
        self.offlineRepository = OfflineWorkoutRepository(modelContext: modelContext)
        self.syncService = WorkoutSyncService.shared
        self.modelContext = modelContext
        self.resumingSession = resumingSession
        
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
            
            let durationSeconds = userInfo["durationSeconds"] as? Int
            
            Task { @MainActor in
                await self.handleWatchSetCompleted(
                    exerciseId: exerciseId,
                    setNumber: setNumber,
                    reps: reps,
                    weight: weight,
                    durationSeconds: durationSeconds
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
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if self.isRestTimerActive {
                    self.updateRestTimeRemaining()
                }
            }
        }
    }
    
    private func handleWatchSetCompleted(
        exerciseId: UUID,
        setNumber: Int,
        reps: Int,
        weight: Double,
        durationSeconds: Int? = nil
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
                durationSeconds: durationSeconds,
                completed: true
            )
        }
    }
    
    func startWorkout() async {
        isLoading = true
        
        // Check if we're resuming an interrupted session
        if let session = resumingSession {
            print("📱 Resuming interrupted workout session: \(session.id)")
            currentSession = session
            startTime = session.startedAt
            
            // Load existing sets from SwiftData
            do {
                let loadedSets = try offlineRepository.fetchSets(for: session)
                sets = loadedSets
            } catch {
                print("❌ Failed to load sets for resumed session: \(error)")
            }
            
            // Filter routineExercises to only those that have sets in this session
            // This prevents exercises added to the routine after the workout started from appearing
            let exerciseIdsInSession = Set(sets.map { $0.exerciseId })
            routineExercises = routineExercises.filter { exerciseIdsInSession.contains($0.exerciseId) }
            allWorkoutExercises = routineExercises
            
            // Advance routineExercises past completed exercises
            while let first = routineExercises.first {
                let setsForExercise = sets.filter { $0.exerciseId == first.exerciseId }
                let allCompleted = !setsForExercise.isEmpty && setsForExercise.allSatisfy { $0.completed }
                if allCompleted {
                    routineExercises.removeFirst()
                } else {
                    break
                }
            }
            
            // Clear the resuming flag
            resumingSession = nil
            
            // Start elapsed time timer
            startWorkoutTimer()
            
            // Launch the watch app and send workout data after a delay
            // The watch app needs time to launch and activate its WCSession
            if SubscriptionManager.shared.isProUser {
                WorkoutSyncManager.shared.launchWatchApp(exercises: exercises)
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                WorkoutSyncManager.shared.sendWorkoutToWatch(
                    routine: routine,
                    routineExercises: routineExercises,
                    exercises: exercises,
                    startTime: startTime!
                )
            }
            
            isLoading = false
            return
        }
        
        startTime = Date()
        
        // Start elapsed time timer
        startWorkoutTimer()
        
        // Use existing session if provided (from scheduled workout), otherwise create new one
        let session: LocalWorkoutSession
        if let existingSessionId = workoutSessionId {
            // Use the existing session ID from the scheduled workout
            // The session already exists in Supabase, so we just create a local copy
            // and mark it as already synced (no need to create it again in Supabase)
            print("📱 Using existing workout session: \(existingSessionId)")
            session = LocalWorkoutSession(
                id: existingSessionId,
                routineId: routine.id,
                name: routine.name,
                needsSync: false  // Session already exists in Supabase from scheduling
            )
            modelContext.insert(session)
            try? modelContext.save()
        } else {
            // Create a new session (needs to be synced to Supabase)
            print("📱 Creating new workout session")
            session = offlineRepository.createSession(
                name: routine.name,
                routineId: routine.id
            )
        }
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
        
        // Launch the watch app and send workout data after a delay
        // The watch app needs time to launch and activate its WCSession
        if let startTime = startTime, SubscriptionManager.shared.isProUser {
            WorkoutSyncManager.shared.launchWatchApp(exercises: exercises)
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
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
        restEndTime = Date().addingTimeInterval(Double(seconds))
        restTimeRemaining = seconds
        isRestTimerActive = true
        
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            Task { @MainActor in
                self.updateRestTimeRemaining()
            }
        }
    }
    
    private func updateRestTimeRemaining() {
        guard let restEndTime = restEndTime else {
            stopRestTimer()
            return
        }
        
        let remaining = Int(ceil(restEndTime.timeIntervalSinceNow))
        if remaining > 0 {
            restTimeRemaining = remaining
        } else {
            stopRestTimer()
        }
    }
    
    func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        restEndTime = nil
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
        print("✅ Workout completed locally")
        
        // Sync completed workout to Supabase if online
        if syncService.isOnline {
            print("🔄 Syncing completed workout to Supabase...")
            
            // Wait for any in-progress sync to finish before starting ours
            // (completeSession may have triggered a background sync)
            while syncService.isSyncing {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            await syncService.syncPendingWorkouts()
            
            // Mark scheduled workout as completed if this was a scheduled workout
            if let scheduledWorkoutId = scheduledWorkoutId {
                do {
                    try await WorkoutRepository().completeScheduledWorkout(
                        id: scheduledWorkoutId,
                        sessionId: session.id
                    )
                    print("✅ Marked scheduled workout \(scheduledWorkoutId) as completed")
                } catch {
                    print("❌ Failed to mark scheduled workout as completed: \(error)")
                }
            } else {
                // Non-scheduled workout: create a completed scheduled entry so it appears on the calendar
                // This must happen after sync so the workout_session exists in Supabase
                do {
                    // Fetch user's timezone setting so the date is stored correctly
                    let userTimeZone = await Self.fetchUserTimeZone()
                    try await WorkoutRepository().createCompletedScheduledWorkout(
                        routineId: routine.id,
                        sessionId: session.id,
                        date: Date(),
                        timeZone: userTimeZone
                    )
                    print("✅ Created completed scheduled entry for non-scheduled workout")
                } catch {
                    print("❌ Failed to create scheduled entry: \(error)")
                }
            }
            
            // Post notification to refresh UI
            NotificationCenter.default.post(name: .workoutDataChanged, object: nil)
            print("📢 Posted workoutDataChanged notification")
        } else {
            // If offline, mark scheduled workout locally to be synced later
            if let scheduledWorkoutId = scheduledWorkoutId {
                print("📱 Offline - will mark scheduled workout \(scheduledWorkoutId) as completed when back online")
                // TODO: Add offline scheduled workout completion tracking
            }
            print("📱 Offline - workout will sync when back online")
        }
        
        // Save to HealthKit
        await HealthKitManager.shared.saveWorkout(
            name: routine.name,
            startDate: startTime,
            durationSeconds: durationSeconds,
            exercises: exercises
        )
        
        // Tell the watch the workout has ended so it dismisses
        WorkoutSyncManager.shared.sendWorkoutEnded()
    }
    
    func cancelWorkout() async {
        guard let session = currentSession else { return }
        
        // Stop timers
        workoutTimer?.invalidate()
        stopRestTimer()
        
        // Delete the session - no need to sync cancelled workouts
        offlineRepository.deleteSession(session)
        print("🗑️ Cancelled workout - deleted local session without syncing")
        
        WorkoutSyncManager.shared.sendWorkoutEnded()
    }
    
    private static func fetchUserTimeZone() async -> TimeZone {
        let supabase = SupabaseManager.shared.client
        guard let userId = supabase.auth.currentUser?.id else { return .current }
        
        do {
            let profile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            return profile.resolvedTimeZone
        } catch {
            return .current
        }
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
            // No more exercises - send completion signal to watch
            // We'll send the last exercise data but with currentSet > totalSets
            print("📱 All exercises completed - sending completion signal to watch")
            
            // Get the last exercise from the original list
            if let lastRoutineExercise = originalRoutineExercises.last,
               let lastExercise = exercises.first(where: { $0.id == lastRoutineExercise.exerciseId }) {
                // Send with currentSet = totalSets + 1 to trigger completion view
                WorkoutSyncManager.shared.sendCurrentExercise(
                    exercise: lastExercise,
                    routineExercise: lastRoutineExercise,
                    currentSetNumber: lastRoutineExercise.sets + 1
                )
            }
            return
        }
        
        WorkoutSyncManager.shared.sendCurrentExercise(
            exercise: currentExercise,
            routineExercise: currentRoutineExercise
        )
    }
}
