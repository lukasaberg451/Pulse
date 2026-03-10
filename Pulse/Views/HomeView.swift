//
//  HomeView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/5/26.
//

import SwiftUI

// MARK: - Tab Definition

enum HomeTab: Int, CaseIterable {
    case dashboard, workout, progress, profile

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .workout:   "Workout"
        case .progress:  "Progress"
        case .profile:   "Profile"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: "DashboardTabIcon"
        case .workout:   "WorkoutTabIcon"
        case .progress:  "ProgressTabIcon"
        case .profile:   "ProfileTabIcon"
        }
    }
}

// MARK: - HomeView

struct HomeView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var syncService: WorkoutSyncService
    @State private var hasPrefetched = false
    @State private var selectedTab: HomeTab = .dashboard
    
    @StateObject private var scheduleViewModel = ScheduleViewModel()
    @StateObject private var routineListViewModel = RoutineListViewModel()
    @StateObject private var progressStatsViewModel = ProgressStatsViewModel()
    @StateObject private var milestoneViewModel = MilestoneViewModel()
    
    @State private var tabBarHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    DashboardView(
                        milestoneViewModel: milestoneViewModel,
                        authViewModel: authViewModel,
                        scheduleViewModel: scheduleViewModel,
                        routineListViewModel: routineListViewModel
                    )
                    .frame(width: geo.size.width)

                    WorkoutView(
                        scheduleViewModel: scheduleViewModel,
                        routineListViewModel: routineListViewModel
                    )
                    .frame(width: geo.size.width)

                    ProgressTabView(
                        viewModel: progressStatsViewModel,
                        milestoneViewModel: milestoneViewModel
                    )
                    .frame(width: geo.size.width)

                    ProfileView()
                        .frame(width: geo.size.width)
                }
                .offset(x: -CGFloat(selectedTab.rawValue) * geo.size.width)
                .animation(.spring(response: 0.4, dampingFraction: 0.82), value: selectedTab)
            }
            .padding(.bottom, tabBarHeight)

            HomeTabBar(selectedTab: $selectedTab)
                .background(
                    GeometryReader { geo in
                        Color.clear.onAppear { tabBarHeight = geo.size.height }
                    }
                )
        }
        .background(Color.appBackground)
        .ignoresSafeArea(.keyboard)
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
        guard !hasPrefetched else { return }
        
        print("🔄 Starting offline data prefetch...")
        syncService.modelContext = modelContext
        let repository = OfflineWorkoutRepository(modelContext: modelContext)
        
        do {
            try await repository.prefetchOfflineData()
            print("✅ Offline data ready")
        } catch {
            print("⚠️ Failed to prefetch offline data: \(error)")
        }
        
        hasPrefetched = true
    }
}

// MARK: - Custom Tab Bar

private struct HomeTabBar: View {
    @Binding var selectedTab: HomeTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(HomeTab.allCases, id: \.self) { tab in
                HomeTabButton(tab: tab, isSelected: selectedTab == tab) {
                    guard tab != selectedTab else { return }
                    selectedTab = tab
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
        .padding(.horizontal, 4)
        .background(Color.appBackground.opacity(0.95))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.appText.opacity(0.06))
                .frame(height: 0.5)
        }
    }
}

// MARK: - Tab Button with Fill/Drain Animation

private struct HomeTabButton: View {
    let tab: HomeTab
    let isSelected: Bool
    let onTap: () -> Void

    @State private var fillProgress: CGFloat = 0

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                // Icon with diagonal fill/drain mask
                Image(tab.icon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(Color.appText.opacity(0.4))
                    .overlay {
                        Image(tab.icon)
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundStyle(Color.appAccent)
                            .mask {
                                GeometryReader { geo in
                                    let w = geo.size.width
                                    let h = geo.size.height
                                    let extraW = h * 0.4
                                    let totalTravel = w + extraW
                                    let xOffset = -extraW + totalTravel * fillProgress

                                    Rectangle()
                                        .frame(width: w + extraW, height: h * 2)
                                        .rotationEffect(.degrees(-15), anchor: .bottomLeading)
                                        .offset(x: xOffset - w, y: 0)
                                }
                                .clipped()
                            }
                    }
                    .frame(height: 24)

                // Label — instant color change, no animation
                Text(tab.title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? Color.appAccent : Color.appText.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .onChange(of: isSelected) { _, selected in
            withAnimation(.easeInOut(duration: 0.35)) {
                fillProgress = selected ? 1 : 0
            }
        }
        .onAppear {
            fillProgress = isSelected ? 1 : 0
        }
    }
}
