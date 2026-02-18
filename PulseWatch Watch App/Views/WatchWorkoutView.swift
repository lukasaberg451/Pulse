//
//  WatchWorkoutView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-16.
//

import SwiftUI
import WatchConnectivity
import HealthKit

struct WatchWorkoutView: View {
    @StateObject private var syncManager = WorkoutSyncManager.shared
    @State private var currentExerciseName: String = "No active workout"
    @State private var currentSet: Int = 1
    @State private var totalSets: Int = 0
    @State private var targetReps: String = ""
    @State private var targetWeight: Double = 0
    @State private var restTimeRemaining: Int = 0
    @State private var isResting: Bool = false
    @State private var workoutSession: HKWorkoutSession?
    
    var body: some View {
        VStack(spacing: 8) {
            // Show connection status at top for debugging
            Text(syncManager.isReachable ? "🟢 Connected" : "🔴 Disconnected")
                .font(.caption2)
                .foregroundColor(syncManager.isReachable ? .green : .red)
            
            if syncManager.isReachable && totalSets > 0 {
                // Connected and workout active
                VStack(spacing: 12) {
                    // Exercise name
                    Text(currentExerciseName)
                        .font(.headline)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                    
                    // Current set progress
                    Text("Set \(currentSet)/\(totalSets)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    // Target weight and reps
                    HStack(spacing: 16) {
                        VStack {
                            Text("\(targetWeight, specifier: "%.0f")kg")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("Weight")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        
                        if !targetReps.isEmpty {
                            VStack {
                                Text("\(targetReps)")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                Text("Reps")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .foregroundColor(.white)
                }
                
                Spacer()
                
                // Rest timer or log button
                if isResting {
                    Text("Rest")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("\(restTimeRemaining)s")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Button("Skip Rest") {
                        sendSkipRest()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                } else {
                    Button("Log Set") {
                        sendSetCompleted()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
            } else {
                // Not connected or no workout
                VStack {
                    Image(systemName: "applewatch.slash")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    
                    Text("No Active Workout")
                        .font(.headline)
                    
                    Text("Start a workout on iPhone")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding()
        .onAppear {
            print("⌚ Watch view appeared")
            print("⌚ isReachable: \(syncManager.isReachable)")
            
            // Check for existing context
            let context = WCSession.default.applicationContext
            if !context.isEmpty {
                print("⌚ Found existing context: \(context)")
                updateWorkoutData(context)
            }
            
            startWorkoutSession()
        }
        .onDisappear {
            endWorkoutSession()
        }
        .onChange(of: syncManager.isReachable) { oldValue, newValue in
            print("⌚ Reachability changed to: \(newValue)")
            
            // When connected, check for existing context
            if newValue {
                let context = WCSession.default.applicationContext
                if !context.isEmpty {
                    print("⌚ Loading existing context after connection: \(context)")
                    updateWorkoutData(context)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WorkoutDataReceived"))) { notification in
            print("⌚ Notification received!")
            if let data = notification.userInfo as? [String: Any] {
                print("⌚ Data: \(data)")
                updateWorkoutData(data)
            } else {
                print("⌚ No data in notification")
            }
        }
    }
    
    func updateWorkoutData(_ data: [String: Any]) {
        print("⌚ updateWorkoutData called with: \(data)")
        
        // Check if workout ended
        if data["workoutEnded"] as? Bool == true {
            currentExerciseName = "No active workout"
            totalSets = 0
            targetReps = ""
            targetWeight = 0
            currentSet = 1
            return
        }
        
        if let exerciseName = data["currentExercise"] as? String {
            print("⌚ Setting exercise name to: \(exerciseName)")
            currentExerciseName = exerciseName
        }
        
        if let sets = data["sets"] as? Int {
            print("⌚ Setting total sets: \(sets)")
            totalSets = sets
        }
        
        if let reps = data["reps"] as? String {
            print("⌚ Setting target reps: \(reps)")
            targetReps = reps
        }
        
        if let weight = data["weight"] as? Double {
            print("⌚ Setting target weight: \(weight)")
            targetWeight = weight
        }
        
        if let setNumber = data["currentSet"] as? Int {
            currentSet = setNumber
        } else {
            currentSet = 1
        }
    }
    
    func sendSetCompleted() {
        guard let session = WCSession.default as WCSession?, session.isReachable else {
            print("⌚ Cannot send - not reachable")
            return
        }
        
        guard let workoutData = WorkoutSyncManager.shared.currentWorkoutData,
              let exerciseIdString = workoutData["exerciseId"] as? String else {
            print("⌚ No exercise ID available")
            return
        }
        
        let message: [String: Any] = [
            "completedSet_exerciseId": exerciseIdString,
            "completedSet_setNumber": currentSet,
            "completedSet_reps": Int(targetReps) ?? 10,
            "completedSet_weight": targetWeight
        ]
        
        print("⌚ Sending completed set: \(message)")
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("⌚ Error sending set: \(error.localizedDescription)")
        }
        
        // Increment set locally
        if currentSet < totalSets {
            currentSet += 1
        }
    }
    
    func sendSkipRest() {
        guard let session = WCSession.default as WCSession?, session.isReachable else { return }
        
        let message = ["skipRest": true]
        session.sendMessage(message, replyHandler: nil)
    }
    
    func startWorkoutSession() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: HKHealthStore(), configuration: configuration)
            workoutSession?.startActivity(with: Date())
        } catch {
            print("⌚ Failed to start workout session: \(error)")
        }
    }
    
    func endWorkoutSession() {
        workoutSession?.end()
    }
}
