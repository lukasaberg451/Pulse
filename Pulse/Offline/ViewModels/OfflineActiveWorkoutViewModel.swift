//
//  OfflineActiveWorkoutViewModel.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-24.
//

import SwiftUI
import SwiftData
import Combine
import Supabase

@MainActor
class OfflineActiveWorkoutViewModel: ObservableObject {
    @Published var sets: [LocalWorkoutSet] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var elapsedTime: TimeInterval = 0
    @Published var isRestTimerActive = false
    @Published var restTimeRemaining: Int = 0
    @Published var isFinishing = false
    
    private var restEndTime: Date?
    @Published var isOfflineMode = false
    
    private let scheduledWorkoutId: UUID?
    private let workoutSessionId: UUID?
    private let exercises: [Exercise]
    
    let routine: Routine
    @Published var routineExercises: [RoutineExercise]
    @Published private(set) var allWorkoutExercises: [RoutineExercise] // All exercises in this workout session
    @Published var strength1RMHighlights: [Strength1RMHighlight] = []
    private let originalRoutineExercises: [RoutineExercise] // Store original list for watch
    
    private var currentSession: LocalWorkoutSession?
    private var startTime: Date?
    private var workoutTimer: Timer?
    private var restTimer: Timer?
    private var persistenceTimer: Timer?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private let offlineRepository: OfflineWorkoutRepository
    private let syncService: WorkoutSyncService
    private let modelContext: ModelContext
    private var resumingSession: LocalWorkoutSession?
    
