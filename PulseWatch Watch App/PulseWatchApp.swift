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

class WatchWorkoutSessionManager: NSObject, ObservableObject, HKWorkoutSessionDelegate {
    static let shared = WatchWorkoutSessionManager()
    
    @Published var workoutSession: HKWorkoutSession?
    private let healthStore = HKHealthStore()
    
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType()
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: [])
            print("⌚ HealthKit authorization granted")
        } catch {
            print("⌚ HealthKit authorization failed: \(error.localizedDescription)")
        }
    }
    
    func startSession(configuration: HKWorkoutConfiguration) {
        // End any existing session first
        workoutSession?.end()
        workoutSession = nil
        
        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            session.delegate = self
            session.startActivity(with: Date())
            workoutSession = session
            print("⌚ HKWorkoutSession started with activity type: \(configuration.activityType.rawValue)")
        } catch {
            print("⌚ Failed to start workout session: \(error)")
        }
    }
    
    func endSession() {
        workoutSession?.end()
        workoutSession = nil
    }
    
    // MARK: - HKWorkoutSessionDelegate
    
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        print("⌚ Workout session state changed: \(fromState.rawValue) -> \(toState.rawValue)")
    }
    
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        print("⌚ Workout session failed: \(error.localizedDescription)")
    }
}

class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        print("⌚ handle(_:) called from iPhone with activity: \(workoutConfiguration.activityType.rawValue)")
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
