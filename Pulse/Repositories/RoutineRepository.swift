//
//  RoutineRepository.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/8/26.
//

import Foundation
import Supabase

class RoutineRepository {
    private var supabase = SupabaseManager.shared.client
    
    func fetchRoutines() async throws -> [Routine] {
        let response: [Routine] = try await supabase
            .from("routines")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    func createRoutine(name: String, description: String?) async throws -> Routine {
        let routine: Routine = try await supabase
            .from("routines")
            .insert([
                "name": name,
                "description": description ?? ""
            ])
            .select()
            .single()
            .execute()
            .value
        
        return routine
    }
    
    func fetchRoutineExercises(routineId: UUID) async throws -> [RoutineExercise] {
        let response: [RoutineExercise] = try await supabase
            .from("routine_exercises")
            .select()
            .eq("routine_id", value: routineId.uuidString)
            .order("order_index")
            .execute()
            .value
        
        return response
    }
    
    func addExerciseToRoutine(
        routineId: UUID,
        exerciseId: UUID,
        sets: Int,
        repsTarget: String?,
        targetWeight: Double?,
        durationSeconds: Int?,
        restSeconds: Int,
        orderIndex: Int
    ) async throws -> RoutineExercise {
        struct NewRoutineExercise: Encodable {
            let routine_id: String
            let exercise_id: String
            let sets: Int
            let reps_target: String?
            let target_weight: Double?
            let duration_seconds: Int?
            let rest_seconds: Int
            let order_index: Int
        }
        
        let newExercise = NewRoutineExercise(
            routine_id: routineId.uuidString,
            exercise_id: exerciseId.uuidString,
            sets: sets,
            reps_target: repsTarget,
            target_weight: targetWeight,
            duration_seconds: durationSeconds,
            rest_seconds: restSeconds,
            order_index: orderIndex
        )
        
        let response: RoutineExercise = try await supabase
            .from("routine_exercises")
            .insert(newExercise)
            .select()
            .single()
            .execute()
            .value
        
        return response
    }
    
    func deleteRoutine(id: UUID) async throws {
        try await supabase
            .from("routines")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
        }
    
    func updateRoutineExercise(
        id: UUID,
        sets: Int,
        repsTarget: String?,
        targetWeight: Double?,
        durationSeconds: Int?,
        restSeconds: Int
    ) async throws {
        struct UpdateData: Encodable {
            let sets: Int
            let reps_target: String?
            let target_weight: Double?
            let duration_seconds: Int?
            let rest_seconds: Int
        }
        
        let data = UpdateData(
            sets: sets,
            reps_target: repsTarget,
            target_weight: targetWeight,
            duration_seconds: durationSeconds,
            rest_seconds: restSeconds
        )
        
        try await supabase
            .from("routine_exercises")
            .update(data)
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    func delteRoutineExercise(id: UUID) async throws {
        try await supabase
            .from("routine_exercises")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
        }
    
    // Update routine name and description
    func updateRoutine(id: UUID, name: String, description: String?) async throws {
        struct UpdateData: Encodable {
            let name: String
            let description: String
        }
        
        let data = UpdateData(
            name: name,
            description: description ?? ""
        )
        
        try await supabase
            .from("routines")
            .update(data)
            .eq("id", value: id.uuidString)
            .execute()
    }

    func deleteRoutineExercise(id: UUID) async throws {
        try await supabase
            .from("routine_exercises")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    func updateExerciseOrder(id: UUID, orderIndex: Int) async throws {
        struct UpdateOrder: Encodable {
            let order_index: Int
        }
        
        let data = UpdateOrder(order_index: orderIndex)
        
        try await supabase
            .from("routine_exercises")
            .update(data)
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    func fetchRoutine(id: UUID) async throws -> Routine {
        let supabase = SupabaseManager.shared.client
        
        let routine: Routine = try await supabase
            .from("routines")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        
        return routine
    }
}
    
   
