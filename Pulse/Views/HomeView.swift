//
//  HomeView.swift
//  Pulse
//
//  Created by lukasaberg on 2/5/26.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var syncService: WorkoutSyncService
    @State private var hasPrefetched = false
    
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "chart.bar.fill") {
                DashboardView(authViewModel: authViewModel)
            }
            Tab("Workout", systemImage: "dumbbell.fill") {
                WorkoutView()
            }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") {
                ProgressTabView()
            }
            Tab("Profile", systemImage: "person.circle.fill") {
                ProfileView()
            }
        }
        .task {
            await prefetchOfflineData()
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
