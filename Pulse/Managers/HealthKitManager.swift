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
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    @Published var isAuthorized = false
    @Published var showDeniedAlert = false
    @AppStorage("healthKitSyncEnabled") var isSyncEnabled = false
    
    private let healthStore = HKHealthStore()
    
    private init() {}
    
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
    
    // MARK: - Save Workout
    
    func saveWorkout(
        name: String,
        startDate: Date,
        durationSeconds: Int,
        exercises: [Exercise]
    ) async {
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
