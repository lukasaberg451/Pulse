//
//  HealthKitManager.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-03-03.
//

import SwiftUI
import Combine
import HealthKit

@MainActor
class HealthKitManager: NSObject, ObservableObject {
    static let shared = HealthKitManager()
    
    @Published var isAuthorized = false
    @Published var showDeniedAlert = false
    @AppStorage("healthKitSyncEnabled") var isSyncEnabled = false
    
    let healthStore = HKHealthStore()
    
    // Active workout session that keeps the app alive in the background
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    
    /// Tracks whether the last attempt to start a workout session succeeded.
    /// When false, the app has no background execution protection and should
    /// persist state more aggressively.
    @Published var hasActiveBackgroundProtection = false
    
    private override init() {}
    
    // MARK: - Authorization
    
    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    func requestAuthorization() async {
        guard isAvailable else { return }
        
        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType()
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: [])
            
            let status = healthStore.authorizationStatus(for: HKObjectType.workoutType())
            if status == .sharingDenied {
                isAuthorized = false
                isSyncEnabled = false
                showDeniedAlert = true
            } else {
                isAuthorized = true
                isSyncEnabled = true
            }
        } catch {
            debugLog("❌ HealthKit authorization error: \(error.localizedDescription)")
            isAuthorized = false
            isSyncEnabled = false
        }
    }
    
    /// Ensures HealthKit is authorized for workout sessions.
    /// Unlike requestAuthorization(), this does not show a denied alert or
    /// change the sync toggle — it only ensures we have the minimum permission
    /// needed for background execution.
    func ensureAuthorizedForBackgroundExecution() async -> Bool {
        guard isAvailable else { return false }
        
        let status = healthStore.authorizationStatus(for: HKObjectType.workoutType())
        if status == .sharingAuthorized {
            return true
        }
        
        // If not yet determined, do NOT request authorization here.
        // The authorization dialog can appear behind a fullScreenCover
        // and hang the main thread indefinitely. Authorization should be
        // requested explicitly from the settings/onboarding UI instead.
        debugLog("📱 HealthKit not authorized (status: \(status.rawValue)) — skipping workout session")
        return false
    }
    
    // MARK: - Live Workout Session (Background Execution)
    
    /// Fire-and-forget: starts an HKWorkoutSession for background execution.
    /// Everything runs off the main actor so this never blocks the UI.
    func startWorkoutSession(exercises: [Exercise]) {
        // Capture everything we need before going off main actor
        let available = isAvailable
        let store = healthStore
        let existingSession = workoutSession
        let existingBuilder = workoutBuilder
        let activityType = resolveActivityType(from: exercises)
        
        // Clear references immediately so we don't hold stale state
        if existingSession != nil {
            workoutSession = nil
            workoutBuilder = nil
        }
        
        // Run EVERYTHING in a detached task — including auth checks.
        // This guarantees zero blocking on the main actor.
        Task.detached { [weak self] in
            guard available else {
                debugLog("📱 HealthKit not available on this device — no background execution protection")
                if let self { await MainActor.run { self.hasActiveBackgroundProtection = false } }
                return
            }
            
            let status = store.authorizationStatus(for: HKObjectType.workoutType())
            guard status == .sharingAuthorized else {
                debugLog("📱 HealthKit not authorized (status: \(status.rawValue)) — no background execution protection")
                if let self { await MainActor.run { self.hasActiveBackgroundProtection = false } }
                return
            }
            
            // End any existing session
            if let existingSession {
                existingSession.end()
                existingBuilder?.discardWorkout()
                debugLog("📱 Ended previous HKWorkoutSession before starting new one")
            }
            
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = activityType
            configuration.locationType = .indoor
            
            do {
                let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
                let builder = session.associatedWorkoutBuilder()
                builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
                
                session.startActivity(with: Date())
                try await builder.beginCollection(at: Date())
                
                if let self {
                    await MainActor.run {
                        session.delegate = self
                        self.workoutSession = session
                        self.workoutBuilder = builder
                        self.hasActiveBackgroundProtection = true
                        debugLog("📱 ✅ Started HKWorkoutSession for background execution")
                    }
                }
            } catch {
                debugLog("📱 ❌ Failed to start HKWorkoutSession: \(error.localizedDescription)")
                if let self { await MainActor.run { self.hasActiveBackgroundProtection = false } }
            }
        }
    }
    
    /// Ends the active workout session. Saves the workout to HealthKit only if
    /// the user has HealthKit sync enabled; otherwise discards the workout data.
    func endWorkoutSession(name: String? = nil) async {
        guard let session = workoutSession, let builder = workoutBuilder else { return }
        
        session.end()
        
        if isSyncEnabled {
            // User wants workouts saved to Health — finish and save
            do {
                if let name = name {
                    try await builder.addMetadata([
                        HKMetadataKeyWorkoutBrandName: "Pulse",
                        "WorkoutName": name
                    ])
                }
                try await builder.endCollection(at: Date())
                try await builder.finishWorkout()
                debugLog("📱 ✅ Ended HKWorkoutSession and saved workout to Health")
            } catch {
                debugLog("📱 ❌ Failed to end workout session: \(error.localizedDescription)")
            }
        } else {
            // Session was only used for background execution — discard the workout
            builder.discardWorkout()
            debugLog("📱 ✅ Ended HKWorkoutSession (workout discarded — sync not enabled)")
        }
        
        workoutSession = nil
        workoutBuilder = nil
        hasActiveBackgroundProtection = false
    }
    
    /// Cancels the active workout session without saving to HealthKit.
    func cancelWorkoutSession() {
        guard let session = workoutSession else { return }
        
        session.end()
        workoutBuilder?.discardWorkout()
        
        workoutSession = nil
        workoutBuilder = nil
        hasActiveBackgroundProtection = false
        
        debugLog("📱 🗑️ Cancelled HKWorkoutSession without saving")
    }
    
    /// Whether a workout session is currently active.
    var isWorkoutSessionActive: Bool {
        workoutSession?.state == .running
    }
    
    // MARK: - Save Workout (Legacy — used when workout session wasn't started)
    
    func saveWorkout(
        name: String,
        startDate: Date,
        durationSeconds: Int,
        exercises: [Exercise]
    ) async {
        // If we have an active workout session, it was already saved via endWorkoutSession()
        guard workoutSession == nil else { return }
        guard isSyncEnabled, isAvailable else { return }
        
        let endDate = startDate.addingTimeInterval(TimeInterval(durationSeconds))
        let activityType = resolveActivityType(from: exercises)
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .indoor
        
        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: nil
        )
        
        do {
            try await builder.beginCollection(at: startDate)
            try await builder.addMetadata([
                HKMetadataKeyWorkoutBrandName: "Pulse",
                "WorkoutName": name
            ])
            try await builder.endCollection(at: endDate)
            try await builder.finishWorkout()
            debugLog("✅ Workout saved to HealthKit: \(name)")
        } catch {
            debugLog("❌ Failed to save workout to HealthKit: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helpers
    
    private func resolveActivityType(from exercises: [Exercise]) -> HKWorkoutActivityType {
        let types = Set(exercises.compactMap { $0.exerciseType })
        
        if types == ["cardio"] {
            return .mixedCardio
        } else {
            return .traditionalStrengthTraining
        }
    }
    
    func disableSync() {
        isSyncEnabled = false
    }
}

// MARK: - HKWorkoutSessionDelegate

extension HealthKitManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in
            debugLog("📱 HKWorkoutSession state changed: \(fromState.rawValue) → \(toState.rawValue)")
            if toState == .ended || toState == .stopped {
                self.hasActiveBackgroundProtection = false
            }
        }
    }
    
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        Task { @MainActor in
            debugLog("📱 ❌ HKWorkoutSession failed: \(error.localizedDescription)")
            self.hasActiveBackgroundProtection = false
        }
    }
}
