//
//  WorkoutLiveActivityManager.swift
//  Pulse
//
//  Created by Lukas Åberg on 3/16/26.
//

import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
final class WorkoutLiveActivityManager {
    static let shared = WorkoutLiveActivityManager()
    
    #if canImport(ActivityKit)
    private var currentActivity: Activity<WorkoutActivityAttributes>?
    #endif
    
    private init() {}
    
    /// Starts a Live Activity for the current workout.
    /// This keeps the app's process priority elevated so iOS is less likely to terminate it in the background.
    func startLiveActivity(routineName: String, startTime: Date, firstExerciseName: String, totalExercises: Int, totalSetsForFirstExercise: Int) {
        #if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            debugLog("📱 Live Activities not enabled, skipping")
            return
        }
        
        let attributes = WorkoutActivityAttributes(
            routineName: routineName,
            startTime: startTime
        )
        
        let initialState = WorkoutActivityAttributes.ContentState(
            currentExerciseName: firstExerciseName,
            currentSetNumber: 1,
            totalSets: totalSetsForFirstExercise,
            completedExercises: 0,
            totalExercises: totalExercises,
            elapsedSeconds: 0
        )
        
        let content = ActivityContent(state: initialState, staleDate: nil)
        
        do {
            currentActivity = try Activity<WorkoutActivityAttributes>.request(
                attributes: attributes,
                content: content
            )
            debugLog("📱 ✅ Started workout Live Activity")
        } catch {
            debugLog("📱 ❌ Failed to start Live Activity: \(error.localizedDescription)")
        }
        #endif
    }
    
    /// Updates the Live Activity with current workout progress.
    func updateLiveActivity(
        currentExerciseName: String,
        currentSetNumber: Int,
        totalSets: Int,
        completedExercises: Int,
        totalExercises: Int,
        elapsedSeconds: Int
    ) {
        #if canImport(ActivityKit)
        guard let activity = currentActivity else { return }
        
        let updatedState = WorkoutActivityAttributes.ContentState(
            currentExerciseName: currentExerciseName,
            currentSetNumber: currentSetNumber,
            totalSets: totalSets,
            completedExercises: completedExercises,
            totalExercises: totalExercises,
            elapsedSeconds: elapsedSeconds
        )
        
        let content = ActivityContent(state: updatedState, staleDate: nil)
        
        Task {
            await activity.update(content)
        }
        #endif
    }
    
    /// Ends the Live Activity when the workout finishes or is cancelled.
    func endLiveActivity(completed: Bool = true) {
        #if canImport(ActivityKit)
        guard let activity = currentActivity else { return }
        
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            debugLog("📱 ✅ Ended workout Live Activity (completed: \(completed))")
        }
        currentActivity = nil
        #endif
    }
    
    /// Ends any stale Live Activities from a previous session (e.g. after app crash/termination).
    func endStaleLiveActivities() {
        #if canImport(ActivityKit)
        Task {
            for activity in Activity<WorkoutActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
                debugLog("📱 🧹 Cleaned up stale Live Activity: \(activity.id)")
            }
        }
        #endif
    }
}
