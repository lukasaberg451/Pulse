//
//  WorkoutRepository.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/8/26.
//

import Foundation
import Supabase
import SwiftData

class WorkoutRepository {
    private let supabase = SupabaseManager.shared.client
    
    // Start a new workout session
    func createSession(name: String, routineId: UUID?) async throws -> WorkoutSession {
        let session: WorkoutSession = try await supabase
            .from("workout_sessions")
            .insert([
                "name": name,
                "routine_id": routineId?.uuidString ?? ""
            ])
            .select()
            .single()
            .execute()
            .value
        
        return session
    }
    
    // Create a session with a specific ID (for syncing local data)
    func createSessionWithId(id: UUID, name: String, routineId: UUID?, startedAt: Date) async throws {
        struct InsertData: Encodable {
            let id: String
            let name: String
            let routine_id: String?
            let started_at: String
        }
        
        let data = InsertData(
            id: id.uuidString,
            name: name,
            routine_id: routineId?.uuidString,
            started_at: ISO8601DateFormatter().string(from: startedAt)
        )
        
        try await supabase
            .from("workout_sessions")
            .insert(data)
            .execute()
    }
    
    // Fetch all workout sessions
    func fetchSessions() async throws -> [WorkoutSession] {
        let response: [WorkoutSession] = try await supabase
            .from("workout_sessions")
            .select()
            .order("started_at", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    // Fetch sets for a session
    func fetchSets(sessionId: UUID) async throws -> [WorkoutSet] {
        let response: [WorkoutSet] = try await supabase
            .from("workout_sets")
            .select()
            .eq("session_id", value: sessionId.uuidString)
            .order("set_number")
            .execute()
            .value
        
        return response
    }
    
    // Add a set to a workout
    func createSet(
        sessionId: UUID,
        exerciseId: UUID,
        setNumber: Int,
        reps: Int?,
        weight: Double?
    ) async throws -> WorkoutSet {
        struct InsertData: Encodable {
            let session_id: String
            let exercise_id: String
            let set_number: Int
            let reps: Int?
            let weight: Double?
            let completed: Bool
        }
        
        let data = InsertData(
            session_id: sessionId.uuidString,
            exercise_id: exerciseId.uuidString,
            set_number: setNumber,
            reps: reps,
            weight: weight,
            completed: false
        )
        
        let workoutSet: WorkoutSet = try await supabase
            .from("workout_sets")
            .insert(data)
            .select()
            .single()
            .execute()
            .value
        
        return workoutSet
    }
    
    // Add a set with a specific ID (for syncing local data)
    func createSetWithId(
        id: UUID,
        sessionId: UUID,
        exerciseId: UUID,
        setNumber: Int,
        reps: Int?,
        weight: Double?,
        durationSeconds: Int?,
        completed: Bool
    ) async throws -> WorkoutSet {
        struct InsertData: Encodable {
            let id: String
            let session_id: String
            let exercise_id: String
            let set_number: Int
            let reps: Int?
            let weight: Double?
            let duration_seconds: Int?
            let completed: Bool
        }
        
        let data = InsertData(
            id: id.uuidString,
            session_id: sessionId.uuidString,
            exercise_id: exerciseId.uuidString,
            set_number: setNumber,
            reps: reps,
            weight: weight,
            duration_seconds: durationSeconds,
            completed: completed
        )
        
        let workoutSet: WorkoutSet = try await supabase
            .from("workout_sets")
            .insert(data)
            .select()
            .single()
            .execute()
            .value
        
        return workoutSet
    }
    
    // Update a set
    func updateSet(
        id: UUID,
        reps: Int?,
        weight: Double?,
        durationSeconds: Int?,
        completed: Bool
    ) async throws {
        struct UpdateData: Encodable {
            let reps: Int?
            let weight: Double?
            let duration_seconds: Int?
            let completed: Bool
        }
        
        let data = UpdateData(
            reps: reps,
            weight: weight,
            duration_seconds: durationSeconds,
            completed: completed
        )
        
        try await supabase
            .from("workout_sets")
            .update(data)
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    // Complete a workout session
    func completeSession(id: UUID, durationSeconds: Int) async throws {
        struct UpdateData: Encodable {
            let completed_at: String
            let duration_seconds: Int
        }
        
        let data = UpdateData(
            completed_at: ISO8601DateFormatter().string(from: Date()),
            duration_seconds: durationSeconds
        )
        
        try await supabase
            .from("workout_sessions")
            .update(data)
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    // Delete a workout session
    func deleteSession(id: UUID) async throws {
        try await supabase
            .from("workout_sessions")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
        
        // Also delete from local cache
        await deleteLocalSession(id: id)
    }
    
    // Schedule a workout
    func scheduleWorkout(routineId: UUID, date: Date) async throws -> ScheduledWorkout {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        // Fetch the routine to get its name
        let routine: Routine = try await supabase
            .from("routines")
            .select()
            .eq("id", value: routineId.uuidString)
            .single()
            .execute()
            .value
        
        // First, create a workout session for this scheduled workout
        let sessionId = UUID()
        
        struct SessionInsertData: Encodable {
            let id: String
            let routine_id: String
            let started_at: String
            let name: String
        }
        
        let sessionData = SessionInsertData(
            id: sessionId.uuidString,
            routine_id: routineId.uuidString,
            started_at: ISO8601DateFormatter().string(from: Date()),
            name: routine.name
        )
        
        try await supabase
            .from("workout_sessions")
            .insert(sessionData)
            .execute()
        
        // Then create the scheduled workout linked to the session
        let scheduled: ScheduledWorkout = try await supabase
            .from("scheduled_workouts")
            .insert([
                "routine_id": routineId.uuidString,
                "scheduled_date": dateString,
                "workout_session_id": sessionId.uuidString
            ])
            .select()
            .single()
            .execute()
            .value
        
        // Post notification to refresh UI
        NotificationCenter.default.post(name: .workoutDataChanged, object: nil)
        print("📅 Scheduled workout created and notification posted")
        
        return scheduled
    }

    // Fetch scheduled workouts for a date range
    func fetchScheduledWorkouts(startDate: Date, endDate: Date) async throws -> [ScheduledWorkout] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let response: [ScheduledWorkout] = try await supabase
            .from("scheduled_workouts")
            .select()
            .gte("scheduled_date", value: formatter.string(from: startDate))
            .lte("scheduled_date", value: formatter.string(from: endDate))
            .order("scheduled_date")
            .execute()
            .value
        
        return response
    }

    // Delete scheduled workout
    func deleteScheduledWorkout(id: UUID) async throws {
        // First, fetch the scheduled workout to get the session ID
        let scheduled: ScheduledWorkout = try await supabase
            .from("scheduled_workouts")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        
        // Delete the scheduled workout
        try await supabase
            .from("scheduled_workouts")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
        
        // If there's a linked workout session, delete it too
        // (this will also delete from local cache via deleteSession)
        if let sessionId = scheduled.workoutSessionId {
            try await deleteSession(id: sessionId)
        }
        
        print("✅ Deleted scheduled workout and associated session")
    }
    
    // Delete local workout session from SwiftData
    @MainActor
    private func deleteLocalSession(id: UUID) async {
        guard let modelContext = WorkoutSyncService.shared.modelContext else {
            print("⚠️ No model context available to delete local session")
            return
        }
        
        do {
            let descriptor = FetchDescriptor<LocalWorkoutSession>(
                predicate: #Predicate<LocalWorkoutSession> { session in
                    session.id == id
                }
            )
            
            let sessions = try modelContext.fetch(descriptor)
            for session in sessions {
                print("🗑️ Deleting local session: \(session.name) (ID: \(session.id))")
                modelContext.delete(session)
            }
            
            try modelContext.save()
            
            // Post notification to refresh UI
            NotificationCenter.default.post(name: .workoutDataChanged, object: nil)
            print("📢 Posted workoutDataChanged notification")
        } catch {
            print("❌ Failed to delete local session: \(error)")
        }
    }

    // Create a completed scheduled workout entry (for non-scheduled workouts that were finished)
    func createCompletedScheduledWorkout(routineId: UUID, sessionId: UUID, date: Date) async throws {
        struct InsertData: Encodable {
            let routine_id: String
            let scheduled_date: String
            let workout_session_id: String
            let completed: Bool
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let data = InsertData(
            routine_id: routineId.uuidString,
            scheduled_date: formatter.string(from: date),
            workout_session_id: sessionId.uuidString,
            completed: true
        )
        
        try await supabase
            .from("scheduled_workouts")
            .insert(data)
            .execute()
    }
    
    // Mark all scheduled workouts for a routine as routine_deleted
    func markScheduledWorkoutsAsRoutineDeleted(routineId: UUID) async throws {
        struct UpdateData: Encodable {
            let routine_deleted: Bool
        }
        
        let data = UpdateData(routine_deleted: true)
        
        try await supabase
            .from("scheduled_workouts")
            .update(data)
            .eq("routine_id", value: routineId.uuidString)
            .execute()
    }
    
    // Mark all workout sessions for a routine as routine_deleted
    func markSessionsAsRoutineDeleted(routineId: UUID) async throws {
        struct UpdateData: Encodable {
            let routine_deleted: Bool
        }
        
        let data = UpdateData(routine_deleted: true)
        
        try await supabase
            .from("workout_sessions")
            .update(data)
            .eq("routine_id", value: routineId.uuidString)
            .execute()
    }
    
    // Mark scheduled workout as completed
    func completeScheduledWorkout(id: UUID, sessionId: UUID) async throws {
        struct UpdateData: Encodable {
            let completed: Bool
            let workout_session_id: String
        }
        
        let data = UpdateData(completed: true, workout_session_id: sessionId.uuidString)
        
        try await supabase
            .from("scheduled_workouts")
            .update(data)
            .eq("id", value: id.uuidString)
            .execute()
    }
}
