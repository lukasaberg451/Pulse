//
//  HomeView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/5/26.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var syncService: WorkoutSyncService
    @State private var hasPrefetched = false
    
    @StateObject private var scheduleViewModel = ScheduleViewModel()
    @StateObject private var routineListViewModel = RoutineListViewModel()
    @StateObject private var progressStatsViewModel = ProgressStatsViewModel()
    @StateObject private var milestoneViewModel = MilestoneViewModel()
    
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "chart.bar.fill") {
                DashboardView(
                    milestoneViewModel: milestoneViewModel,
                    authViewModel: authViewModel,
                    scheduleViewModel: scheduleViewModel,
                    routineListViewModel: routineListViewModel
                )
            }
            Tab("Workout", systemImage: "dumbbell.fill") {
                WorkoutView(
                    scheduleViewModel: scheduleViewModel,
                    routineListViewModel: routineListViewModel
                )
            }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") {
                ProgressTabView(
                    viewModel: progressStatsViewModel,
                    milestoneViewModel: milestoneViewModel
                )
            }
            Tab("Profile", systemImage: "person.circle.fill") {
                ProfileView()
            }
        }
        .task {
            routineListViewModel.modelContext = modelContext
            async let routines: Void = routineListViewModel.loadRoutines()
            async let schedule: Void = scheduleViewModel.loadData()
            async let progress: Void = progressStatsViewModel.loadStats()
            async let milestones: Void = milestoneViewModel.loadMilestones()
            async let offline: Void = prefetchOfflineData()
            _ = await (routines, schedule, progress, milestones, offline)
        }
    }
    
    private func prefetchOfflineData() async {
        // Only prefetch once per session
        guard !hasPrefetched else { return }
        
        print("🔄 Starting offline data prefetch...")
        
        // Set up sync service with model context
        syncService.modelContext = modelContext
        
        // Create offline repository
        let repository = OfflineWorkoutRepository(modelContext: modelContext)
        
        // Prefetch all data for offline use
        do {
            try await repository.prefetchOfflineData()
            print("✅ Offline data ready")
        } catch {
            print("⚠️ Failed to prefetch offline data: \(error)")
            // Continue anyway - user might be offline or data might already be cached
        }
        
        hasPrefetched = true
    }
}
