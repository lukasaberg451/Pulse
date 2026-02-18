//
//  WorkoutSyncManager.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-16.
//

import Foundation
import WatchConnectivity
import Combine

class WorkoutSyncManager: NSObject, ObservableObject {
    static let shared = WorkoutSyncManager()
    
    @Published var isReachable = false
    @Published var currentWorkoutData: [String: Any]?
    
    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
    
    private override init() {
        super.init()
        print("WorkoutSyncManager initializing...")
        
        guard let session = session else {
            print("WCSession not supported")
            return
        }
        
        session.delegate = self
        session.activate()
    }
    
    // MARK: - Send Data from iPhone to Watch
    
    func sendWorkoutToWatch(routine: Routine, routineExercises: [RoutineExercise], exercises: [Exercise]) {
        guard let session = session else {
            print("📱 No session available")
            return
        }
        
        print("📱 Sending workout to watch: \(routine.name)")
        
        guard let firstRoutineExercise = routineExercises.first,
              let firstExercise = exercises.first(where: { $0.id == firstRoutineExercise.exerciseId }) else {
            print("📱 No exercises to send")
            return
        }
        
        let workoutData: [String: Any] = [
            "workoutStarted": true,  // Add this flag
            "routineName": routine.name,
            "exerciseId": firstExercise.id.uuidString,
            "currentExercise": firstExercise.name,
            "sets": firstRoutineExercise.sets,
            "currentSet": 1,
            "reps": firstRoutineExercise.repsTarget ?? "",
            "weight": firstRoutineExercise.targetWeight ?? 0,
            "rest": firstRoutineExercise.restSeconds,
            "exerciseType": (firstExercise.exerciseType ?? "strength") as Any
        ]
        
        print("📱 Sending via transferUserInfo...")
        
        // Use transferUserInfo with high priority - this will wake the Watch app
        session.transferUserInfo(workoutData)
        
        // Also try updateApplicationContext for immediate availability
        do {
            try session.updateApplicationContext(workoutData)
            print("📱 Context updated successfully")
        } catch {
            print("📱 Error updating context: \(error.localizedDescription)")
        }
    }
    
    func sendRestTimerUpdate(timeRemaining: Int) {
        guard let session = session, session.isReachable else { return }
        
        let message = ["restTimer": timeRemaining]
        session.sendMessage(message, replyHandler: nil)
    }
    
    func sendRestTimerStopped() {
        guard let session = session, session.isReachable else { return }
        
        let message = ["restTimerStopped": true]
        session.sendMessage(message, replyHandler: nil)
    }
    
    func sendWorkoutFinished() {
        guard let session = session, session.isReachable else { return }
        
        let message = ["workoutFinished": true]
        session.sendMessage(message, replyHandler: nil)
    }
    
    // MARK: - Receive Data from Watch
    
    func handleSetCompleted(exerciseId: String, setNumber: Int, reps: Int, weight: Double) {
        // This will be called on iPhone when Watch completes a set
        NotificationCenter.default.post(
            name: .setCompletedFromWatch,
            object: nil,
            userInfo: [
                "exerciseId": exerciseId,
                "setNumber": setNumber,
                "reps": reps,
                "weight": weight
            ]
        )
    }
    
    func handleSkipRest() {
        // This will be called on iPhone when Watch skips rest
        NotificationCenter.default.post(name: .skipRestFromWatch, object: nil)
    }
    
    func sendCurrentExercise(exercise: Exercise, routineExercise: RoutineExercise) {
        guard let session = session else { return }
        
        let exerciseData: [String: Any] = [
            "currentExercise": exercise.name,
            "sets": routineExercise.sets,
            "reps": routineExercise.repsTarget ?? "",
            "weight": routineExercise.targetWeight ?? 0,
            "rest": routineExercise.restSeconds,
            "exerciseType": (exercise.exerciseType ?? "strength") as Any
        ]
        
        print("📱 Sending current exercise to Watch: \(exercise.name)")
        
        do {
            try session.updateApplicationContext(exerciseData)
        } catch {
            print("📱 Error sending current exercise: \(error.localizedDescription)")
        }
    }
    
    func sendWorkoutEnded() {
        guard let session = session else { return }
        
        let endData: [String: Any] = ["workoutEnded": true]
        
        do {
            try session.updateApplicationContext(endData)
            print("📱 Sent workout ended to Watch")
        } catch {
            print("📱 Error sending workout ended: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WorkoutSyncManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ WCSession activation failed: \(error.localizedDescription)")
                } else {
                    print("✅ WCSession activated with state: \(activationState.rawValue)")
                    self.isReachable = session.isReachable
                }
            }
        }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            print("📩 Received application context: \(applicationContext)")
            
            #if os(watchOS)
            print("⌚ Processing context on Watch...")
            self.currentWorkoutData = applicationContext
            NotificationCenter.default.post(
                name: NSNotification.Name("WorkoutDataReceived"),
                object: nil,
                userInfo: applicationContext
            )
            print("⌚ Posted notification from context")
            #endif
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        DispatchQueue.main.async {
            print("📩 Received userInfo: \(userInfo)")
            
            #if os(watchOS)
            print("⌚ Processing userInfo on Watch...")
            self.currentWorkoutData = userInfo
            NotificationCenter.default.post(
                name: NSNotification.Name("WorkoutDataReceived"),
                object: nil,
                userInfo: userInfo
            )
            print("⌚ Posted notification from userInfo")
            #endif
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            print("REACHABILITY CHANGED: \(session.isReachable)")
            #if os(iOS)
            print("   isPaired: \(session.isPaired)")
            #endif
            print("   activationState: \(session.activationState.rawValue)")
        }
    }
    
    // Real-time messages (for buttons, timers, etc.)
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            print("📩 Received message: \(message)")
            
            #if os(watchOS)
            print("⌚ Processing message on Watch...")
            if message.keys.contains("routineName") {
                self.currentWorkoutData = message
                NotificationCenter.default.post(
                    name: NSNotification.Name("WorkoutDataReceived"),
                    object: nil,
                    userInfo: message
                )
            }
            #endif
            
            #if os(iOS)
            // Handle Watch button presses
            if let exerciseId = message["completedSet_exerciseId"] as? String,
               let setNumber = message["completedSet_setNumber"] as? Int,
               let reps = message["completedSet_reps"] as? Int,
               let weight = message["completedSet_weight"] as? Double {
                self.handleSetCompleted(exerciseId: exerciseId, setNumber: setNumber, reps: reps, weight: weight)
            }
            
            if message["skipRest"] as? Bool == true {
                self.handleSkipRest()
            }
            #endif
        }
    }
    
    // iOS-only delegate methods
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("📱 WCSession became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("📱 WCSession deactivated")
        session.activate()
    }
    #endif
}

// MARK: - Notification Names

extension Notification.Name {
    static let setCompletedFromWatch = Notification.Name("setCompletedFromWatch")
    static let skipRestFromWatch = Notification.Name("skipRestFromWatch")
}
