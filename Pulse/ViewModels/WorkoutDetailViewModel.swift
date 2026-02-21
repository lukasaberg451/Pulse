//
//  WorkoutDetailViewModel.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-21.
//

import Foundation
import Supabase
import Combine

@MainActor
class WorkoutDetailViewModel: ObservableObject {
    @Published var workoutSession: WorkoutSession
    @Published var workoutSets: [WorkoutSet] = []
    @Published var exerciseNames: [UUID: String] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseManager.shared.client
    
    init(workoutSession: WorkoutSession) {
        self.workoutSession = workoutSession
    }
    
    func loadWorkoutDetails() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch all sets for this workout
            let sets: [WorkoutSet] = try await supabase
                .from("workout_sets")
                .select()
                .eq("session_id", value: workoutSession.id.uuidString)
                .order("set_number", ascending: true)
                .execute()
                .value
            
            workoutSets = sets
            
            // Get unique exercise IDs
            let exerciseIds = Set(sets.map { $0.exerciseId })
            
            // Fetch exercise names
            for exerciseId in exerciseIds {
                if let exercise: Exercise = try? await supabase
                    .from("exercises")
                    .select("id, name")
                    .eq("id", value: exerciseId.uuidString)
                    .single()
                    .execute()
                    .value {
                    exerciseNames[exerciseId] = exercise.name
                }
            }
            
        } catch {
            errorMessage = "Failed to load workout details: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // Group sets by exercise
    var groupedSets: [(exerciseId: UUID, exerciseName: String, sets: [WorkoutSet])] {
        let grouped = Dictionary(grouping: workoutSets, by: { $0.exerciseId })
        return grouped.map { (exerciseId, sets) in
            let name = exerciseNames[exerciseId] ?? "Unknown Exercise"
            let sortedSets = sets.sorted { $0.setNumber < $1.setNumber }
            return (exerciseId, name, sortedSets)
        }.sorted { $0.exerciseName < $1.exerciseName }
    }
    
    // Calculate total volume (weight × reps)
    var totalVolume: Double {
        workoutSets.reduce(0) { total, set in
            let weight = set.weight ?? 0
            let reps = Double(set.reps ?? 0)
            return total + (weight * reps)
        }
    }
    
    // Calculate total sets
    var totalSets: Int {
        workoutSets.count
    }
    
    // Format duration
    var formattedDuration: String {
        guard let duration = workoutSession.durationSeconds else { return "N/A" }
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
