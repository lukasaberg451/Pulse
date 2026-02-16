//
//  PulseWatchApp.swift
//  PulseWatch Watch App
//
//  Created by Lukas Åberg on 2026-02-16.
//

import SwiftUI

@main
struct PulseWatchAppApp: App {
    
    init() {
        // Initialize WatchConnectivity
        _ = WorkoutSyncManager.shared
        print("⌚ Watch app initializing...")
    }
    
    var body: some Scene {
        WindowGroup {
            WatchWorkoutView()
        }
    }
}
