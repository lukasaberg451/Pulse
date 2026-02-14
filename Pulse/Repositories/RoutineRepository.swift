//
//  RoutineRepository.swift
//  Pulse
//
//  Created by lukasaberg on 2/8/26.
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
        orderIndex: Int,
        sets: Int,
        repsTarget: String,
        restSeconds: Int
    ) async throws -> RoutineExercise {
            struct InsertData: Encodable {
                let routine_id: String
                let exercise_id: String
                let order_index: Int
                let sets: Int
                let reps_target: String
                let rest_seconds: Int
            }
            
            let data = InsertData(
                routine_id: routineId.uuidString,
                exercise_id: exerciseId.uuidString,
                order_index: orderIndex,
                sets: sets,
                reps_target: repsTarget,
                rest_seconds: restSeconds
            )
            
            let routineExercise: RoutineExercise = try await supabase
                .from("routine_exercises")
                .insert(data)
                .select()
                .single()
                .execute()
                .value
            
            return routineExercise
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
        repsTarget: String,
        restSeconds: Int
    ) async throws {
        struct UpdateData: Encodable {
            let sets: Int
            let reps_target: String
            let rest_seconds: Int
        }
        
        let data = UpdateData(
            sets: sets,
            reps_target: repsTarget,
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

    // Delete a routine exercise
    func deleteRoutineExercise(id: UUID) async throws {
        try await supabase
            .from("routine_exercises")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
    
   
