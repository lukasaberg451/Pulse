//
//  WorkoutSyncManager.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-16.
//

import Foundation
import WatchConnectivity
import Combine
import HealthKit

class WorkoutSyncManager: NSObject, ObservableObject {
    static let shared = WorkoutSyncManager()
    
    @Published var isReachable = false
    @Published var isPaired = false
    @Published var isProUser = false
    @Published var currentWorkoutData: [String: Any]?
    @Published var restTimerStoppedFromPhone = false
    static let restTimerUpdate = Notification.Name("restTimerUpdate")
    static let restTimerStopped = Notification.Name("restTimerStopped")
    
    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
    #if os(iOS)
    private let healthStore = HKHealthStore()
    /// The mirrored workout session received from the watch via HealthKit mirroring.
    private var mirroredSession: HKWorkoutSession?
    #endif
    
    private override init() {
        super.init()

        guard let session = session else {
            return
        }

        session.delegate = self
        session.activate()

        #if os(iOS)
        // Handle mirrored workout sessions started from the watch.
        // This keeps the iPhone app aware of the active session and prevents
        // the system from terminating the connection.
        healthStore.workoutSessionMirroringStartHandler = { [weak self] mirroredSession in
            debugLog("📱 Received mirrored workout session from Watch")
            self?.mirroredSession = mirroredSession
        }
        #endif
    }
    
    // MARK: - Launch Watch App
    
    #if os(iOS)
    func launchWatchApp(exercises: [Exercise]) {
        guard let session = session, session.isPaired else {
            debugLog("📱 No watch paired — skipping watch app launch")
            return
        }
        
        let activityType: HKWorkoutActivityType
        let types = Set(exercises.compactMap { $0.exerciseType })
        if types == ["cardio"] {
            activityType = .mixedCardio
        } else {
            activityType = .traditionalStrengthTraining
        }
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .indoor
        
        healthStore.startWatchApp(with: configuration) { success, error in
            if let error = error {
                debugLog("📱 ❌ Failed to launch watch app: \(error.localizedDescription)")
            } else if success {
                debugLog("📱 ✅ Watch app launched successfully")
            } else {
                debugLog("📱 ⚠️ Watch app launch returned false without error")
            }
        }
    }
    #endif
    
    // MARK: - Sync Pro Status
    
    #if os(iOS)
    func syncProStatus(_ isProUser: Bool) {
        guard let session = session else { return }
        
        let data: [String: Any] = ["isProUser": isProUser]
        do {
            try session.updateApplicationContext(data)
        } catch {
            debugLog("📱 Error syncing pro status: \(error.localizedDescription)")
        }
    }
    #endif
    
    // MARK: - Send Data from iPhone to Watch
    
    func sendWorkoutToWatch(routine: Routine, routineExercises: [RoutineExercise], exercises: [Exercise], startTime: Date) {
        guard let session = session else {
            debugLog("📱 ERROR: No WCSession available")
            return
        }
        
        #if os(iOS)
        guard session.isPaired else {
            debugLog("📱 No watch paired — skipping watch sync")
            return
        }
        #endif
        
        guard let firstRoutineExercise = routineExercises.first,
              let firstExercise = exercises.first(where: { $0.id == firstRoutineExercise.exerciseId }) else {
            debugLog("📱 ERROR: No exercises found to send")
            return
        }
        
        let rawWeight = firstRoutineExercise.targetWeight ?? 0
        #if os(iOS)
        let displayWeight = UnitManager.shared.displayWeight(rawWeight)
        let weightUnitLabel = UnitManager.shared.weightUnit
        #else
        let displayWeight = rawWeight
        let weightUnitLabel = "kg"
        #endif

        let workoutData: [String: Any] = [
            "workoutStarted": true,
            "workoutStartTime": startTime.timeIntervalSince1970,
            "routineName": routine.name,
            "exerciseId": firstExercise.id.uuidString,
            "currentExercise": firstExercise.name,
            "sets": firstRoutineExercise.sets,
            "currentSet": 1,
            "reps": firstRoutineExercise.repsTarget ?? "",
            "weight": displayWeight,
            "weightUnit": weightUnitLabel,
            "rest": firstRoutineExercise.restSeconds,
            "exerciseType": (firstExercise.exerciseType ?? "strength") as Any,
            "durationSeconds": (firstRoutineExercise.durationSeconds ?? 0) as Any
        ]
        
        debugLog("📱 ========== STARTING WORKOUT ON WATCH ==========")
        debugLog("📱 Routine: \(routine.name)")
        debugLog("📱 First Exercise: \(firstExercise.name)")
        debugLog("📱 Sets: \(firstRoutineExercise.sets)")
        debugLog("📱 Weight: \(firstRoutineExercise.targetWeight ?? 0) kg")
        debugLog("📱 Reps: '\(firstRoutineExercise.repsTarget ?? "")'")
        debugLog("📱 Start time: \(startTime)")
        debugLog("📱 Full data: \(workoutData)")
        #if os(iOS)
        debugLog("📱 Session state - isPaired: \(session.isPaired), isReachable: \(session.isReachable), activationState: \(session.activationState.rawValue)")
        #else
        debugLog("📱 Session state - isReachable: \(session.isReachable), activationState: \(session.activationState.rawValue)")
        #endif
        
        // Use transferUserInfo with high priority - this will wake the Watch app
        session.transferUserInfo(workoutData)
        debugLog("📱 ✅ Queued userInfo transfer")
        
        // Also try updateApplicationContext for immediate availability
        do {
            try session.updateApplicationContext(workoutData)
            debugLog("📱 ✅ Updated application context")
        } catch {
            debugLog("📱 ❌ Error updating context: \(error.localizedDescription)")
        }
        debugLog("📱 ===============================================")
    }
    
