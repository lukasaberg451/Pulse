//
//  WorkoutActivityAttributes.swift
//  Pulse
//
//  Created by Lukas Åberg on 3/16/26.
//

import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(ActivityKit)
struct WorkoutActivityAttributes: ActivityAttributes {
    /// Static data that doesn't change during the Live Activity
    let routineName: String
    let startTime: Date
    
    /// Dynamic data that updates as the workout progresses
    struct ContentState: Codable, Hashable {
        let currentExerciseName: String
        let currentSetNumber: Int
        let totalSets: Int
        let completedExercises: Int
        let totalExercises: Int
        let elapsedSeconds: Int
    }
}
#endif
