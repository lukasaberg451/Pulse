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
    @Published var restTimerStoppedFromPhone = false
    static let restTimerUpdate = Notification.Name("restTimerUpdate")
    static let restTimerStopped = Notification.Name("restTimerStopped")
    
    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
    
    private override init() {
        super.init()
        
        guard let session = session else {
            return
        }
        
        session.delegate = self
        session.activate()
    }
    
    // MARK: - Send Data from iPhone to Watch
    
    func sendWorkoutToWatch(routine: Routine, routineExercises: [RoutineExercise], exercises: [Exercise], startTime: Date) {
        guard let session = session else {
            print("📱 ERROR: No WCSession available")
            return
        }
        
        guard let firstRoutineExercise = routineExercises.first,
              let firstExercise = exercises.first(where: { $0.id == firstRoutineExercise.exerciseId }) else {
            print("📱 ERROR: No exercises found to send")
            return
        }
        
        let workoutData: [String: Any] = [
            "workoutStarted": true,
            "workoutStartTime": startTime.timeIntervalSince1970,
            "routineName": routine.name,
            "exerciseId": firstExercise.id.uuidString,
            "currentExercise": firstExercise.name,
            "sets": firstRoutineExercise.sets,
            "currentSet": 1,
            "reps": firstRoutineExercise.repsTarget ?? "",
            "weight": firstRoutineExercise.targetWeight ?? 0,
            "rest": firstRoutineExercise.restSeconds,
            "exerciseType": (firstExercise.exerciseType ?? "strength") as Any,
            "durationSeconds": (firstRoutineExercise.durationSeconds ?? 0) as Any
        ]
        
        print("📱 ========== STARTING WORKOUT ON WATCH ==========")
        print("📱 Routine: \(routine.name)")
        print("📱 First Exercise: \(firstExercise.name)")
        print("📱 Sets: \(firstRoutineExercise.sets)")
        print("📱 Weight: \(firstRoutineExercise.targetWeight ?? 0) kg")
        print("📱 Reps: '\(firstRoutineExercise.repsTarget ?? "")'")
        print("📱 Start time: \(startTime)")
        print("📱 Full data: \(workoutData)")
        #if os(iOS)
        print("📱 Session state - isPaired: \(session.isPaired), isReachable: \(session.isReachable), activationState: \(session.activationState.rawValue)")
        #else
        print("📱 Session state - isReachable: \(session.isReachable), activationState: \(session.activationState.rawValue)")
        #endif
        
        // Use transferUserInfo with high priority - this will wake the Watch app
        session.transferUserInfo(workoutData)
        print("📱 ✅ Queued userInfo transfer")
        
        // Also try updateApplicationContext for immediate availability
        do {
            try session.updateApplicationContext(workoutData)
            print("📱 ✅ Updated application context")
        } catch {
            print("📱 ❌ Error updating context: \(error.localizedDescription)")
        }
        print("📱 ===============================================")
    }
    
    func sendRestTimerUpdate(timeRemaining: Int) {
        guard let session = session, session.isReachable else { return }
        
        let message = ["restTimer": timeRemaining]
        session.sendMessage(message, replyHandler: nil)
    }
    
    func sendRestTimerStopped() {
        guard let session = session else { return }
        
        let message: [String: Any] = ["restTimerStopped": true]
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("📱 Error sending restTimerStopped via message: \(error.localizedDescription)")
                // Fallback to transferUserInfo if sendMessage fails
                session.transferUserInfo(message)
                print("📱 Queued restTimerStopped via transferUserInfo fallback")
            }
        } else {
            // Not reachable, use guaranteed delivery
            session.transferUserInfo(message)
            print("📱 Queued restTimerStopped via transferUserInfo (not reachable)")
        }
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
    
    func sendCurrentExercise(exercise: Exercise, routineExercise: RoutineExercise, currentSetNumber: Int = 1, restStopped: Bool = false, restStarted: Bool = false, restDuration: Int = 0) {
        guard let session = session else {
            print("📱 ERROR: No WCSession available")
            return
        }
        
        var exerciseData: [String: Any] = [
            "exerciseId": exercise.id.uuidString,
            "currentExercise": exercise.name,
            "sets": routineExercise.sets,
            "currentSet": currentSetNumber,
            "reps": routineExercise.repsTarget ?? "",
            "weight": routineExercise.targetWeight ?? 0,
            "rest": routineExercise.restSeconds,
            "exerciseType": (exercise.exerciseType ?? "strength") as Any,
            "durationSeconds": (routineExercise.durationSeconds ?? 0) as Any
        ]
        
        if restStopped {
            exerciseData["restStopped"] = true
        }
        if restStarted {
            exerciseData["restStarted"] = true
            exerciseData["restDuration"] = restDuration
        }
        
        // Add timestamp to ensure applicationContext always sees this as new data
        exerciseData["timestamp"] = Date().timeIntervalSince1970
        
        print("📱 ========== SENDING EXERCISE UPDATE ==========")
        print("📱 Exercise: \(exercise.name)")
        print("📱 Current Set: \(currentSetNumber)/\(routineExercise.sets)")
        print("📱 restStarted: \(restStarted), restStopped: \(restStopped)")
        
        // Always try sendMessage for immediate delivery
        if session.isReachable {
            session.sendMessage(exerciseData, replyHandler: nil) { error in
                print("📱 ❌ sendMessage failed: \(error.localizedDescription)")
            }
            print("📱 ✅ Sent via sendMessage")
        }
        
        // Always use transferUserInfo as guaranteed delivery
        session.transferUserInfo(exerciseData)
        print("📱 ✅ Queued via transferUserInfo")
        
        // Also update application context
        do {
            try session.updateApplicationContext(exerciseData)
            print("📱 ✅ Updated application context")
        } catch {
            print("📱 ❌ Error updating context: \(error.localizedDescription)")
        }
        print("📱 ============================================")
    }
    
    func sendWorkoutEnded() {
        guard let session = session else { return }
        
        let endData: [String: Any] = ["workoutEnded": true]
        
        // Use sendMessage for immediate delivery when reachable
        if session.isReachable {
            session.sendMessage(endData, replyHandler: nil) { error in
                print("📱 ❌ sendMessage workoutEnded failed: \(error.localizedDescription)")
            }
            print("📱 ✅ Sent workoutEnded via sendMessage")
        }
        
        // Use transferUserInfo for guaranteed delivery
        session.transferUserInfo(endData)
        print("📱 ✅ Queued workoutEnded via transferUserInfo")
        
        // Also update application context
        do {
            try session.updateApplicationContext(endData)
            print("📱 ✅ Updated application context with workoutEnded")
        } catch {
            print("📱 ❌ Error updating context with workoutEnded: \(error.localizedDescription)")
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
            
            if userInfo["restTimerStopped"] as? Bool == true {
                print("⌚ Rest timer stopped from iPhone (via userInfo)")
                self.restTimerStoppedFromPhone = true
                return
            }
            
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
            // Process any message that contains exercise data (currentExercise) or routine data (routineName)
            if message.keys.contains("currentExercise") || message.keys.contains("routineName") {
                self.currentWorkoutData = message
                NotificationCenter.default.post(
                    name: NSNotification.Name("WorkoutDataReceived"),
                    object: nil,
                    userInfo: message
                )
            }
            
            if message["workoutEnded"] as? Bool == true {
                print("⌚ Workout ended from iPhone (via message)")
                self.currentWorkoutData = message
                NotificationCenter.default.post(
                    name: NSNotification.Name("WorkoutDataReceived"),
                    object: nil,
                    userInfo: message
                )
            }
            
            if message["restTimerStopped"] as? Bool == true {
                print("⌚ Rest timer stopped from iPhone (via message)")
                self.restTimerStoppedFromPhone = true
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
