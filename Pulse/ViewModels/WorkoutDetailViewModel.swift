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
    @Published var exerciseTypes: [UUID: String] = [:]
    @Published var routineExercises: [RoutineExercise] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseManager.shared.client
    private var userProfile: Profile?
    
    var isAILogged: Bool {
        workoutSession.routineId == nil && workoutSession.routineDeleted != true
    }
    
    init(workoutSession: WorkoutSession) {
        self.workoutSession = workoutSession
    }
    
    private func fetchUserProfile() async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        do {
            let profile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            userProfile = profile
        } catch {
            debugLog("Failed to fetch user profile: \(error)")
        }
    }
    
    func formattedDate(_ date: Date) -> String {
        let formatter = SharedFormatters.mediumDate
        formatter.timeZone = userProfile?.resolvedTimeZone ?? .current
        return formatter.string(from: date)
    }
    
    func formattedTime(_ date: Date) -> String {
        let formatter = SharedFormatters.shortTime
        formatter.timeZone = userProfile?.resolvedTimeZone ?? .current
        return formatter.string(from: date)
    }
    
    func loadWorkoutDetails() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch profile and sets concurrently
            async let profileTask: Void = fetchUserProfile()
            async let setsTask: [WorkoutSet] = supabase
                .from("workout_sets")
                .select()
                .eq("session_id", value: workoutSession.id.uuidString)
                .order("set_number", ascending: true)
                .execute()
                .value
            
            let (_, sets) = try await (profileTask, setsTask)
            workoutSets = sets
            
            // Get unique exercise IDs
            let exerciseIds = Array(Set(sets.map { $0.exerciseId }))
            
            // Fetch exercises in a single query and routine exercises concurrently
            async let exercisesTask: [Exercise] = supabase
                .from("exercises")
                .select("id, name, exercise_type")
                .in("id", values: exerciseIds.map { $0.uuidString })
                .execute()
                .value
            
            if let routineId = workoutSession.routineId {
                async let routineTask: [RoutineExercise] = supabase
                    .from("routine_exercises")
                    .select()
                    .eq("routine_id", value: routineId.uuidString)
                    .execute()
                    .value
                
                let (exercises, fetched) = try await (exercisesTask, routineTask)
                for exercise in exercises {
                    exerciseNames[exercise.id] = exercise.name
                    exerciseTypes[exercise.id] = exercise.exerciseType
                }
                routineExercises = fetched
            } else {
                let exercises = try await exercisesTask
                for exercise in exercises {
                    exerciseNames[exercise.id] = exercise.name
                    exerciseTypes[exercise.id] = exercise.exerciseType
                }
            }
            
        } catch {
            errorMessage = "Failed to load workout details: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // Group sets by exercise and orderIndex to keep duplicate exercises separate
    var groupedSets: [(exerciseId: UUID, exerciseName: String, exerciseType: String?, orderIndex: Int, sets: [WorkoutSet])] {
        // Group by both exerciseId and orderIndex
        var groups: [(exerciseId: UUID, orderIndex: Int, sets: [WorkoutSet])] = []
        for set in workoutSets {
            let oi = set.orderIndex ?? Int.max
            if let idx = groups.firstIndex(where: { $0.exerciseId == set.exerciseId && $0.orderIndex == oi }) {
                groups[idx].sets.append(set)
            } else {
                groups.append((exerciseId: set.exerciseId, orderIndex: oi, sets: [set]))
            }
        }
        return groups.sorted { $0.orderIndex < $1.orderIndex }.map { group in
            let name = exerciseNames[group.exerciseId] ?? "Unknown Exercise"
            let type = exerciseTypes[group.exerciseId]
            let sortedSets = group.sets.sorted { $0.setNumber < $1.setNumber }
            return (group.exerciseId, name, type, group.orderIndex, sortedSets)
        }
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
    
    @Published var showDeleteConfirmation = false
    @Published var isDeleting = false
    
    // Delete the workout session
    func deleteWorkout() async -> Bool {
        isDeleting = true
        do {
            let repository = WorkoutRepository()
            try await repository.deleteSession(id: workoutSession.id)
            isDeleting = false
            return true
        } catch {
            errorMessage = "Failed to delete workout: \(error.localizedDescription)"
            isDeleting = false
            return false
        }
    }
    
    // Format duration (rounds to nearest minute)
    var formattedDuration: String {
        guard let duration = workoutSession.durationSeconds else { return "N/A" }
        let totalMinutes = Int(round(Double(duration) / 60.0))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}
