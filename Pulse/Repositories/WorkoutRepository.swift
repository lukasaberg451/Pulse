//
//  WorkoutRepository.swift
//  Pulse
//
//  Created by lukasaberg on 2/8/26.
//

import Foundation
import Supabase

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
    
    // Update a set
    func updateSet(id: UUID, reps: Int?, weight: Double?, completed: Bool) async throws {
        struct UpdateData: Encodable {
            let reps: Int?
            let weight: Double?
            let completed: Bool
        }
        
        let data = UpdateData(reps: reps, weight: weight, completed: completed)
        
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
    }
    
    // Schedule a workout
    func scheduleWorkout(routineId: UUID, date: Date) async throws -> ScheduledWorkout {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        let scheduled: ScheduledWorkout = try await supabase
            .from("scheduled_workouts")
            .insert([
                "routine_id": routineId.uuidString,
                "scheduled_date": dateString
            ])
            .select()
            .single()
            .execute()
            .value
        
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
            .lt("scheduled_date", value: formatter.string(from: endDate))
            .order("scheduled_date")
            .execute()
            .value
        
        return response
    }

    // Delete scheduled workout
    func deleteScheduledWorkout(id: UUID) async throws {
        try await supabase
            .from("scheduled_workouts")
            .delete()
            .eq("id", value: id.uuidString)
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