    /// UserDefaults keys for fallback persistence of critical workout state
    private static let startTimeKey = "activeWorkout_startTime"
    private static let sessionIdKey = "activeWorkout_sessionId"
    
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
                self.endBackgroundSave()
            }
        }
        
        // Save elapsed time when the app goes to the background so we can
        // restore it accurately if the user kills the app mid-workout.
        // Also request a background task to ensure the save completes.
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.beginBackgroundSave()
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
        
        let currentOrderIndex = currentRoutineExercise.orderIndex
        if let setIndex = sets.firstIndex(where: {
            $0.exerciseId == exerciseId &&
            $0.orderIndex == currentOrderIndex &&
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
            debugLog("📱 Resuming interrupted workout session: \(session.id)")
            currentSession = session
            
            // Load existing sets from SwiftData
            do {
                let loadedSets = try offlineRepository.fetchSets(for: session)
                sets = loadedSets
            } catch {
                debugLog("❌ Failed to load sets for resumed session: \(error)")
            }
            
            // Restore the elapsed time from before the app was killed.
            // First try durationSeconds (saved periodically and on background).
            // Fall back to the original start time saved in UserDefaults,
            // which gives us the real wall-clock time the workout was started.
            if let savedDuration = session.durationSeconds, savedDuration > 0 {
                startTime = Date().addingTimeInterval(-TimeInterval(savedDuration))
            } else {
                // Fallback: use persisted start time from UserDefaults
                let savedStartTimestamp = UserDefaults.standard.double(forKey: Self.startTimeKey)
                if savedStartTimestamp > 0 {
                    startTime = Date(timeIntervalSince1970: savedStartTimestamp)
                } else {
                    // Last resort: use the session's startedAt
                    startTime = session.startedAt
                }
            }
            
            // Filter routineExercises to only those that have sets in this session
            // This prevents exercises added to the routine after the workout started from appearing
            let exerciseIdsInSession = Set(sets.map { $0.exerciseId })
            routineExercises = routineExercises.filter { exerciseIdsInSession.contains($0.exerciseId) }
            allWorkoutExercises = routineExercises
            
            // Advance routineExercises past completed exercises
            while let first = routineExercises.first {
                let setsForExercise = sets.filter { $0.exerciseId == first.exerciseId && $0.orderIndex == first.orderIndex }
                let allCompleted = !setsForExercise.isEmpty && setsForExercise.allSatisfy { $0.completed }
                if allCompleted {
                    routineExercises.removeFirst()
                } else {
                    break
                }
            }
            
            // Clear the resuming flag
            resumingSession = nil
            
            // Save the restored start time to UserDefaults for future crash protection
            if let startTime = startTime {
                UserDefaults.standard.set(startTime.timeIntervalSince1970, forKey: Self.startTimeKey)
            }
            UserDefaults.standard.set(session.id.uuidString, forKey: Self.sessionIdKey)
            
            // Start elapsed time timer
            startWorkoutTimer()
            
            // Start Live Activity for resumed workout
            startWorkoutLiveActivity()
            
            isLoading = false
            
            // Start HKWorkoutSession for background execution (fire-and-forget, non-blocking).
            HealthKitManager.shared.startWorkoutSession(exercises: exercises)
            
            // Launch the watch app and send workout data after a delay (non-blocking)
            if SubscriptionManager.shared.isProUser {
                let routineForWatch = routine
                let exercisesForWatch = routineExercises
                let allExercises = exercises
                let watchStartTime = startTime!
                Task.detached {
                    await WorkoutSyncManager.shared.launchWatchApp(exercises: allExercises)
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await WorkoutSyncManager.shared.sendWorkoutToWatch(
                        routine: routineForWatch,
                        routineExercises: exercisesForWatch,
                        exercises: allExercises,
                        startTime: watchStartTime
                    )
                }
            }
            
            return
        }
        
        startTime = Date()
        
        // Start elapsed time timer
        startWorkoutTimer()
        
        // Save start time immediately as fallback
        UserDefaults.standard.set(startTime!.timeIntervalSince1970, forKey: Self.startTimeKey)
        
        // Use existing session if provided (from scheduled workout), otherwise create new one
        let session: LocalWorkoutSession
        if let existingSessionId = workoutSessionId {
            // Use the existing session ID from the scheduled workout
            // The session already exists in Supabase, so we just create a local copy
            // and mark it as already synced (no need to create it again in Supabase)
            debugLog("📱 Using existing workout session: \(existingSessionId)")
            session = LocalWorkoutSession(
                id: existingSessionId,
                routineId: routine.id,
                scheduledWorkoutId: scheduledWorkoutId,
                name: routine.name,
                needsSync: false  // Session already exists in Supabase from scheduling
            )
            modelContext.insert(session)
            try? modelContext.save()
        } else {
            // Create a new session (needs to be synced to Supabase)
            debugLog("📱 Creating new workout session")
            session = offlineRepository.createSession(
                name: routine.name,
                routineId: routine.id
            )
        }
        currentSession = session
        UserDefaults.standard.set(session.id.uuidString, forKey: Self.sessionIdKey)
        
        // Create placeholder sets for each exercise
        for routineExercise in routineExercises {
            for setNumber in 1...routineExercise.sets {
                let set = offlineRepository.createSet(
                    session: session,
                    exerciseId: routineExercise.exerciseId,
                    setNumber: setNumber,
                    reps: nil,
                    weight: nil,
                    orderIndex: routineExercise.orderIndex
                )
                sets.append(set)
            }
        }
        
        // Start Live Activity for new workout
        startWorkoutLiveActivity()
        
        isLoading = false
        
        // Start HKWorkoutSession for background execution (fire-and-forget, non-blocking).
        HealthKitManager.shared.startWorkoutSession(exercises: exercises)
        
        // Launch the watch app and send workout data after a delay (non-blocking)
        // The watch app needs time to launch and activate its WCSession
        // Use Task.detached to avoid inheriting @MainActor and blocking the UI
        if let startTime = startTime, SubscriptionManager.shared.isProUser {
            let routineForWatch = routine
            let exercisesForWatch = routineExercises
            let allExercises = exercises
            Task.detached {
                await WorkoutSyncManager.shared.launchWatchApp(exercises: allExercises)
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                await WorkoutSyncManager.shared.sendWorkoutToWatch(
                    routine: routineForWatch,
                    routineExercises: exercisesForWatch,
                    exercises: allExercises,
                    startTime: startTime
                )
            }
        }
    }
    
    private func startWorkoutTimer() {
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                guard let startTime = self.startTime else { return }
                self.elapsedTime = Date().timeIntervalSince(startTime)
            }
        }
        
        // Also start periodic persistence so elapsed time is saved
        // even if the app is killed without the background notification
        startPersistenceTimer()
    }
    
    /// Persist the current elapsed time to the session so it can be
    /// restored accurately if the app is killed mid-workout.
    private func saveElapsedTime() {
        guard let session = currentSession, let startTime = startTime else { return }
        let elapsed = Int(Date().timeIntervalSince(startTime))
        session.durationSeconds = elapsed
        try? modelContext.save()
        
        // Also save start time to UserDefaults as a fallback
        UserDefaults.standard.set(startTime.timeIntervalSince1970, forKey: Self.startTimeKey)
        UserDefaults.standard.set(session.id.uuidString, forKey: Self.sessionIdKey)
    }
    
    /// Start periodic persistence of elapsed time every 30 seconds.
    /// This ensures elapsed time is saved even if the app is killed
    /// without going through the normal background notification.
    private func startPersistenceTimer() {
        persistenceTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.saveElapsedTime()
            }
        }
    }
    
    /// Request a background task so iOS gives us extra time to save state.
    private func beginBackgroundSave() {
        saveElapsedTime()
        
        guard backgroundTaskID == .invalid else { return }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "WorkoutStateSave") { [weak self] in
            // Expiration handler — save one more time and end the task
            guard let self = self else { return }
            Task { @MainActor in
                self.saveElapsedTime()
                self.endBackgroundSave()
            }
        }
    }
    
    /// End the background task if one is active.
    private func endBackgroundSave() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
    
    /// Clear the UserDefaults fallback keys when a workout completes or is cancelled.
    private func clearPersistedState() {
        UserDefaults.standard.removeObject(forKey: Self.startTimeKey)
        UserDefaults.standard.removeObject(forKey: Self.sessionIdKey)
        persistenceTimer?.invalidate()
        persistenceTimer = nil
    }
    
    // MARK: - Live Activity
    
    private func startWorkoutLiveActivity() {
        guard let firstRoutineExercise = allWorkoutExercises.first,
              let firstExercise = exercises.first(where: { $0.id == firstRoutineExercise.exerciseId }) else {
            return
        }
        WorkoutLiveActivityManager.shared.startLiveActivity(
            routineName: routine.name,
            startTime: startTime ?? Date(),
            firstExerciseName: firstExercise.name,
            totalExercises: allWorkoutExercises.count,
            totalSetsForFirstExercise: firstRoutineExercise.sets
        )
    }
    
    private func updateWorkoutLiveActivity() {
        let completedCount = allWorkoutExercises.count - routineExercises.count
        let currentRoutineExercise = routineExercises.first
        let currentExercise = currentRoutineExercise.flatMap { re in exercises.first(where: { $0.id == re.exerciseId }) }
        
        let setsForCurrent = currentRoutineExercise.map { re in
            sets.filter { $0.exerciseId == re.exerciseId && $0.orderIndex == re.orderIndex }
        } ?? []
        let completedSets = setsForCurrent.filter { $0.completed }.count
        
        WorkoutLiveActivityManager.shared.updateLiveActivity(
            currentExerciseName: currentExercise?.name ?? "Workout",
            currentSetNumber: completedSets + 1,
            totalSets: setsForCurrent.count,
            completedExercises: completedCount,
            totalExercises: allWorkoutExercises.count,
            elapsedSeconds: Int(elapsedTime)
        )
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
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            isRestTimerActive = false
        }
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
            // Save elapsed time on each set completion as an additional persistence point
            saveElapsedTime()
            
            // Check if this was the last set of current exercise
            let currentRoutineExercise = routineExercises.first
            let setsForCurrentExercise = sets.filter {
                $0.exerciseId == currentRoutineExercise?.exerciseId && $0.orderIndex == currentRoutineExercise?.orderIndex
            }
            let completedSetsCount = setsForCurrentExercise.filter { $0.completed }.count
            let allSetsCompleted = setsForCurrentExercise.allSatisfy { $0.completed }
            
            if allSetsCompleted {
                moveToNextExercise()
            } else {
                // Send updated set number to Watch (use actual set count in case sets were added)
                if let currentRoutineExercise = currentRoutineExercise,
                   let currentExercise = exercises.first(where: { $0.id == currentRoutineExercise.exerciseId }) {
                    WorkoutSyncManager.shared.sendCurrentExercise(
                        exercise: currentExercise,
                        routineExercise: currentRoutineExercise,
                        currentSetNumber: completedSetsCount + 1,
                        totalSets: setsForCurrentExercise.count
                    )
                }
                startRestTimer(seconds: currentRoutineExercise?.restSeconds ?? 60)
            }
            
            // Update Live Activity with current progress
            updateWorkoutLiveActivity()
        } else {
            // Undo path — a previously completed set was uncompleted
            
            // Stop the rest timer since the user is going back
            stopRestTimer()
            
            // Find the routine exercise that owns this set
            let undoneExerciseId = set.exerciseId
            let undoneOrderIndex = set.orderIndex
            
            if let routineExercise = allWorkoutExercises.first(where: {
                $0.exerciseId == undoneExerciseId && $0.orderIndex == undoneOrderIndex
            }) {
                // If the exercise was already completed and removed from
                // routineExercises, re-insert it at the front so the watch
                // and Live Activity reflect the correct current exercise.
                let isStillInQueue = routineExercises.contains(where: {
                    $0.exerciseId == undoneExerciseId && $0.orderIndex == undoneOrderIndex
                })
                if !isStillInQueue {
                    routineExercises.insert(routineExercise, at: 0)
                }
                
                // Send corrected state to the watch
                let setsForExercise = sets.filter {
                    $0.exerciseId == undoneExerciseId && $0.orderIndex == undoneOrderIndex
                }
                let completedSetsCount = setsForExercise.filter { $0.completed }.count
                
                if let exercise = exercises.first(where: { $0.id == undoneExerciseId }) {
                    WorkoutSyncManager.shared.sendCurrentExercise(
                        exercise: exercise,
                        routineExercise: routineExercise,
                        currentSetNumber: completedSetsCount + 1,
                        totalSets: setsForExercise.count,
                        restStopped: true
                    )
                }
            }
            
            // Update Live Activity with corrected progress
            updateWorkoutLiveActivity()
        }
    }

    private func moveToNextExercise() {
        if !routineExercises.isEmpty {
            routineExercises.removeFirst()
        }
        sendCurrentExerciseToWatch()
    }
    
    func addSet(exerciseId: UUID, targetSets: Int, orderIndex: Int? = nil) async {
        guard let session = currentSession else { return }
        
        let existingSets = sets.filter { $0.exerciseId == exerciseId && $0.orderIndex == orderIndex }
        let nextSetNumber = existingSets.count + 1
        
        let newSet = offlineRepository.createSet(
            session: session,
            exerciseId: exerciseId,
            setNumber: nextSetNumber,
            reps: nil,
            weight: nil,
            orderIndex: orderIndex
        )
        sets.append(newSet)
        
        // Notify watch of the updated set count so it doesn't prematurely show "workout complete"
        if let routineExercise = routineExercises.first(where: { $0.exerciseId == exerciseId && $0.orderIndex == orderIndex }),
           let exercise = exercises.first(where: { $0.id == exerciseId }) {
            let completedCount = existingSets.filter { $0.completed }.count
            WorkoutSyncManager.shared.sendCurrentExercise(
                exercise: exercise,
                routineExercise: routineExercise,
                currentSetNumber: completedCount + 1,
                totalSets: nextSetNumber
            )
        }
    }
    
    func finishWorkout() async {
        guard let session = currentSession, let startTime = startTime else { return }
        
        isFinishing = true
        
        // Stop timers
        workoutTimer?.invalidate()
        stopRestTimer()
        clearPersistedState()
        
        let durationSeconds = Int(Date().timeIntervalSince(startTime))
        
        offlineRepository.completeSession(session, durationSeconds: durationSeconds)
        debugLog("✅ Workout completed locally")
        
        // End the Live Activity
        WorkoutLiveActivityManager.shared.endLiveActivity(completed: true)
        
        // Run sync, scheduled entry, 1RM updates, and HealthKit save concurrently
        // since they are independent operations.
        
        // HealthKit save (independent of network operations)
        let healthKitTask = Task {
            if HealthKitManager.shared.isWorkoutSessionActive {
                await HealthKitManager.shared.endWorkoutSession(name: routine.name)
            } else {
                await HealthKitManager.shared.saveWorkout(
                    name: routine.name,
                    startDate: startTime,
                    durationSeconds: durationSeconds,
                    exercises: exercises
                )
            }
        }
        
        if syncService.isOnline {
            debugLog("🔄 Syncing completed workout to Supabase...")
            
            // Wait for any in-progress sync to finish before starting ours
            // (completeSession may have triggered a background sync)
            while syncService.isSyncing {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            await syncService.syncPendingWorkouts()
            
            // Start 1RM updates concurrently (the main bottleneck)
            async let onermResult: Void = updateEstimated1RMForCompletedSets()
            
            // Mark scheduled workout as completed (1-2 calls, runs while 1RM updates are in flight)
            if !session.scheduledEntryCreated {
                if let scheduledWorkoutId = scheduledWorkoutId {
                    do {
                        try await WorkoutRepository().completeScheduledWorkout(
                            id: scheduledWorkoutId,
                            sessionId: session.id
                        )
                        session.scheduledEntryCreated = true
                        try? modelContext.save()
                        debugLog("✅ Marked scheduled workout \(scheduledWorkoutId) as completed")
                    } catch {
                        debugLog("❌ Failed to mark scheduled workout as completed: \(error)")
                    }
                } else {
                    do {
                        let userTimeZone = await Self.fetchUserTimeZone()
                        try await WorkoutRepository().createCompletedScheduledWorkout(
                            routineId: routine.id,
                            sessionId: session.id,
                            date: Date(),
                            timeZone: userTimeZone
                        )
                        session.scheduledEntryCreated = true
                        try? modelContext.save()
                        debugLog("✅ Created completed scheduled entry for non-scheduled workout")
                    } catch {
                        debugLog("❌ Failed to create scheduled entry: \(error)")
                    }
                }
            }
            
            // Await 1RM updates to finish
            await onermResult
            
            // Post notification to refresh UI
            NotificationCenter.default.post(name: .workoutDataChanged, object: nil)
            debugLog("📢 Posted workoutDataChanged notification")
        } else {
            if let scheduledWorkoutId = scheduledWorkoutId {
                debugLog("📱 Offline - will mark scheduled workout \(scheduledWorkoutId) as completed when back online")
            }
            debugLog("📱 Offline - workout will sync when back online")
        }
        
        // Ensure HealthKit save completes before returning
        await healthKitTask.value
        
        // Tell the watch the workout has ended so it dismisses
        WorkoutSyncManager.shared.sendWorkoutEnded()
    }
    
    func cancelWorkout() async {
        guard let session = currentSession else { return }
        
        // Stop timers
        workoutTimer?.invalidate()
        stopRestTimer()
        clearPersistedState()
        
        // Delete the session - no need to sync cancelled workouts
        offlineRepository.deleteSession(session)
        debugLog("🗑️ Cancelled workout - deleted local session without syncing")
        
        // Cancel the HKWorkoutSession without saving to HealthKit
        HealthKitManager.shared.cancelWorkoutSession()
        
        WorkoutLiveActivityManager.shared.endLiveActivity(completed: false)
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
    
    /// Calls the server-side RPC to update estimated 1RM for each eligible
    /// completed strength set in this workout.
    private func updateEstimated1RMForCompletedSets() async {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id else { return }
        
        let completedSets = sets.filter { $0.completed }
        
        // Filter to eligible strength sets upfront
        let eligibleSets = completedSets.filter { set in
            guard let weight = set.weight, weight > 0,
                  let reps = set.reps, reps >= 1, reps <= 10 else { return false }
            let exercise = exercises.first { $0.id == set.exerciseId }
            return exercise?.exerciseType != "cardio"
        }
        
        guard !eligibleSets.isEmpty else { return }
        
        // Prepare all data upfront so the task group closures only capture Sendable values
        struct SetInput: Sendable {
            let exerciseId: UUID
            let name: String
            let weight: Double
            let reps: Int
        }
        
        let inputs: [SetInput] = eligibleSets.map { set in
            let exercise = exercises.first { $0.id == set.exerciseId }
            return SetInput(
                exerciseId: set.exerciseId,
                name: exercise?.name ?? "Unknown",
                weight: set.weight!,
                reps: set.reps!
            )
        }
        
        let supabaseClient = SupabaseManager.shared.client
        
        // Run all 1RM update calls concurrently
        let results: [(exerciseId: UUID, name: String, response: Update1RMResponse)] = await withTaskGroup(
            of: (UUID, String, Update1RMResponse)?.self
        ) { group in
            for input in inputs {
                group.addTask {
                    do {
                        let data = try await supabaseClient
                            .rpc("update_exercise_1rm", params: [
                                "p_user_id": userId.uuidString,
                                "p_exercise_id": input.exerciseId.uuidString,
                                "p_weight": String(input.weight),
                                "p_reps": String(input.reps)
                            ])
                            .execute()
                            .data
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase
                        let response = try decoder.decode(Update1RMResponse.self, from: data)
                        if response.isNewPr {
                            debugLog("🏆 New 1RM PR for exercise \(input.name): \(response.estimated1rm ?? 0)")
                        }
                        return (input.exerciseId, input.name, response)
                    } catch {
                        debugLog("Failed to update 1RM for exercise \(input.exerciseId): \(error)")
                        return nil
                    }
                }
            }
            
            var collected: [(UUID, String, Update1RMResponse)] = []
            for await result in group {
                if let result { collected.append(result) }
            }
            return collected
        }
        
        // Track the best response per exercise (a set with higher estimated 1RM wins)
        var bestPerExercise: [UUID: (name: String, response: Update1RMResponse)] = [:]
        for (exerciseId, name, response) in results {
            if let existing = bestPerExercise[exerciseId] {
                if (response.estimated1rm ?? 0) > (existing.response.estimated1rm ?? 0) {
                    bestPerExercise[exerciseId] = (name, response)
                }
            } else {
                bestPerExercise[exerciseId] = (name, response)
            }
        }
        
        // Build highlights from best responses (only include exercises that had a valid estimated 1RM)
        let highlights = bestPerExercise.compactMap { exerciseId, entry -> Strength1RMHighlight? in
            guard let estimated1rm = entry.response.estimated1rm else { return nil }
            return Strength1RMHighlight(
                id: exerciseId,
                exerciseName: entry.name,
                estimated1rm: estimated1rm,
                isNewPr: entry.response.isNewPr,
                previousBest: entry.response.previousBest ?? 0
            )
        }.sorted { $0.estimated1rm > $1.estimated1rm }
        
        await MainActor.run {
            self.strength1RMHighlights = highlights
        }
    }
    
    deinit {
        workoutTimer?.invalidate()
        restTimer?.invalidate()
        persistenceTimer?.invalidate()
    }
    
    private func sendCurrentExerciseToWatch() {
        guard let currentRoutineExercise = routineExercises.first,
              let currentExercise = exercises.first(where: {
                  $0.id == currentRoutineExercise.exerciseId
              }) else {
            // No more exercises - send completion signal to watch
            // We'll send the last exercise data but with currentSet > totalSets
            debugLog("📱 All exercises completed - sending completion signal to watch")
            
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
