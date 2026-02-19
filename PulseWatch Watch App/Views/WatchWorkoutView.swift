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
    @State private var restSeconds: Int = 60
    @State private var restTimeRemaining: Int = 0
    @State private var isResting: Bool = false
    @State private var restTimer: Timer?
    @State private var workoutSession: HKWorkoutSession?
    
    var body: some View {
        VStack(spacing: 8) {
            
            if syncManager.isReachable && totalSets > 0 {
                if isResting {
                    // REST TIMER VIEW
                    VStack(spacing: 16) {
                        Text("Rest Time")
                            .font(.caption)
                            .foregroundStyle(Color.appText)
                        
                        Text("\(restTimeRemaining)")
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.appAccent)
                        
                        Text("seconds")
                            .font(.caption)
                            .foregroundStyle(Color.appText)
                        
                        Spacer()
                        
                        Button {
                            skipRest()
                        } label: {
                            Text("Skip Rest")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                    .padding()
                } else {
                    // WORKOUT VIEW
                    VStack(spacing: 12) {
                        // Exercise name
                        Text(currentExerciseName)
                            .font(.headline)
                            .foregroundStyle(Color.appAccent)
                            .multilineTextAlignment(.center)
                        
                        // Current set progress
                        Text("Set \(currentSet)/\(totalSets)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.appText)
                        
                        // Target weight and reps
                        HStack(spacing: 16) {
                            VStack {
                                Text("\(targetWeight, specifier: "%.0f")kg")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                Text("Weight")
                                    .font(.caption2)
                                    .foregroundStyle(Color.appText)
                            }
                            
                            if !targetReps.isEmpty {
                                VStack {
                                    Text("\(targetReps)")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Text("Reps")
                                        .font(.caption2)
                                        .foregroundStyle(Color.appText)
                                }
                            }
                        }
                        .foregroundStyle(Color.appText)
                    }
                    
                    Spacer()
                    
                    Button {
                        logSetAndStartRest()
                    } label: {
                        Text("Log Set")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
            } else {
                // Not connected or no workout
                VStack {
                    Image(systemName: "applewatch.slash")
                        .font(.largeTitle)
                        .foregroundStyle(Color.appText)
                    
                    Text("No Active Workout")
                        .font(.headline)
                    
                    Text("Start a workout on iPhone")
                        .font(.caption)
                        .foregroundStyle(Color.appText)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding()
        .onAppear {
            
            let context = WCSession.default.applicationContext
            if !context.isEmpty {
                print("⌚ Found existing context: \(context)")
                updateWorkoutData(context)
            }
            
            startWorkoutSession()
        }
        .onDisappear {
            stopRestTimer()
            endWorkoutSession()
        }
        .onChange(of: syncManager.isReachable) { oldValue, newValue in
            if newValue {
                let context = WCSession.default.applicationContext
                if !context.isEmpty {
                    updateWorkoutData(context)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WorkoutDataReceived"))) { notification in
            if let data = notification.userInfo as? [String: Any] {
                updateWorkoutData(data)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RestTimerUpdate"))) { notification in
            if let timeRemaining = notification.userInfo?["timeRemaining"] as? Int {
                restTimeRemaining = timeRemaining
                isResting = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RestTimerStopped"))) { _ in
            stopRestTimer()
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
            stopRestTimer()
            return
        }
        
        if let exerciseName = data["currentExercise"] as? String {
            currentExerciseName = exerciseName
        }
        
        if let sets = data["sets"] as? Int {
            totalSets = sets
        }
        
        if let reps = data["reps"] as? String {
            targetReps = reps
        }
        
        if let weight = data["weight"] as? Double {
            targetWeight = weight
        }
        
        if let rest = data["rest"] as? Int {
            restSeconds = rest
        }
        
        if let setNumber = data["currentSet"] as? Int {
            currentSet = setNumber
        } else {
            currentSet = 1
        }
    }
    
    func logSetAndStartRest() {
        // Send completed set to iPhone
        sendSetCompleted()
        
        // Start rest timer only if not on last set
        if currentSet < totalSets {
            startRestTimer()
        } else {
            // Last set completed - increment but don't rest
            currentSet += 1
        }
    }
    
    func startRestTimer() {
        restTimeRemaining = restSeconds
        isResting = true
        
        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if restTimeRemaining > 0 {
                restTimeRemaining -= 1
            } else {
                // Rest complete - move to next set
                stopRestTimer()
                currentSet += 1
            }
        }
    }
    
    func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        isResting = false
        restTimeRemaining = 0
    }
    
    func skipRest() {
        stopRestTimer()
        currentSet += 1
        sendSkipRest()
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