    func sendRestTimerUpdate(timeRemaining: Int) {
        #if os(iOS)
        guard SubscriptionManager.shared.isProUser else { return }
        #endif
        guard let session = session, session.isReachable else { return }
        
        let message = ["restTimer": timeRemaining]
        session.sendMessage(message, replyHandler: nil)
    }
    
    func sendRestTimerStopped() {
        #if os(iOS)
        guard SubscriptionManager.shared.isProUser else { return }
        #endif
        guard let session = session else { return }
        
        let message: [String: Any] = ["restTimerStopped": true]
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                debugLog("📱 Error sending restTimerStopped via message: \(error.localizedDescription)")
                // Fallback to transferUserInfo if sendMessage fails
                session.transferUserInfo(message)
                debugLog("📱 Queued restTimerStopped via transferUserInfo fallback")
            }
        } else {
            // Not reachable, use guaranteed delivery
            session.transferUserInfo(message)
            debugLog("📱 Queued restTimerStopped via transferUserInfo (not reachable)")
        }
    }
    
    func sendWorkoutFinished() {
        #if os(iOS)
        guard SubscriptionManager.shared.isProUser else { return }
        #endif
        guard let session = session, session.isReachable else { return }
        
        let message = ["workoutFinished": true]
        session.sendMessage(message, replyHandler: nil)
    }
    
    // MARK: - Receive Data from Watch
    
    func handleSetCompleted(exerciseId: String, setNumber: Int, reps: Int, weight: Double, durationSeconds: Int?) {
        // Weight arrives in display units from the Watch — convert back to kg for storage
        #if os(iOS)
        let weightInKg = UnitManager.shared.toKg(weight)
        #else
        let weightInKg = weight
        #endif
        var userInfo: [String: Any] = [
            "exerciseId": exerciseId,
            "setNumber": setNumber,
            "reps": reps,
            "weight": weightInKg
        ]
        if let durationSeconds = durationSeconds {
            userInfo["durationSeconds"] = durationSeconds
        }
        NotificationCenter.default.post(
            name: .setCompletedFromWatch,
            object: nil,
            userInfo: userInfo
        )
    }
    
    func handleSkipRest() {
        // This will be called on iPhone when Watch skips rest
        NotificationCenter.default.post(name: .skipRestFromWatch, object: nil)
    }

    func sendCurrentExercise(exercise: Exercise, routineExercise: RoutineExercise, currentSetNumber: Int = 1, totalSets: Int? = nil, restStopped: Bool = false, restStarted: Bool = false, restDuration: Int = 0) {
        #if os(iOS)
        guard SubscriptionManager.shared.isProUser else {
            debugLog("📱 Skipping watch sync — user is not pro")
            return
        }
        #endif
        
        guard let session = session else {
            debugLog("📱 ERROR: No WCSession available")
            return
        }
        
        let rawWeight = routineExercise.targetWeight ?? 0
        #if os(iOS)
        let displayWeight = UnitManager.shared.displayWeight(rawWeight)
        let weightUnitLabel = UnitManager.shared.weightUnit
        #else
        let displayWeight = rawWeight
        let weightUnitLabel = "kg"
        #endif

        var exerciseData: [String: Any] = [
            "exerciseId": exercise.id.uuidString,
            "currentExercise": exercise.name,
            "sets": totalSets ?? routineExercise.sets,
            "currentSet": currentSetNumber,
            "reps": routineExercise.repsTarget ?? "",
            "weight": displayWeight,
            "weightUnit": weightUnitLabel,
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
        
        debugLog("📱 ========== SENDING EXERCISE UPDATE ==========")
        debugLog("📱 Exercise: \(exercise.name)")
        debugLog("📱 Current Set: \(currentSetNumber)/\(routineExercise.sets)")
        debugLog("📱 restStarted: \(restStarted), restStopped: \(restStopped)")
        
        // Always try sendMessage for immediate delivery
        if session.isReachable {
            session.sendMessage(exerciseData, replyHandler: nil) { error in
                debugLog("📱 ❌ sendMessage failed: \(error.localizedDescription)")
            }
            debugLog("📱 ✅ Sent via sendMessage")
        }
        
        // Always use transferUserInfo as guaranteed delivery
        session.transferUserInfo(exerciseData)
        debugLog("📱 ✅ Queued via transferUserInfo")
        
        // Also update application context
        do {
            try session.updateApplicationContext(exerciseData)
            debugLog("📱 ✅ Updated application context")
        } catch {
            debugLog("📱 ❌ Error updating context: \(error.localizedDescription)")
        }
        debugLog("📱 ============================================")
    }
    
    func sendWorkoutEnded() {
        guard let session = session else { return }
        
        let endData: [String: Any] = ["workoutEnded": true]
        
        // Use sendMessage for immediate delivery when reachable
        if session.isReachable {
            session.sendMessage(endData, replyHandler: nil) { error in
                debugLog("📱 ❌ sendMessage workoutEnded failed: \(error.localizedDescription)")
            }
            debugLog("📱 ✅ Sent workoutEnded via sendMessage")
        }
        
        // Use transferUserInfo for guaranteed delivery
        session.transferUserInfo(endData)
        debugLog("📱 ✅ Queued workoutEnded via transferUserInfo")
        
        // Also update application context
        do {
            try session.updateApplicationContext(endData)
            debugLog("📱 ✅ Updated application context with workoutEnded")
        } catch {
            debugLog("📱 ❌ Error updating context with workoutEnded: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WorkoutSyncManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
            DispatchQueue.main.async {
                if let error = error {
                    debugLog("❌ WCSession activation failed: \(error.localizedDescription)")
                } else {
                    debugLog("✅ WCSession activated with state: \(activationState.rawValue)")
                    self.isReachable = session.isReachable
                    #if os(iOS)
                    self.isPaired = session.isPaired
                    #endif
                    #if os(watchOS)
                    if let proStatus = session.receivedApplicationContext["isProUser"] as? Bool {
                        self.isProUser = proStatus
                    }
                    #endif
                }
            }
        }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            debugLog("📩 Received application context: \(applicationContext)")
            
            #if os(watchOS)
            if let proStatus = applicationContext["isProUser"] as? Bool {
                self.isProUser = proStatus
            }
            
            debugLog("⌚ Processing context on Watch...")
            self.currentWorkoutData = applicationContext
            NotificationCenter.default.post(
                name: NSNotification.Name("WorkoutDataReceived"),
                object: nil,
                userInfo: applicationContext
            )
            debugLog("⌚ Posted notification from context")
            #endif
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        DispatchQueue.main.async {
            debugLog("📩 Received userInfo: \(userInfo)")
            
            #if os(watchOS)
            debugLog("⌚ Processing userInfo on Watch...")
            
            if userInfo["restTimerStopped"] as? Bool == true {
                debugLog("⌚ Rest timer stopped from iPhone (via userInfo)")
                self.restTimerStoppedFromPhone = true
                return
            }
            
            self.currentWorkoutData = userInfo
            NotificationCenter.default.post(
                name: NSNotification.Name("WorkoutDataReceived"),
                object: nil,
                userInfo: userInfo
            )
            debugLog("⌚ Posted notification from userInfo")
            #endif
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            #if os(iOS)
            self.isPaired = session.isPaired
            #endif
            debugLog("REACHABILITY CHANGED: \(session.isReachable)")
            #if os(iOS)
            debugLog("   isPaired: \(session.isPaired)")
            #endif
            debugLog("   activationState: \(session.activationState.rawValue)")
        }
    }
    
    // Real-time messages (for buttons, timers, etc.)
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            debugLog("📩 Received message: \(message)")
            
            #if os(watchOS)
            debugLog("⌚ Processing message on Watch...")
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
                debugLog("⌚ Workout ended from iPhone (via message)")
                self.currentWorkoutData = message
                NotificationCenter.default.post(
                    name: NSNotification.Name("WorkoutDataReceived"),
                    object: nil,
                    userInfo: message
                )
            }
            
            if message["restTimerStopped"] as? Bool == true {
                debugLog("⌚ Rest timer stopped from iPhone (via message)")
                self.restTimerStoppedFromPhone = true
            }
            #endif
            
            #if os(iOS)
            // Handle Watch button presses
            if let exerciseId = message["completedSet_exerciseId"] as? String,
               let setNumber = message["completedSet_setNumber"] as? Int,
               let reps = message["completedSet_reps"] as? Int,
               let weight = message["completedSet_weight"] as? Double {
                let durationSeconds = message["completedSet_durationSeconds"] as? Int
                self.handleSetCompleted(exerciseId: exerciseId, setNumber: setNumber, reps: reps, weight: weight, durationSeconds: durationSeconds)
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
        debugLog("📱 WCSession became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        debugLog("📱 WCSession deactivated")
        session.activate()
    }
    #endif
}

// MARK: - Notification Names

extension Notification.Name {
    static let setCompletedFromWatch = Notification.Name("setCompletedFromWatch")
    static let skipRestFromWatch = Notification.Name("skipRestFromWatch")
}
