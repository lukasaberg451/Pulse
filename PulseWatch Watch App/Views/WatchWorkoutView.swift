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
    @StateObject private var sessionManager = WatchWorkoutSessionManager.shared
    @State private var currentExerciseName: String = "No active workout"
    @State private var currentSet: Int = 1
    @State private var totalSets: Int = 0
    @State private var targetReps: String = ""
    @State private var targetWeight: Double = 0
    @State private var exerciseType: String = "strength"
    @State private var targetDuration: Int = 0
    @State private var restSeconds: Int = 60
    @State private var restTimeRemaining: Int = 0
    @State private var isResting: Bool = false
    @State private var restTimer: Timer?
    @State private var workoutStartTime: Date?
    @State private var workoutDuration: TimeInterval = 0
    @State private var durationTimer: Timer?
    
    var body: some View {
        let showWorkout = !currentExerciseName.isEmpty && currentExerciseName != "No active workout" && totalSets > 0
        let workoutComplete = currentSet > totalSets && totalSets > 0
        
        ScrollView {
            VStack(spacing: 8) {
                if workoutComplete {
                    // WORKOUT COMPLETE VIEW
                    VStack(spacing: 12) {
                        Image("check-circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .foregroundStyle(.green)
                            .padding(.top, 20)
                        
                        Text("Workout Done!")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        Text("Finish the workout on iPhone")
                            .font(.caption)
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else if showWorkout {
                    if isResting {
                        // REST TIMER VIEW
                        VStack(spacing: 5) {
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
                            .buttonStyle(.bordered)
                            .tint(.appAccent)
                            .padding(.top, 8)
                        }
                        .padding(.vertical)
                    } else {
                        // WORKOUT VIEW
                        VStack(spacing: 4) {
                            // Exercise name
                            Text(currentExerciseName)
                                .font(.caption2)
                                .foregroundStyle(Color.appAccent)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            
                            if exerciseType == "cardio" {
                                // CARDIO VIEW - show time prominently
                                Text(timeString(from: workoutDuration))
                                    .font(.system(size: 40, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.appAccent)
                                    .padding(.top, 8)
                                
                                HStack(spacing: 8) {
                                    Text("Set \(currentSet)/\(totalSets)")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                    
                                    if targetDuration > 0 {
                                        Text("•")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                        
                                        Text(formatDuration(targetDuration))
                                            .font(.caption)
                                            .foregroundStyle(.white)
                                    }
                                }
                                .padding(.top, 2)
                            } else {
                                // STRENGTH VIEW - show weight and reps
                                // Workout timer
                                Text(timeString(from: workoutDuration))
                                    .font(.caption2)
                                    .foregroundStyle(Color.gray)
                                
                                // Current set progress
                                Text("Set \(currentSet)/\(totalSets)")
                                    .font(.body)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .padding(.top, 2)
                                
                                // Target weight and reps
                                HStack(spacing: 20) {
                                    VStack(spacing: 0) {
                                        Text("Weight")
                                            .font(.body)
                                            .foregroundStyle(.gray)
                                        Text("\(targetWeight, specifier: "%.1f") kg")
                                            .font(.body)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.white)
                                    }
                                    
                                    VStack(spacing: 0) {
                                        Text("Reps")
                                            .font(.body)
                                            .foregroundStyle(.gray)
                                       
                                        Text(targetReps.isEmpty ? "—" : "\(targetReps)")
                                            .font(.body)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.white)
                                    }
                                }
                                .padding(.top, 4)
                            }
                            
                            Button {
                                logSetAndStartRest()
                            } label: {
                                Text("Log Set")
                                    .font(.footnote)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.appAccent)
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 8)
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
            debugLog("⌚ WatchWorkoutView appeared")
            let context = WCSession.default.applicationContext
            if !context.isEmpty {
                debugLog("⌚ Found existing context: \(context)")
                updateWorkoutData(context)
            }
        }
        .onDisappear {
            debugLog("⌚ WatchWorkoutView disappeared")
            stopRestTimer()
            stopDurationTimer()
        }
        .onChange(of: syncManager.isReachable) { oldValue, newValue in
            debugLog("⌚ Reachability changed to: \(newValue)")
            if newValue {
                let context = WCSession.default.applicationContext
                if !context.isEmpty {
                    debugLog("⌚ Updating from context after reachability change")
                    updateWorkoutData(context)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WorkoutDataReceived"))) { notification in
            debugLog("⌚ Received WorkoutDataReceived notification")
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
        .onChange(of: syncManager.restTimerStoppedFromPhone) { _, newValue in
            if newValue {
                debugLog("⌚ Rest timer stopped from phone (via @Published)")
                stopRestTimer()
                syncManager.restTimerStoppedFromPhone = false
            }
        }
    }
    
    func updateWorkoutData(_ data: [String: Any]) {
        debugLog("⌚ ========== UPDATE WORKOUT DATA ==========")
        debugLog("⌚ Received data keys: \(data.keys.sorted())")
        debugLog("⌚ Full data: \(data)")
        
        // Check if rest was started from phone
        if data["restStarted"] as? Bool == true, let duration = data["restDuration"] as? Int {
            debugLog("⌚ Rest started from phone - starting rest timer for \(duration)s")
            restSeconds = duration
            startRestTimer()
        }
        
        // Check if rest was stopped from phone
        if data["restStopped"] as? Bool == true {
            debugLog("⌚ Rest stopped from phone - dismissing rest timer")
            stopRestTimer()
        }
        
        // Check if workout ended
        if data["workoutEnded"] as? Bool == true {
            debugLog("⌚ Workout ended - resetting all data")
            currentExerciseName = "No active workout"
            totalSets = 0
            targetReps = ""
            targetWeight = 0
            currentSet = 1
            workoutStartTime = nil
            workoutDuration = 0
            stopRestTimer()
            stopDurationTimer()
            sessionManager.endSession()
            return
        }
        
        // Update exercise details
        if let exerciseName = data["currentExercise"] as? String {
            debugLog("⌚ Setting exercise name: \(exerciseName)")
            currentExerciseName = exerciseName
        } else {
            debugLog("⌚ WARNING: No currentExercise in data")
        }
        
        if let sets = data["sets"] as? Int {
            debugLog("⌚ Setting total sets: \(sets)")
            totalSets = sets
        } else {
            debugLog("⌚ WARNING: No sets in data")
        }
        
        if let reps = data["reps"] as? String {
            debugLog("⌚ Setting target reps: '\(reps)'")
            targetReps = reps
        } else if let repsInt = data["reps"] as? Int {
            debugLog("⌚ Setting target reps from Int: '\(repsInt)'")
            targetReps = "\(repsInt)"
        } else {
            debugLog("⌚ WARNING: No reps in data or wrong type, value: \(String(describing: data["reps"]))")
        }
        
        if let weight = data["weight"] as? Double {
            debugLog("⌚ Setting target weight: \(weight)")
            targetWeight = weight
        } else if let weightInt = data["weight"] as? Int {
            debugLog("⌚ Setting target weight from Int: \(weightInt)")
            targetWeight = Double(weightInt)
        } else {
            debugLog("⌚ WARNING: No weight in data or wrong type, value: \(String(describing: data["weight"]))")
        }
        
        if let type = data["exerciseType"] as? String {
            debugLog("⌚ Setting exercise type: \(type)")
            exerciseType = type
        } else {
            debugLog("⌚ WARNING: No exerciseType in data, defaulting to strength")
            exerciseType = "strength"
        }
        
        if let duration = data["durationSeconds"] as? Int {
            debugLog("⌚ Setting target duration: \(duration)s")
            targetDuration = duration
        } else {
            targetDuration = 0
        }
        
        if let rest = data["rest"] as? Int {
            debugLog("⌚ Setting rest seconds: \(rest)")
            restSeconds = rest
        } else {
            debugLog("⌚ WARNING: No rest in data")
        }
        
        if let setNumber = data["currentSet"] as? Int {
            debugLog("⌚ Setting current set: \(setNumber)")
            currentSet = setNumber
        } else {
            debugLog("⌚ WARNING: No currentSet in data, defaulting to 1")
            currentSet = 1
        }
        
        // Check if this is a new workout starting or syncing with existing
        if let startTimeInterval = data["workoutStartTime"] as? TimeInterval {
            // Use the phone's actual start time so timers stay in sync
            let phoneStartTime = Date(timeIntervalSince1970: startTimeInterval)
            debugLog("⌚ Setting workout start time from phone: \(phoneStartTime)")
            workoutStartTime = phoneStartTime
            workoutDuration = Date().timeIntervalSince(phoneStartTime)
            startDurationTimer()
        } else if let workoutStarted = data["workoutStarted"] as? Bool, workoutStarted {
            // Fallback if no start time provided
            debugLog("⌚ New workout detected without start time - using current time")
            workoutStartTime = Date()
            workoutDuration = 0
            startDurationTimer()
        }
        
        debugLog("⌚ ========== STATE AFTER UPDATE ==========")
        debugLog("⌚ Exercise: '\(currentExerciseName)'")
        debugLog("⌚ Set: \(currentSet)/\(totalSets)")
        debugLog("⌚ Weight: \(targetWeight) kg")
        debugLog("⌚ Reps: '\(targetReps)'")
        debugLog("⌚ Rest: \(restSeconds) seconds")
        debugLog("⌚ UI should show: \(syncManager.isReachable && totalSets > 0 ? "WORKOUT VIEW" : "NO WORKOUT")")
        debugLog("⌚ ========================================")
    }
    
    func logSetAndStartRest() {
        WKInterfaceDevice.current().play(.click)
        
        // Send completed set to iPhone
        sendSetCompleted()
        
        // Don't increment currentSet here - wait for iPhone to send updated set number
        // Just start rest timer if not on last set
        if currentSet < totalSets {
            startRestTimer()
        }
    }
    
    func startRestTimer() {
        let endTime = Date().addingTimeInterval(TimeInterval(restSeconds))
        restTimeRemaining = restSeconds
        isResting = true
        
        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            let remaining = Int(ceil(endTime.timeIntervalSinceNow))
            if remaining <= 0 {
                self.stopRestTimer()
                WKInterfaceDevice.current().play(.notification)
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
        WKInterfaceDevice.current().play(.click)
        stopRestTimer()
        // Don't increment here - the iPhone will send the updated set number
        sendSkipRest()
    }
    
    func sendSetCompleted() {
        guard let session = WCSession.default as WCSession?, session.isReachable else {
            debugLog("⌚ Cannot send - not reachable")
            return
        }
        
        guard let workoutData = WorkoutSyncManager.shared.currentWorkoutData,
              let exerciseIdString = workoutData["exerciseId"] as? String else {
            debugLog("⌚ No exercise ID available")
            return
        }
        
        var message: [String: Any] = [
            "completedSet_exerciseId": exerciseIdString,
            "completedSet_setNumber": currentSet,
            "completedSet_reps": Int(targetReps) ?? 10,
            "completedSet_weight": targetWeight
        ]
        
        if exerciseType == "cardio" && targetDuration > 0 {
            message["completedSet_durationSeconds"] = targetDuration
        }
        
        debugLog("⌚ Sending completed set: \(message)")
        
        session.sendMessage(message, replyHandler: nil) { error in
            debugLog("⌚ Error sending set: \(error.localizedDescription)")
        }
    }
    
    func sendSkipRest() {
        guard let session = WCSession.default as WCSession?, session.isReachable else { return }
        
        let message = ["skipRest": true]
        session.sendMessage(message, replyHandler: nil)
    }
    
    
    func startDurationTimer() {
        // Stop any existing timer first
        stopDurationTimer()
        
        debugLog("⌚ Starting duration timer")
        
        // Update immediately first
        if let startTime = workoutStartTime {
            workoutDuration = Date().timeIntervalSince(startTime)
        }
        
        // Then schedule regular updates
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
            guard let startTime = self.workoutStartTime else {
                debugLog("⌚ Warning: No start time available")
                return
            }
            self.workoutDuration = Date().timeIntervalSince(startTime)
        }
    }

    func stopDurationTimer() {
        debugLog("⌚ Stopping duration timer")
        durationTimer?.invalidate()
        durationTimer = nil
    }

    func formatDuration(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if seconds > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(minutes)m"
    }
    
    func timeString(from duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
