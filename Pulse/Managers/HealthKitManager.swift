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
        
        // Not yet determined — request authorization silently
        if status == .notDetermined {
            let typesToShare: Set<HKSampleType> = [
                HKObjectType.workoutType()
            ]
            do {
                try await healthStore.requestAuthorization(toShare: typesToShare, read: [])
                let newStatus = healthStore.authorizationStatus(for: HKObjectType.workoutType())
                if newStatus == .sharingAuthorized {
                    isAuthorized = true
                    return true
                }
            } catch {
                debugLog("❌ HealthKit background auth error: \(error.localizedDescription)")
            }
        }
        
        return false
    }
    
    // MARK: - Live Workout Session (Background Execution)
    
    /// Starts an HKWorkoutSession which grants the app extended background execution.
    /// This prevents iOS from terminating the app while a workout is in progress.
    /// Always attempts to start regardless of the sync toggle — background protection
    /// is critical for all workouts. Will auto-request HealthKit authorization if needed.
    func startWorkoutSession(exercises: [Exercise]) async {
        guard isAvailable else {
            debugLog("📱 HealthKit not available on this device — no background execution protection")
            hasActiveBackgroundProtection = false
            return
        }
        
        // Ensure we have authorization (will prompt user if not yet determined)
        let authorized = await ensureAuthorizedForBackgroundExecution()
        guard authorized else {
            debugLog("📱 HealthKit not authorized — no background execution protection")
            hasActiveBackgroundProtection = false
            return
        }
        
        // End any existing session first
        if workoutSession != nil {
            await endWorkoutSession()
        }
        
        let activityType = resolveActivityType(from: exercises)
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .indoor
        
        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            session.delegate = self
            
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            
            session.startActivity(with: Date())
            try await builder.beginCollection(at: Date())
            
            self.workoutSession = session
            self.workoutBuilder = builder
            hasActiveBackgroundProtection = true
            
            debugLog("📱 ✅ Started HKWorkoutSession for background execution")
        } catch {
            hasActiveBackgroundProtection = false
            debugLog("📱 ❌ Failed to start HKWorkoutSession: \(error.localizedDescription)")
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
