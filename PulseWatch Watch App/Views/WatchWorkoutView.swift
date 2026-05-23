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
    @State private var weightUnit: String = "kg"
    @State private var exerciseType: String = "strength"
    @State private var targetDuration: Int = 0
    @State private var restSeconds: Int = 60

    // Time-based state: store reference dates instead of timer-updated counters.
    // TimelineView re-evaluates the body on its schedule, so we compute
    // the remaining/elapsed values from these dates each time.
    @State private var isResting: Bool = false
    @State private var restEndDate: Date? = nil
    @State private var workoutStartTime: Date?

    // Weight input flow for strength exercises
    @State private var isEditingWeight: Bool = false
    @State private var actualWeightWhole: Int = 0
    @State private var actualWeightDecimal: Int = 0
    @FocusState private var isWeightWholeFocused: Bool

    // Reps input flow (second step after weight)
    @State private var isEditingReps: Bool = false
    @State private var actualReps: Int = 10

    var body: some View {
        // TimelineView keeps updating even when the watch enters the always-on
        // low-power state. The cadence drops to once per second or once per minute
        // depending on the display state, but the view is never "frozen".
        TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
            let now = timeline.date
            let showWorkout = !currentExerciseName.isEmpty && currentExerciseName != "No active workout" && totalSets > 0
            let workoutComplete = currentSet > totalSets && totalSets > 0

            // Compute time values from reference dates
            let workoutDuration: TimeInterval = {
                guard let start = workoutStartTime else { return 0 }
                return now.timeIntervalSince(start)
            }()

            let restTimeRemaining: Int = {
                guard let end = restEndDate else { return 0 }
                return max(0, Int(ceil(end.timeIntervalSince(now))))
            }()

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

                            Text("Workout Done!", comment: "Shown when all sets are completed")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)

                            Text("Finish the workout on iPhone", comment: "Instruction after workout completes")
                                .font(.caption)
                                .foregroundStyle(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    } else if showWorkout {
                        if isResting && restTimeRemaining > 0 {
                            // REST TIMER VIEW
                            VStack(spacing: 5) {
                                Text("Rest Time", comment: "Rest timer label")
                                    .font(.caption2)
                                    .foregroundStyle(Color.appText)

                                Text(verbatim: "\(restTimeRemaining)")
                                    .font(.system(size: 50, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.appAccent)

                                Text("seconds", comment: "Seconds label under rest timer")
                                    .font(.caption2)
                                    .foregroundStyle(Color.appText)

                                Button {
                                    skipRest()
                                } label: {
                                    Text("Skip Rest", comment: "Button to skip rest timer")
                                        .font(.footnote)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(.appAccent)
                                .padding(.top, 8)
                            }
                            .padding(.vertical)
                        } else {
                            // Auto-dismiss rest when timer reaches zero
                            let _ = handleRestExpiry(restTimeRemaining: restTimeRemaining)

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
                                        Text(verbatim: setProgressString(current: currentSet, total: totalSets))
                                            .font(.caption)
                                            .foregroundStyle(.gray)

                                        if targetDuration > 0 {
                                            Text(verbatim: "•")
                                                .font(.caption)
                                                .foregroundStyle(.gray)

                                            Text(formatDuration(targetDuration))
                                                .font(.caption)
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .padding(.top, 2)
                                } else if isEditingWeight {
                                    // STRENGTH WEIGHT INPUT VIEW
                                    Text(verbatim: setProgressString(current: currentSet, total: totalSets))
                                        .font(.caption2)
                                        .foregroundStyle(.gray)
                                        .padding(.bottom, -2)

                                    HStack(spacing: 2) {
                                        Picker("", selection: $actualWeightWhole) {
                                            ForEach(0..<500) { value in
                                                Text(verbatim: "\(value)").tag(value)
                                            }
                                        }
                                        .pickerStyle(.wheel)
                                        .frame(width: 55, height: 80)
                                        .focused($isWeightWholeFocused)

                                        Text(verbatim: ".")
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(.white)

                                        Picker("", selection: $actualWeightDecimal) {
                                            ForEach(0..<10) { value in
                                                Text(verbatim: "\(value)").tag(value)
                                            }
                                        }
                                        .pickerStyle(.wheel)
                                        .frame(width: 35, height: 80)

                                        Text(verbatim: weightUnit)
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }
                                    .padding(.bottom, 4)

                                    Button {
                                        prepareRepsInput()
                                    } label: {
                                        Text("Next", comment: "Button to proceed to reps input")
                                            .font(.footnote)
                                            .fontWeight(.semibold)
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.green)
                                } else if isEditingReps {
                                    // STRENGTH REPS INPUT VIEW
                                    Text(verbatim: setProgressString(current: currentSet, total: totalSets))
                                        .font(.caption2)
                                        .foregroundStyle(.gray)
                                        .padding(.bottom, -2)

                                    Text("Reps", comment: "Reps label in reps input")
                                        .font(.caption2)
                                        .foregroundStyle(.gray)

                                    HStack(spacing: 16) {
                                        Button {
                                            if actualReps > 1 {
                                                actualReps -= 1
                                                WKInterfaceDevice.current().play(.click)
                                            }
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.title2)
                                                .foregroundStyle(.gray)
                                        }
                                        .buttonStyle(.plain)

                                        Text(verbatim: "\(actualReps)")
                                            .font(.system(size: 36, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                            .frame(minWidth: 50)

                                        Button {
                                            if actualReps < 999 {
                                                actualReps += 1
                                                WKInterfaceDevice.current().play(.click)
                                            }
                                        } label: {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.title2)
                                                .foregroundStyle(.gray)
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    Button {
                                        logSetWithActualValues()
                                    } label: {
                                        Text("Log Set", comment: "Button to log a set with custom weight and reps")
                                            .font(.footnote)
                                            .fontWeight(.semibold)
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.green)
                                } else {
                                    // STRENGTH VIEW - show weight and reps
                                    // Workout timer
                                    Text(timeString(from: workoutDuration))
                                        .font(.caption2)
                                        .foregroundStyle(Color.gray)

                                    // Current set progress
                                    Text(verbatim: setProgressString(current: currentSet, total: totalSets))
                                        .font(.body)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                        .padding(.top, 2)

                                    // Target weight and reps
                                    HStack(spacing: 20) {
                                        VStack(spacing: 0) {
                                            Text("Weight", comment: "Weight label")
                                                .font(.body)
                                                .foregroundStyle(.gray)
                                            Text(verbatim: "\(String(format: "%.1f", targetWeight)) \(weightUnit)")
                                                .font(.body)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.white)
                                        }

                                        VStack(spacing: 0) {
                                            Text("Reps", comment: "Reps label")
                                                .font(.body)
                                                .foregroundStyle(.gray)

                                            Text(verbatim: targetReps.isEmpty ? "-" : targetReps)
                                                .font(.body)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .padding(.top, 4)
                                }

                                if !isEditingWeight && !isEditingReps {
                                    Button {
                                        if exerciseType == "strength" {
                                            prepareWeightInput()
                                        } else {
                                            logSetAndStartRest()
                                        }
                                    } label: {
                                        Text("Complete", comment: "Button to complete a set")
                                            .font(.footnote)
                                            .fontWeight(.semibold)
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.appAccent)
                                    .padding(.top, 8)
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                    } else {
                        // Not connected or no workout
                        VStack(spacing: 8) {
                            Text("No Active Workout", comment: "Shown when no workout is in progress")
                                .font(.footnote)
                                .fontWeight(.semibold)
                        }
                        .containerRelativeFrame(.vertical) { length, _ in
                            length
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 8)
            }
        }
        .onAppear {
            debugLog("⌚ WatchWorkoutView appeared")
            let context = WCSession.default.applicationContext
            if !context.isEmpty {
                debugLog("⌚ Found existing context: \(context)")
                updateWorkoutData(context)
            }
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
                restEndDate = Date().addingTimeInterval(TimeInterval(timeRemaining))
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

    /// Called from within the TimelineView body to detect when rest expires.
    /// Returns Void so it can be used with `let _ = ...` in the view builder.
    private func handleRestExpiry(restTimeRemaining: Int) {
        if isResting && restTimeRemaining <= 0 {
            DispatchQueue.main.async {
                if self.isResting {
                    WKInterfaceDevice.current().play(.notification)
                    self.stopRestTimer()
                }
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
            stopRestTimer()
            sessionManager.endSession()
            return
        }

        // Reset editing state when exercise data updates
        isEditingWeight = false
        isEditingReps = false

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

        if let unit = data["weightUnit"] as? String {
            weightUnit = unit
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
        } else if let workoutStarted = data["workoutStarted"] as? Bool, workoutStarted {
            // Fallback if no start time provided
            debugLog("⌚ New workout detected without start time - using current time")
            workoutStartTime = Date()
        }

        debugLog("⌚ ========== STATE AFTER UPDATE ==========")
        debugLog("⌚ Exercise: '\(currentExerciseName)'")
        debugLog("⌚ Set: \(currentSet)/\(totalSets)")
        debugLog("⌚ Weight: \(targetWeight) \(weightUnit)")
        debugLog("⌚ Reps: '\(targetReps)'")
        debugLog("⌚ Rest: \(restSeconds) seconds")
        debugLog("⌚ UI should show: \(totalSets > 0 ? "WORKOUT VIEW" : "NO WORKOUT")")
        debugLog("⌚ ========================================")
    }

    func prepareWeightInput() {
        WKInterfaceDevice.current().play(.click)
        let whole = Int(targetWeight)
        let decimal = Int(round((targetWeight - Double(whole)) * 10))
        actualWeightWhole = whole
        actualWeightDecimal = decimal
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditingWeight = true
        }
        isWeightWholeFocused = true
    }

    func prepareRepsInput() {
        WKInterfaceDevice.current().play(.click)
        actualReps = Int(targetReps) ?? 10
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditingWeight = false
            isEditingReps = true
        }
    }

    func logSetWithActualValues() {
        WKInterfaceDevice.current().play(.click)
        let actualWeight = Double(actualWeightWhole) + Double(actualWeightDecimal) / 10.0

        withAnimation(.easeInOut(duration: 0.2)) {
            isEditingReps = false
        }

        sendSetCompleted(overrideWeight: actualWeight, overrideReps: actualReps)

        if currentSet < totalSets {
            startRestTimer()
        }
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
        guard restSeconds > 0 else { return }
        restEndDate = Date().addingTimeInterval(TimeInterval(restSeconds))
        isResting = true
    }

    func stopRestTimer() {
        isResting = false
        restEndDate = nil
    }

    func skipRest() {
        WKInterfaceDevice.current().play(.click)
        stopRestTimer()
        // Don't increment here - the iPhone will send the updated set number
        sendSkipRest()
    }

    func sendSetCompleted(overrideWeight: Double? = nil, overrideReps: Int? = nil) {
        guard let session = WCSession.default as WCSession?, session.isReachable else {
            debugLog("⌚ Cannot send - not reachable")
            return
        }

        guard let workoutData = WorkoutSyncManager.shared.currentWorkoutData,
              let exerciseIdString = workoutData["exerciseId"] as? String else {
            debugLog("⌚ No exercise ID available")
            return
        }

        let weightToSend = overrideWeight ?? targetWeight
        let repsToSend = overrideReps ?? Int(targetReps) ?? 10

        var message: [String: Any] = [
            "completedSet_exerciseId": exerciseIdString,
            "completedSet_setNumber": currentSet,
            "completedSet_reps": repsToSend,
            "completedSet_weight": weightToSend
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

    func formatDuration(_ totalSeconds: Int) -> String {
        Duration.seconds(totalSeconds).formatted(
            .units(allowed: [.minutes, .seconds], width: .narrow)
        )
    }

    func timeString(from duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    func setProgressString(current: Int, total: Int) -> String {
        let setLabel = String(localized: "Set", comment: "Set progress label, e.g. 'Set 1/3'")
        return "\(setLabel) \(current)/\(total)"
    }
}
