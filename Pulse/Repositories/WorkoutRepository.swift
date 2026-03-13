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
            started_at: SharedFormatters.iso8601.string(from: startedAt)
        )
        
        try await supabase
            .from("workout_sessions")
            .insert(data)
            .execute()
    }
    
    // Fetch workout sessions with an optional limit (defaults to 100)
    func fetchSessions(limit: Int = 100) async throws -> [WorkoutSession] {
        let response: [WorkoutSession] = try await supabase
            .from("workout_sessions")
            .select()
            .order("started_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        return response
    }
    
    // Fetch completed workout sessions with pagination
    func fetchCompletedSessions(limit: Int, offset: Int) async throws -> [WorkoutSession] {
        let response: [WorkoutSession] = try await supabase
            .from("workout_sessions")
            .select()
            .not("completed_at", operator: .is, value: "null")
            .order("started_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
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
        weight: Double?,
        orderIndex: Int? = nil
    ) async throws -> WorkoutSet {
        struct InsertData: Encodable {
            let session_id: String
            let exercise_id: String
            let set_number: Int
            let reps: Int?
            let weight: Double?
            let completed: Bool
            let order_index: Int?
        }
        
        let data = InsertData(
            session_id: sessionId.uuidString,
            exercise_id: exerciseId.uuidString,
            set_number: setNumber,
            reps: reps,
            weight: weight,
            completed: false,
            order_index: orderIndex
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
        completed: Bool,
        orderIndex: Int? = nil
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
            let order_index: Int?
        }
        
        let data = InsertData(
            id: id.uuidString,
            session_id: sessionId.uuidString,
            exercise_id: exerciseId.uuidString,
            set_number: setNumber,
            reps: reps,
            weight: weight,
            duration_seconds: durationSeconds,
            completed: completed,
            order_index: orderIndex
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
            completed_at: SharedFormatters.iso8601.string(from: Date()),
            duration_seconds: durationSeconds
        )
        
        try await supabase
            .from("workout_sessions")
            .update(data)
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    // Delete a workout session and its associated scheduled workout
    func deleteSession(id: UUID) async throws {
        // Delete any scheduled workout that references this session
        try await supabase
            .from("scheduled_workouts")
            .delete()
            .eq("workout_session_id", value: id.uuidString)
            .execute()
        
        // Delete the session itself
        try await supabase
            .from("workout_sessions")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
        
        // Also delete from local cache
        await deleteLocalSession(id: id)
    }
    
    // Schedule a workout
    func scheduleWorkout(routineId: UUID, date: Date, timeZone: TimeZone = .current) async throws -> ScheduledWorkout {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timeZone
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
            started_at: SharedFormatters.iso8601.string(from: Date()),
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
        debugLog("📅 Scheduled workout created and notification posted")
        
        return scheduled
    }

    // Fetch scheduled workouts for a date range
    func fetchScheduledWorkouts(startDate: Date, endDate: Date, timeZone: TimeZone = .current) async throws -> [ScheduledWorkout] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timeZone
        
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
        
        debugLog("✅ Deleted scheduled workout and associated session")
    }
    
    // Delete local workout session from SwiftData
    @MainActor
    private func deleteLocalSession(id: UUID) async {
        guard let modelContext = WorkoutSyncService.shared.modelContext else {
            debugLog("⚠️ No model context available to delete local session")
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
                debugLog("🗑️ Deleting local session: \(session.name) (ID: \(session.id))")
                modelContext.delete(session)
            }
            
            try modelContext.save()
            
            // Post notification to refresh UI
            NotificationCenter.default.post(name: .workoutDataChanged, object: nil)
            debugLog("📢 Posted workoutDataChanged notification")
        } catch {
            debugLog("❌ Failed to delete local session: \(error)")
        }
    }

    // Create a completed scheduled workout entry (for non-scheduled workouts that were finished)
    func createCompletedScheduledWorkout(routineId: UUID, sessionId: UUID, date: Date, timeZone: TimeZone = .current) async throws {
        struct InsertData: Encodable {
            let routine_id: String
            let scheduled_date: String
            let workout_session_id: String
            let completed: Bool
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timeZone
        
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
    
    // Delete uncompleted scheduled workouts for a routine (and their linked sessions)
    func deleteUncompletedScheduledWorkouts(routineId: UUID) async throws {
        // Fetch uncompleted scheduled workouts for this routine
        let uncompleted: [ScheduledWorkout] = try await supabase
            .from("scheduled_workouts")
            .select()
            .eq("routine_id", value: routineId.uuidString)
            .eq("completed", value: false)
            .execute()
            .value
        
        for workout in uncompleted {
            // Delete the scheduled workout
            try await supabase
                .from("scheduled_workouts")
                .delete()
                .eq("id", value: workout.id.uuidString)
                .execute()
            
            // Delete the linked session if it exists
            if let sessionId = workout.workoutSessionId {
                try await supabase
                    .from("workout_sessions")
                    .delete()
                    .eq("id", value: sessionId.uuidString)
                    .execute()
                
                await deleteLocalSession(id: sessionId)
            }
        }
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
    
    // MARK: - Server-Side Aggregate RPCs
    
    /// Fetches dashboard stats (streak, weekly minutes, total count, latest PR) via server-side RPC.
    func fetchDashboardStats(
        userId: UUID,
        weekStart: Date,
        weekEnd: Date
    ) async throws -> DashboardStats {
        let stats: DashboardStats = try await supabase
            .rpc("get_dashboard_stats", params: [
                "p_user_id": userId.uuidString,
                "p_week_start": SharedFormatters.iso8601.string(from: weekStart),
                "p_week_end": SharedFormatters.iso8601.string(from: weekEnd)
            ])
            .execute()
            .value
        return stats
    }
    
    /// Fetches all progress tab stats via server-side RPC.
    func fetchProgressStats(
        userId: UUID,
        weekStart: Date,
        weekEnd: Date,
        monthStart: Date,
        monthEnd: Date,
        lastMonthStart: Date,
        lastMonthEnd: Date
    ) async throws -> ProgressStats {
        let stats: ProgressStats = try await supabase
            .rpc("get_progress_stats", params: [
                "p_user_id": userId.uuidString,
                "p_week_start": SharedFormatters.iso8601.string(from: weekStart),
                "p_week_end": SharedFormatters.iso8601.string(from: weekEnd),
                "p_month_start": SharedFormatters.iso8601.string(from: monthStart),
                "p_month_end": SharedFormatters.iso8601.string(from: monthEnd),
                "p_last_month_start": SharedFormatters.iso8601.string(from: lastMonthStart),
                "p_last_month_end": SharedFormatters.iso8601.string(from: lastMonthEnd)
            ])
            .execute()
            .value
        return stats
    }
    
    /// Fetches muscle group stats for the current month via server-side RPC.
    func fetchMuscleGroupStats(
        userId: UUID,
        monthStart: Date,
        monthEnd: Date
    ) async throws -> [MuscleGroupStatRow] {
        let rows: [MuscleGroupStatRow] = try await supabase
            .rpc("get_muscle_group_stats", params: [
                "p_user_id": userId.uuidString,
                "p_month_start": SharedFormatters.iso8601.string(from: monthStart),
                "p_month_end": SharedFormatters.iso8601.string(from: monthEnd)
            ])
            .execute()
            .value
        return rows
    }
    
    /// Fetches strength progress per exercise via server-side RPC.
    func fetchStrengthProgress(userId: UUID) async throws -> [StrengthProgressRow] {
        let rows: [StrengthProgressRow] = try await supabase
            .rpc("get_strength_progress", params: [
                "p_user_id": userId.uuidString
            ])
            .execute()
            .value
        return rows
    }
}
