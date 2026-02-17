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
            "routineName": routine.name,
            "currentExercise": firstExercise.name,
            "sets": firstRoutineExercise.sets,
            "reps": firstRoutineExercise.repsTarget ?? "",
            "weight": firstRoutineExercise.targetWeight ?? 0,
            "rest": firstRoutineExercise.restSeconds,
            "exerciseType": firstExercise.exerciseType ?? ""
        ]
        
        print("📱 Sending via transferUserInfo...")
        let transfer = session.transferUserInfo(workoutData)
        print("📱 Transfer created, isTransferring: \(transfer.isTransferring)")
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
