//
//  DataMigrationHelper.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-24.
//

import Foundation
import SwiftData

@MainActor
class DataMigrationHelper {
    private let modelContext: ModelContext
    private let repository = WorkoutRepository()
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Migrate recent workouts from Supabase to local database
    /// Call this once when user first launches app with offline support
    func migrateRecentWorkoutsToLocal() async throws {
        // Check if we've already migrated
        let hasMigrated = UserDefaults.standard.bool(forKey: "hasMigratedWorkoutsToSwiftData")
        guard !hasMigrated else {
            print("ℹ️ Workouts already migrated")
            return
        }
        
        print("🔄 Starting workout migration...")
        
        do {
            // Fetch recent sessions from Supabase (limit to last 30 days to avoid long migration)
            let sessions = try await repository.fetchSessions()
            let recentSessions = Array(sessions.prefix(50)) // Only migrate 50 most recent
            
            print("🔄 Migrating \(recentSessions.count) workouts...")
            
            for session in recentSessions {
                // Check if session already exists locally
                let existsDescriptor = FetchDescriptor<LocalWorkoutSession>(
                    predicate: #Predicate { $0.id == session.id }
                )
                let existingCount = try modelContext.fetchCount(existsDescriptor)
                
                if existingCount == 0 {
                    // Create local copy
                    let localSession = LocalWorkoutSession.from(session)
                    modelContext.insert(localSession)
                    
                    // Fetch and migrate sets
                    let sets = try await repository.fetchSets(sessionId: session.id)
                    for set in sets {
                        let localSet = LocalWorkoutSet.from(set)
                        localSet.session = localSession
                        modelContext.insert(localSet)
                    }
                }
            }
            
            try modelContext.save()
            
            // Mark as migrated
            UserDefaults.standard.set(true, forKey: "hasMigratedWorkoutsToSwiftData")
            
            print("✅ Successfully migrated \(recentSessions.count) workouts")
        } catch {
            print("❌ Migration failed: \(error)")
            throw error
        }
    }
    
    /// Clear all local data (for testing or troubleshooting)
    func clearAllLocalData() throws {
        let sessionDescriptor = FetchDescriptor<LocalWorkoutSession>()
        let sessions = try modelContext.fetch(sessionDescriptor)
        
        for session in sessions {
            modelContext.delete(session)
        }
        
        try modelContext.save()
        
        // Reset migration flag
        UserDefaults.standard.set(false, forKey: "hasMigratedWorkoutsToSwiftData")
        
        print("🗑️ Cleared all local workout data")
    }
    
    /// Get migration status for debugging
    func getMigrationStatus() -> (migrated: Bool, localCount: Int, pendingSync: Int) {
        let migrated = UserDefaults.standard.bool(forKey: "hasMigratedWorkoutsToSwiftData")
        
        let totalDescriptor = FetchDescriptor<LocalWorkoutSession>()
        let localCount = (try? modelContext.fetchCount(totalDescriptor)) ?? 0
        
        let pendingDescriptor = FetchDescriptor<LocalWorkoutSession>(
            predicate: #Predicate { $0.needsSync == true }
        )
        let pendingSync = (try? modelContext.fetchCount(pendingDescriptor)) ?? 0
        
        return (migrated, localCount, pendingSync)
    }
}
