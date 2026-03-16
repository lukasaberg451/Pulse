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
    
    // MARK: - Live Workout Session (Background Execution)
    
    /// Starts an HKWorkoutSession which grants the app extended background execution
    /// via the workout-processing background mode. This prevents iOS from terminating
    /// the app while a workout is in progress.
    func startWorkoutSession(exercises: [Exercise]) async {
        guard isSyncEnabled, isAvailable else {
            debugLog("📱 HealthKit not enabled, skipping workout session")
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
            
            debugLog("📱 ✅ Started HKWorkoutSession for background execution")
        } catch {
            debugLog("📱 ❌ Failed to start HKWorkoutSession: \(error.localizedDescription)")
        }
    }
    
    /// Ends the active workout session and saves the workout to HealthKit.
    func endWorkoutSession(name: String? = nil) async {
        guard let session = workoutSession, let builder = workoutBuilder else { return }
        
        session.end()
        
        do {
            if let name = name {
                try await builder.addMetadata([
                    HKMetadataKeyWorkoutBrandName: "Pulse",
                    "WorkoutName": name
                ])
            }
            try await builder.endCollection(at: Date())
            try await builder.finishWorkout()
            debugLog("📱 ✅ Ended HKWorkoutSession and saved workout")
        } catch {
            debugLog("📱 ❌ Failed to end workout session: \(error.localizedDescription)")
        }
        
        workoutSession = nil
        workoutBuilder = nil
    }
    
    /// Cancels the active workout session without saving to HealthKit.
    func cancelWorkoutSession() {
        guard let session = workoutSession else { return }
        
        session.end()
        workoutBuilder?.discardWorkout()
        
        workoutSession = nil
        workoutBuilder = nil
        
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
        }
    }
    
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        Task { @MainActor in
            debugLog("📱 ❌ HKWorkoutSession failed: \(error.localizedDescription)")
        }
    }
}
