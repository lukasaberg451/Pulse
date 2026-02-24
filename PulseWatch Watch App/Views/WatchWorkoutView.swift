//
//  WatchWorkoutView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-16.
//

import SwiftUI
import WatchConnectivity
import HealthKit
import WatchKit

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
    @State private var workoutStartTime: Date?
    @State private var workoutDuration: TimeInterval = 0
    @State private var durationTimer: Timer?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if syncManager.isReachable && totalSets > 0 {
                    if isResting {
                        // REST TIMER VIEW
                        VStack(spacing: 10) {
                            Text("Rest Time")
                                .font(.caption2)
                                .foregroundStyle(Color.appText)
                            
                            Text("\(restTimeRemaining)")
                                .font(.system(size: 50, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.appAccent)
                            
                            Text("seconds")
                                .font(.caption2)
                                .foregroundStyle(Color.appText)
                            
                            Button {
                                skipRest()
                            } label: {
                                Text("Skip Rest")
                                    .font(.footnote)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .padding(.top, 8)
                        }
                        .padding(.vertical)
                    } else {
                        // WORKOUT VIEW
                        VStack(spacing: 8) {
                            // Exercise name
                            Text(currentExerciseName)
                                .font(.caption)
                                .foregroundStyle(Color.appAccent)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                            
                            // Workout timer
                            Text(timeString(from: workoutDuration))
                                .font(.caption)
                                .foregroundStyle(Color.gray)
                            
                            // Current set progress
                            Text("Set \(currentSet)/\(totalSets)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.appText)
                                .padding(.vertical, 4)
                            
                            // Target weight and reps
                            HStack(spacing: 16) {
                                VStack(spacing: 2) {
                                    Text("\(targetWeight, specifier: "%.1f")")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Text("kg")
                                        .font(.caption2)
                                        .foregroundStyle(Color.appText)
                                }
                                
                                if !targetReps.isEmpty {
                                    VStack(spacing: 2) {
                                        Text("\(targetReps)")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                        Text("reps")
                                            .font(.caption2)
                                            .foregroundStyle(Color.appText)
                                    }
                                }
                            }
                            .foregroundStyle(Color.appText)
                            .padding(.vertical, 4)
                            
                            Button {
                                logSetAndStartRest()
                            } label: {
                                Text("Log Set")
                                    .font(.footnote)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .padding(.top, 4)
                        }
                    }
                } else {
                    // Not connected or no workout
                    VStack(spacing: 8) {
                        Image(systemName: "applewatch.slash")
                            .font(.title)
                            .foregroundStyle(Color.appText)
                            .padding(.top, 20)
                        
                        Text("No Active Workout")
                            .font(.footnote)
                            .fontWeight(.semibold)
                        
                        Text("Start a workout on iPhone")
                            .font(.caption2)
                            .foregroundStyle(Color.appText)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 8)
        }
        .onAppear {
            print("⌚ WatchWorkoutView appeared")
            let context = WCSession.default.applicationContext
            if !context.isEmpty {
                print("⌚ Found existing context: \(context)")
                updateWorkoutData(context)
            }
            
            startWorkoutSession()
        }
        .onDisappear {
            print("⌚ WatchWorkoutView disappeared")
            stopRestTimer()
            stopDurationTimer()
            endWorkoutSession()
        }
        .onChange(of: syncManager.isReachable) { oldValue, newValue in
            print("⌚ Reachability changed to: \(newValue)")
            if newValue {
                let context = WCSession.default.applicationContext
                if !context.isEmpty {
                    print("⌚ Updating from context after reachability change")
                    updateWorkoutData(context)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WorkoutDataReceived"))) { notification in
            print("⌚ Received WorkoutDataReceived notification")
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
            print("⌚ Workout ended - resetting all data")
            currentExerciseName = "No active workout"
            totalSets = 0
            targetReps = ""
            targetWeight = 0
            currentSet = 1
            workoutStartTime = nil
            workoutDuration = 0
            stopRestTimer()
            stopDurationTimer()
            return
        }
        
        // Update exercise details
        if let exerciseName = data["currentExercise"] as? String {
            print("⌚ Setting exercise name: \(exerciseName)")
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
        
        if let rest = data["rest"] as? Int {
            print("⌚ Setting rest seconds: \(rest)")
            restSeconds = rest
        }
        
        if let setNumber = data["currentSet"] as? Int {
            print("⌚ Setting current set: \(setNumber)")
            currentSet = setNumber
        } else {
            currentSet = 1
        }
        
        // Check if this is a new workout starting (workoutStarted flag or workoutStartTime)
        if let workoutStarted = data["workoutStarted"] as? Bool, workoutStarted {
            print("⌚ New workout detected - starting timer")
            // New workout starting - reset and start timer
            workoutStartTime = Date()
            workoutDuration = 0
            startDurationTimer()
        } else if let startTimeInterval = data["workoutStartTime"] as? TimeInterval {
            // Sync with existing workout time from iPhone
            print("⌚ Syncing with existing workout timer from iPhone")
            workoutStartTime = Date(timeIntervalSince1970: startTimeInterval)
            if workoutStartTime != nil {
                startDurationTimer()
            }
        }
        
        print("⌚ Data update complete - exercise: \(currentExerciseName), sets: \(currentSet)/\(totalSets), weight: \(targetWeight)kg, reps: \(targetReps)")
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
        let endTime = Date().addingTimeInterval(TimeInterval(restSeconds))
        restTimeRemaining = restSeconds
        isResting = true
        
        restTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            let remaining = Int(endTime.timeIntervalSinceNow)
            if remaining <= 0 {
                self.stopRestTimer()
                self.currentSet += 1
                WKInterfaceDevice.current().play(.success)
            } else {
                self.restTimeRemaining = remaining
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
    
    func startDurationTimer() {
        // Stop any existing timer first
        stopDurationTimer()
        
        print("⌚ Starting duration timer")
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [self] _ in
            guard let startTime = self.workoutStartTime else {
                print("⌚ Warning: No start time available")
                return
            }
            self.workoutDuration = Date().timeIntervalSince(startTime)
        }
    }

    func stopDurationTimer() {
        print("⌚ Stopping duration timer")
        durationTimer?.invalidate()
        durationTimer = nil
    }

    func timeString(from duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
