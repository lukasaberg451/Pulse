//
//  PulseWatchApp.swift
//  PulseWatch Watch App
//
//  Created by Lukas Åberg on 2026-02-16.
//

import SwiftUI
import HealthKit
import WatchKit
import Combine

class WatchWorkoutSessionManager: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    static let shared = WatchWorkoutSessionManager()

    @Published var workoutSession: HKWorkoutSession?
    @Published var isSessionActive = false
    private var builder: HKLiveWorkoutBuilder?
    let healthStore = HKHealthStore()

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType()
        ]

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]

        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            debugLog("⌚ HealthKit authorization granted")
        } catch {
            debugLog("⌚ HealthKit authorization failed: \(error.localizedDescription)")
        }
    }

    func startSession(configuration: HKWorkoutConfiguration) {
        // End any existing session first
        if let existing = workoutSession {
            existing.end()
            workoutSession = nil
            builder = nil
        }

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            session.delegate = self

            // Set up the live workout builder so the system fully recognizes this as an active workout.
            // This prevents Apple Fitness from asking "Are you working out?" and keeps the app
            // in the foreground during the workout.
            let workoutBuilder = session.associatedWorkoutBuilder()
            workoutBuilder.delegate = self
            workoutBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

            self.builder = workoutBuilder
            self.workoutSession = session

            // Start mirroring to iPhone — this creates a proper mirrored session link
            // which makes the workout delivery reliable and keeps the watch app prioritized.
            Task {
                do {
                    try await session.startMirroringToCompanionDevice()
                    debugLog("⌚ Successfully started mirroring to companion device")
                } catch {
                    debugLog("⌚ Failed to start mirroring: \(error.localizedDescription)")
                }
            }

            // Start the session activity
            let startDate = Date()
            session.startActivity(with: startDate)

            Task {
                do {
                    try await workoutBuilder.beginCollection(at: startDate)
                    debugLog("⌚ Workout builder began collection")
                } catch {
                    debugLog("⌚ Failed to begin builder collection: \(error.localizedDescription)")
                }
            }

            DispatchQueue.main.async {
                self.isSessionActive = true
            }

            debugLog("⌚ HKWorkoutSession started with builder, activity type: \(configuration.activityType.rawValue)")
        } catch {
            debugLog("⌚ Failed to start workout session: \(error)")
        }
    }

    func endSession() {
        guard let session = workoutSession else { return }

        session.end()

        // Discard the workout (we don't save it to HealthKit — the app is just for tracking sets)
        builder?.discardWorkout()
        debugLog("⌚ Workout builder discarded")

        workoutSession = nil
        builder = nil

        DispatchQueue.main.async {
            self.isSessionActive = false
        }

        debugLog("⌚ Workout session ended")
    }

    // MARK: - HKWorkoutSessionDelegate

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        debugLog("⌚ Workout session state changed: \(fromState.rawValue) -> \(toState.rawValue)")
        DispatchQueue.main.async {
            self.isSessionActive = (toState == .running)
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        debugLog("⌚ Workout session failed: \(error.localizedDescription)")
    }

    // MARK: - HKLiveWorkoutBuilderDelegate

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // No-op: we don't need to process workout events
    }

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        // No-op: we don't need to process collected health data
    }
}

class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        debugLog("⌚ handle(_:) called from iPhone with activity: \(workoutConfiguration.activityType.rawValue)")
        // Start the HKWorkoutSession immediately — this brings the app to the foreground
        WatchWorkoutSessionManager.shared.startSession(configuration: workoutConfiguration)
    }
}

@main
struct PulseWatchAppApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) var appDelegate
    
    init() {
        // Initialize WatchConnectivity
        _ = WorkoutSyncManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            WatchWorkoutView()
                .task {
                    await WatchWorkoutSessionManager.shared.requestAuthorization()
                }
        }
    }
}
