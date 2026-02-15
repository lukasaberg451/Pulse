//
//  ProgressStatsViewModel.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-15.
//

import Foundation
import Supabase
import Combine

struct PersonalRecord: Identifiable {
    let id = UUID()
    let exerciseName: String
    let weight: Double
    let reps: Int
    let date: Date
}

struct MuscleGroupStat {
    let name: String
    let sets: Int
    let percentage: Double
}

@MainActor
class ProgressStatsViewModel: ObservableObject {
    @Published var monthlyVolume: Int = 0
    @Published var monthlyWorkouts: Int = 0
    @Published var monthlyPRs: Int = 0
    @Published var avgDuration: Int = 0
    @Published var currentStreak: Int = 0
    
    @Published var lastMonthVolume: Int = 0
    @Published var lastMonthWorkouts: Int = 0
    @Published var lastMonthAvgDuration: Int = 0
    
    @Published var recentPRs: [PersonalRecord] = []
    @Published var topMuscleGroups: [MuscleGroupStat] = []
    
    @Published var lifetimeWorkouts: Int = 0
    @Published var lifetimeVolume: Int = 0
    @Published var lifetimeHours: Int = 0
    @Published var bestStreak: Int = 0
    
    private let supabase = SupabaseManager.shared.client
    
    func loadStats() async {
        await loadMonthlyStats()
        await loadLastMonthStats()
        await loadRecentPRs()
        await loadMuscleGroupStats()
        await loadLifetimeStats()
        await calculateStreak()
    }
    
    private func loadMonthlyStats() async {
        let calendar = Calendar.current
        let now = Date()
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return
        }
        
        do {
            guard let userId = supabase.auth.currentUser?.id else { return }
            
            // Get completed sessions this month
            let sessions: [WorkoutSession] = try await supabase
                .from("workout_sessions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("started_at", value: ISO8601DateFormatter().string(from: monthStart))
                .lt("started_at", value: ISO8601DateFormatter().string(from: monthEnd))
                .not("completed_at", operator: .is, value: "null")
                .execute()
                .value
            
            monthlyWorkouts = sessions.count
            
            // Calculate average duration
            let totalDuration = sessions.reduce(0) { $0 + ($1.durationSeconds ?? 0) }
            avgDuration = sessions.isEmpty ? 0 : (totalDuration / sessions.count) / 60
            
            // Get all sets from this month to calculate volume
            let sets: [WorkoutSet] = try await supabase
                .from("workout_sets")
                .select()
                .in("session_id", values: sessions.map { $0.id.uuidString })
                .not("weight", operator: .is, value: "null")
                .not("reps", operator: .is, value: "null")
                .execute()
                .value
            
            // Calculate total volume (weight × reps)
            monthlyVolume = sets.reduce(0) { total, set in
                let weight = set.weight ?? 0
                let reps = set.reps ?? 0
                return total + Int(weight * Double(reps))
            }
            
        } catch {
            print("Failed to load monthly stats: \(error)")
        }
    }
    
    private func loadLastMonthStats() async {
        let calendar = Calendar.current
        let now = Date()
            guard let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
            let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart) else {
                
            return
        
        
        
        
        
        }
        
        let lastMonthEnd = thisMonthStart
        
        do {
            guard let userId = supabase.auth.currentUser?.id else { return }
            
            let sessions: [WorkoutSession] = try await supabase
                .from("workout_sessions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("started_at", value: ISO8601DateFormatter().string(from: lastMonthStart))
                .lt("started_at", value: ISO8601DateFormatter().string(from: lastMonthEnd))
                .not("completed_at", operator: .is, value: "null")
                .execute()
                .value
            
            lastMonthWorkouts = sessions.count
            
            let totalDuration = sessions.reduce(0) { $0 + ($1.durationSeconds ?? 0) }
            lastMonthAvgDuration = sessions.isEmpty ? 0 : (totalDuration / sessions.count) / 60
            
            let sets: [WorkoutSet] = try await supabase
                .from("workout_sets")
                .select()
                .in("session_id", values: sessions.map { $0.id.uuidString })
                .not("weight", operator: .is, value: "null")
                .not("reps", operator: .is, value: "null")
                .execute()
                .value
            
            lastMonthVolume = sets.reduce(0) { total, set in
                let weight = set.weight ?? 0
                let reps = set.reps ?? 0
                return total + Int(weight * Double(reps))
            }
            
        } catch {
            print("Failed to load last month stats: \(error)")
        }
    }
    
    private func loadRecentPRs() async {
        // Placeholder - will implement PR tracking later
        monthlyPRs = 0
        recentPRs = []
    }
    
    private func loadMuscleGroupStats() async {
        // Placeholder - would aggregate by muscle group
        topMuscleGroups = []
    }
    
    private func loadLifetimeStats() async {
        do {
            guard let userId = supabase.auth.currentUser?.id else { return }
            
            let sessions: [WorkoutSession] = try await supabase
                .from("workout_sessions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .not("completed_at", operator: .is, value: "null")
                .execute()
                .value
            
            lifetimeWorkouts = sessions.count
            
            let totalSeconds = sessions.reduce(0) { $0 + ($1.durationSeconds ?? 0) }
            lifetimeHours = totalSeconds / 3600
            
            let sets: [WorkoutSet] = try await supabase
                .from("workout_sets")
                .select()
                .in("session_id", values: sessions.map { $0.id.uuidString })
                .not("weight", operator: .is, value: "null")
                .not("reps", operator: .is, value: "null")
                .execute()
                .value
            
            lifetimeVolume = sets.reduce(0) { total, set in
                let weight = set.weight ?? 0
                let reps = set.reps ?? 0
                return total + Int(weight * Double(reps))
            }
            
        } catch {
            print("Failed to load lifetime stats: \(error)")
        }
    }
    
    private func calculateStreak() async {
        // Calculate current workout streak
        // Placeholder implementation
        currentStreak = 0
        bestStreak = 0
    }
}
