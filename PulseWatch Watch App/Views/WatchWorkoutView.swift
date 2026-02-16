//
//  WatchWorkoutView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-16.
//

import SwiftUI
import WatchConnectivity

struct WatchWorkoutView: View {
    @StateObject private var syncManager = WorkoutSyncManager.shared
    @State private var currentExerciseName: String = "No active workout"
    @State private var currentSets: String = ""
    @State private var currentReps: String = ""
    @State private var restTimeRemaining: Int = 0
    @State private var isResting: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Show reachability status at top for debugging
            Text(syncManager.isReachable ? "🟢 Connected" : "🔴 Disconnected")
                .font(.caption2)
                .foregroundColor(syncManager.isReachable ? .green : .red)
            
            if syncManager.isReachable {
                // Connected - show workout
                VStack(spacing: 4) {
                    Text(currentExerciseName)
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    if !currentSets.isEmpty {
                        Text("\(currentSets) sets × \(currentReps) reps")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Rest timer
                if isResting {
                    Text("Rest")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("\(restTimeRemaining)s")
                        .font(.title)
                        .foregroundColor(.orange)
                    
                    Button("Skip Rest") {
                        sendSkipRest()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                } else {
                    Button("Complete Set") {
                        sendSetCompleted()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    Button("Check Context") {
                        let context = WCSession.default.applicationContext
                        print("⌚ Manual context check: \(context)")
                        if !context.isEmpty {
                            updateWorkoutData(context)
                        } else {
                            print("⌚ Context is empty")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                // Not connected
                VStack {
                    Image(systemName: "applewatch.slash")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    
                    Text("Not Connected")
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
            print("⌚ Current exercise: \(currentExerciseName)")
            
            // Check for existing context
            let context = WCSession.default.applicationContext
            if !context.isEmpty {
                print("⌚ Found existing context: \(context)")
                updateWorkoutData(context)
            }
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
        print("⌚ Received workout data: \(data)")
        
        if let exerciseName = data["currentExercise"] as? String {
            currentExerciseName = exerciseName
        }
        
        if let sets = data["sets"] as? Int,
           let reps = data["reps"] as? String {
            currentSets = "\(sets)"
            currentReps = reps
        }
    }
    
    func sendSetCompleted() {
        guard let session = WCSession.default as WCSession?, session.isReachable else {
            print("⌚ Cannot send - not reachable")
            return
        }
        
        let message: [String: Any] = [
            "completedSet_exerciseId": "test-id",
            "completedSet_setNumber": 1,
            "completedSet_reps": 10,
            "completedSet_weight": 50.0
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("⌚ Error sending set: \(error.localizedDescription)")
        }
    }
    
    func sendSkipRest() {
        guard let session = WCSession.default as WCSession?, session.isReachable else { return }
        
        let message = ["skipRest": true]
        session.sendMessage(message, replyHandler: nil)
    }
}
