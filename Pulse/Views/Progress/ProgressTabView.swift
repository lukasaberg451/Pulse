//
//  ProgressTabView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-15.
//

import SwiftUI

struct ProgressTabView: View {
    @ObservedObject var viewModel: ProgressStatsViewModel
    @EnvironmentObject var syncService: WorkoutSyncService
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var unitManager: UnitManager
    @State private var showingPaywall = false
    @Environment(\.tabBarBottomInset) private var tabBarBottomInset
    
    private func formattedVolume(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
    
    private var lastWorkoutDateText: String {
        guard let lastSession = viewModel.recentSessions.first else {
            return "—"
        }
        let date = lastSession.completedAt ?? lastSession.startedAt
        return viewModel.formatDate(date)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground
                    .ignoresSafeArea()
                
                // Pro upgrade prompt
                if !subscriptionManager.isProUser {
                    VStack(spacing: 24) {
                        Spacer()
                        
                        IconBadge(assetName: "progressup", color: .appAccent, size: 72)
                        
                        Text("Unlock Progress Tracking")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.appText)
                        
                        Text("Upgrade to Pro to access detailed analytics, personal records, and training insights.")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        PrimaryCTAButton("Upgrade to Pulse Pro", icon: "starshine") {
                            let impactLight = UIImpactFeedbackGenerator(style: .light)
                            impactLight.impactOccurred()
                            showingPaywall = true
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                } else {
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Smart Insight
                        if let insight = viewModel.currentInsight {
                            Text("Smart Insights")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color.appText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            SmartInsightCard(insight: insight)
                        }
                        
                        // Activity Section
                        Text("Activity")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.appText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        // Streak Card
                        VStack(spacing: 16) {
                            HStack(spacing: 14) {
                                IconBadge(assetName: "flame", color: .orange, size: 44)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Current Streak")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Color.appSecondaryText)
                                    
                                    Text("\(viewModel.currentStreak) \(viewModel.currentStreak == 1 ? "day" : "days")")
                                        .font(.title2.weight(.bold))
                                        .foregroundStyle(Color.appText)
                                }
                                
                                Spacer()
                            }
                            
                            Divider()
                                .background(Color.appText.opacity(0.06))
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Longest Streak")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Color.appSecondaryText)
                                    
                                    Text("\(viewModel.bestStreak) \(viewModel.bestStreak == 1 ? "day" : "days")")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.appText)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text("Last Workout")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Color.appSecondaryText)
                                    
                                    Text(lastWorkoutDateText)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.appText)
                                }
                            }
                        }
                        .padding(16)
                        .background {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.appSurface)
                                .modifier(CardShadowModifier())
                        }
                        .padding(.horizontal)
                        
                        // Total Workouts
                        HStack(spacing: 14) {
                            IconBadge(assetName: "strengthtraining", color: .appAccent, size: 44)
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(viewModel.lifetimeWorkouts) workouts completed")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.appText)
                                
                                Text("\(viewModel.monthlyWorkouts) this month")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color.appSecondaryText)
                            }
                            
                            Spacer()
                        }
                        .padding(16)
                        .background {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.appSurface)
                                .modifier(CardShadowModifier())
                        }
                        .padding(.horizontal)
                        
                        // Volume Lifted
                        VStack(spacing: 16) {
                            HStack(spacing: 14) {
                                IconBadge(assetName: "volume", color: .blue, size: 44)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Volume Lifted")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Color.appSecondaryText)
                                    
                                    Text("This week: \(formattedVolume(unitManager.displayWeight(Double(viewModel.weeklyVolume)))) \(unitManager.weightUnit)")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.appText)
                                }
                                
                                Spacer()
                            }
                            
                            Divider()
                                .background(Color.appText.opacity(0.06))
                            
                            HStack {
                                Text("All time: \(formattedVolume(unitManager.displayWeight(Double(viewModel.lifetimeVolume)))) \(unitManager.weightUnit)")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color.appSecondaryText)
                                
                                Spacer()
                            }
                        }
                        .padding(16)
                        .background {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.appSurface)
                                .modifier(CardShadowModifier())
                        }
                        .padding(.horizontal)
                        
                        // Estimated 1RM Section
                        Estimated1RMSection(viewModel: viewModel)
                        
                        // Strength Progress
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Strength Progress")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(Color.appText)
                                
                                Spacer()
                                
                                if !viewModel.strengthProgress.isEmpty {
                                    NavigationLink(destination: AllStrengthProgressView(viewModel: viewModel).hidesTabBar()) {
                                        Text("See All")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(Color.appAccent)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            if viewModel.strengthProgress.isEmpty {
                                EmptyStrengthProgressCard()
                            } else {
                                ForEach(viewModel.strengthProgress.prefix(3)) { progress in
                                    StrengthProgressCard(progress: progress)
                                }
                            }
                        }
                        
                        // Body Metrics Section
                        HealthMetricsSection()
                    }
                    .padding(.top, 30)
                    .padding(.bottom)
                }
                .contentMargins(.bottom, tabBarBottomInset, for: .scrollContent)
                .refreshable {
                    await viewModel.loadStats()
                }
                .task {
                    // Data is loaded from HomeView.task — only reload if not yet loaded
                    // (e.g., when navigating back after a memory warning)
                    if !viewModel.hasLoaded {
                        await viewModel.loadStats()
                    }
                }
                } // end else (pro user)
            }
            .sheet(isPresented: $showingPaywall) {
                SubscriptionView()
                    .sheetContentTransition()
            }
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    var isSystemImage: Bool = true

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 10) {
            if isSystemImage {
                IconBadge(systemName: icon, color: color, size: 38)
            } else {
                IconBadge(assetName: icon, color: color, size: 38)
            }

            Text(value)
                .font(.title.weight(.bold))
                .foregroundStyle(Color.appText)

            Text(unit)
                .font(.caption)
                .foregroundStyle(Color.appSecondaryText)

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.appText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 110)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.appSurface)
                .modifier(CardShadowModifier())
        }
    }
}

// MARK: - Strength Progress Card
struct StrengthProgressCard: View {
    let progress: StrengthProgress
    @EnvironmentObject var unitManager: UnitManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                IconBadge(assetName: "trophy", color: .appAccent, size: 40)

                Text(progress.exerciseName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appText)

                Spacer()

                if progress.improvementPercent != 0 {
                    Text(progress.improvementPercent > 0
                         ? "+\(Int(progress.improvementPercent))%"
                         : "\(Int(progress.improvementPercent))%")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(progress.improvementPercent > 0 ? .green : .red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            (progress.improvementPercent > 0 ? Color.green : Color.red)
                                .opacity(0.12),
                            in: Capsule()
                        )
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Best")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.appSecondaryText)
                    Text("\(unitManager.displayWeight(progress.bestWeight), specifier: "%.1f") \(unitManager.weightUnit)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.appAccent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Last")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.appSecondaryText)
                    Text("\(unitManager.displayWeight(progress.lastWeight), specifier: "%.1f") \(unitManager.weightUnit)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.appText)
                }

                Spacer()

                if progress.improvementPercent != 0 {
                    Text("since start")
                        .font(.caption2)
                        .foregroundStyle(Color.appTertiaryText)
                }
            }
            .padding(.leading, 52)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appSurface)
                .modifier(CardShadowModifier())
        }
        .padding(.horizontal)
    }
}

struct EmptyStrengthProgressCard: View {
    var body: some View {
        VStack(spacing: 14) {
            IconBadge(assetName: "trophy", size: 48)

            Text("No Strength Data Yet")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appText)

            Text("Complete workouts to start tracking your strength progress!")
                .font(.caption)
                .foregroundStyle(Color.appSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.appSurface)
                .modifier(CardShadowModifier())
        }
        .padding(.horizontal)
    }
}

// MARK: - Comparison Row
struct ComparisonRow: View {
    let title: String
    let current: Int
    let previous: Int
    let unit: String
    
    var change: Int {
        current - previous
    }
    
    var changePercentage: Double {
        guard previous > 0 else { return 0 }
        return Double(change) / Double(previous) * 100
    }
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.appText)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(current) \(unit)")
                    .font(.headline)
                    .foregroundStyle(Color.appText)
                
                if change != 0 {
                    HStack(spacing: 4) {
                        Image(change > 0 ? "arrow-up" : "arrow-down")
                            .font(.caption)
                        Text("\(abs(change)) (\(abs(changePercentage), specifier: "%.0f")%)")
                            .font(.caption)
                    }
                    .foregroundStyle(change > 0 ? Color.green : Color.red)
                }
            }
        }
    }
}

// MARK: - Lifetime Stat Card
struct LifetimeStatCard: View {
    let title: String
    let value: String
    let icon: String
    var isSystemImage: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            if isSystemImage {
                IconBadge(systemName: icon, color: .appAccent, size: 36)
            } else {
                IconBadge(assetName: icon, color: .appAccent, size: 36)
            }

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.appText)

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.appSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.appSurface)
                .modifier(CardShadowModifier())
        }
    }
}

// MARK: - Estimated 1RM Section
struct Estimated1RMSection: View {
    @ObservedObject var viewModel: ProgressStatsViewModel
    @EnvironmentObject var unitManager: UnitManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Estimated 1RM")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.appText)

                Spacer()

                if !viewModel.exercise1RMStats.isEmpty {
                    NavigationLink(destination: AllEstimated1RMView(viewModel: viewModel).hidesTabBar()) {
                        Text("See All")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.appAccent)
                    }
                }
            }
            .padding(.horizontal)

            if viewModel.exercise1RMStats.isEmpty {
                Empty1RMCard()
            } else {
                ForEach(viewModel.exercise1RMStats.prefix(3)) { stat in
                    Estimated1RMCard(stat: stat)
                }
            }
        }
    }
}

// MARK: - Estimated 1RM Card
struct Estimated1RMCard: View {
    let stat: Exercise1RMRow
    @EnvironmentObject var unitManager: UnitManager
    @State private var showTrainingWeights = false

    private var formattedDate: String {
        SharedFormatters.mediumDate.string(from: stat.achievedAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack(spacing: 12) {
                IconBadge(assetName: "crown", color: .orange, size: 40)

                Text(stat.exerciseName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appText)

                Spacer()

                Text("\(unitManager.displayWeight(stat.bestEstimated1rm), specifier: "%.1f") \(unitManager.weightUnit)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.appAccent)
            }

            // Details row
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Based on")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.appSecondaryText)
                    Text("\(unitManager.displayWeight(stat.bestWeight), specifier: "%.1f") \(unitManager.weightUnit) × \(stat.bestReps) reps")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appText)
                }

                Spacer()

                Text(formattedDate)
                    .font(.caption2)
                    .foregroundStyle(Color.appTertiaryText)
            }
            .padding(.leading, 52)

            // Training weights toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showTrainingWeights.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Training Weights")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.appAccent)
                    Image(systemName: showTrainingWeights ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(Color.appAccent)
                }
            }
            .buttonStyle(.plain)
            .padding(.leading, 52)

            if showTrainingWeights {
                TrainingWeightsGrid(estimated1rm: stat.bestEstimated1rm)
                    .padding(.leading, 52)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appSurface)
                .modifier(CardShadowModifier())
        }
        .padding(.horizontal)
    }
}

// MARK: - Training Weights Grid
struct TrainingWeightsGrid: View {
    let estimated1rm: Double
    @EnvironmentObject var unitManager: UnitManager

    private let percentages: [(label: String, value: Double)] = [
        ("95%", 0.95),
        ("90%", 0.90),
        ("85%", 0.85),
        ("80%", 0.80),
        ("75%", 0.75),
        ("70%", 0.70)
    ]

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 8) {
            ForEach(percentages, id: \.label) { pct in
                VStack(spacing: 2) {
                    Text(pct.label)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.appSecondaryText)
                    Text("\(unitManager.displayWeight(estimated1rm * pct.value), specifier: "%.1f")")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.appText)
                    Text(unitManager.weightUnit)
                        .font(.caption2)
                        .foregroundStyle(Color.appTertiaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.appAccent.opacity(0.08))
                }
            }
        }
    }
}

// MARK: - Empty 1RM Card
struct Empty1RMCard: View {
    var body: some View {
        VStack(spacing: 14) {
            IconBadge(assetName: "crown", size: 48)

            Text("No 1RM Data Yet")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appText)

            Text("Log strength sets with 10 or fewer reps to estimate your one rep max!")
                .font(.caption)
                .foregroundStyle(Color.appSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.appSurface)
                .modifier(CardShadowModifier())
        }
        .padding(.horizontal)
    }
}

// MARK: - All Estimated 1RM View
struct AllEstimated1RMView: View {
    @ObservedObject var viewModel: ProgressStatsViewModel

    var body: some View {
        ZStack {
            LinearGradient.dashboardBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    if viewModel.exercise1RMStats.isEmpty {
                        VStack(spacing: 16) {
                            IconBadge(assetName: "crown", size: 56)

                            Text("No 1RM Data Yet")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color.appText)

                            Text("Log strength sets with 10 or fewer reps to estimate your one rep max!")
                                .font(.subheadline)
                                .foregroundStyle(Color.appSecondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 100)
                    } else {
                        StaggeredList(items: viewModel.exercise1RMStats, id: \.id) { stat in
                            Estimated1RMCard(stat: stat)
                        }
                    }
                }
                .padding(.vertical)
            }
            .refreshable {
                await viewModel.loadStats()
            }
        }
        .navigationTitle("Estimated 1RM")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
    }
}

// MARK: - All Strength Progress View
struct AllStrengthProgressView: View {
    @ObservedObject var viewModel: ProgressStatsViewModel

    var body: some View {
        ZStack {
            LinearGradient.dashboardBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    if viewModel.strengthProgress.isEmpty {
                        VStack(spacing: 16) {
                            IconBadge(assetName: "trophy", size: 56)

                            Text("No Strength Data Yet")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color.appText)

                            Text("Complete workouts to start tracking your strength progress!")
                                .font(.subheadline)
                                .foregroundStyle(Color.appSecondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 100)
                    } else {
                        StaggeredList(items: viewModel.strengthProgress, id: \.id) { progress in
                            StrengthProgressCard(progress: progress)
                        }
                    }
                }
                .padding(.vertical)
            }
            .refreshable {
                await viewModel.loadStats()
            }
        }
        .navigationTitle("Strength Progress")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
    }
}
// MARK: - Body Metrics Section
struct HealthMetricsSection: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var unitManager: UnitManager
    @State private var showingEditSheet = false
    @State private var showingWeightChart = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Body Metrics")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.appText)

                Spacer()

                Button {
                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                    impactLight.impactOccurred()
                    showingEditSheet = true
                } label: {
                    Image("edit-pencil")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(Color.appAccent)
                }
                .buttonStyle(ScalePressStyle())
            }
            .padding(.horizontal)
            
            if let profile = viewModel.profile {
                VStack(spacing: 16) {
                    // Height and Weight Row
                    HStack(spacing: 16) {
                        // Height Card
                        HealthMetricCard(
                            icon: "ruler",
                            title: "Height",
                            value: profile.heightCm != nil ? unitManager.displayHeightFormatted(profile.heightCm!) : "--",
                            unit: unitManager.unitSystem == .metric ? "cm" : "",
                            color: .green
                        )
                        
                        // Weight Card
                        Button {
                            if profile.weightKg != nil {
                                let impactLight = UIImpactFeedbackGenerator(style: .light)
                                impactLight.impactOccurred()
                                showingWeightChart = true
                            }
                        } label: {
                            HealthMetricCard(
                                icon: "scale",
                                title: "Weight",
                                value: profile.weightKg != nil ? String(format: "%.1f", unitManager.displayWeight(profile.weightKg!)) : "--",
                                unit: unitManager.weightUnit,
                                color: .blue,
                                showChevron: profile.weightKg != nil
                            )
                        }
                        .buttonStyle(ScalePressStyle())
                    }
                    .padding(.horizontal)
                    
                    // Weight Trend
                    if let currentWeight = profile.weightKg,
                       let startWeight = viewModel.startWeightKg,
                       startWeight > 0 {
                        
                        VStack(spacing: 12) {
                            // Header
                            HStack(spacing: 14) {
                                IconBadge(assetName: "scale", color: .appAccent, size: 40)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Weight Trend")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.appText)
                                    
                                    let change = currentWeight - startWeight
                                    let displayChange = abs(unitManager.displayWeight(currentWeight) - unitManager.displayWeight(startWeight))
                                    
                                    if abs(change) >= 0.1 {
                                        let arrow = change > 0 ? "↑" : "↓"
                                        Text("\(arrow) \(String(format: "%.1f", displayChange)) \(unitManager.weightUnit) since start")
                                            .font(.caption)
                                            .foregroundStyle(Color.appSecondaryText)
                                    } else {
                                        Text("No change since start")
                                            .font(.caption)
                                            .foregroundStyle(Color.appSecondaryText)
                                    }
                                }
                                
                                Spacer()
                            }
                            
                            // Target (optional)
                            if let targetWeight = profile.targetWeightKg, targetWeight > 0 {
                                Divider()
                                
                                let remaining = abs(currentWeight - targetWeight)
                                
                                HStack(spacing: 14) {
                                    IconBadge(assetName: "circle-dashed", color: .appSecondaryText, size: 40)
                                    
                                    Text("Target: \(String(format: "%.1f", unitManager.displayWeight(targetWeight))) \(unitManager.weightUnit)")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Color.appSecondaryText)
                                    
                                    Spacer()
                                    
                                    Text("\(String(format: "%.1f", unitManager.displayWeight(remaining))) \(unitManager.weightUnit) from target")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Color.appSecondaryText)
                                }
                            }
                        }
                        .padding(16)
                        .background {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.appSurface)
                                .modifier(CardShadowModifier())
                        }
                        .padding(.horizontal)
                    }
                    
                    // BMI Card
                    if let bmi = profile.bmi, let category = profile.bmiCategory {
                        VStack(alignment: .leading, spacing: 8) {
                            // Icon
                            HStack {
                                Image("clipboard-text")
                                    .font(.title2)
                                    .foregroundStyle(Color.red)
                                Spacer()
                            }
                            
                            // Title
                            Text("BMI")
                                .font(.caption)
                                .foregroundStyle(Color.appText.opacity(0.7))
                            
                            // Value and Category
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(String(format: "%.1f", bmi))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.appText)
                                
                                Text(category)
                                    .font(.caption)
                                    .foregroundStyle(categoryColor(for: category))
                                    .fontWeight(.semibold)
                            }
                            
                            // BMI Category Scale
                            VStack(spacing: 8) {
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        // Background gradient
                                        HStack(spacing: 0) {
                                            Rectangle()
                                                .fill(Color.blue.opacity(0.3))
                                                .frame(width: geometry.size.width * 0.25)
                                            
                                            Rectangle()
                                                .fill(Color.green.opacity(0.3))
                                                .frame(width: geometry.size.width * 0.25)
                                            
                                            Rectangle()
                                                .fill(Color.orange.opacity(0.3))
                                                .frame(width: geometry.size.width * 0.25)
                                            
                                            Rectangle()
                                                .fill(Color.red.opacity(0.3))
                                                .frame(width: geometry.size.width * 0.25)
                                        }
                                        .cornerRadius(12)
                                        
                                        // Indicator
                                        let position = bmiToPosition(bmi: bmi, width: geometry.size.width)
                                        Circle()
                                            .fill(categoryColor(for: category))
                                            .frame(width: 10, height: 10)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.appBackground, lineWidth: 2)
                                            )
                                            .offset(x: position - 5)
                                    }
                                }
                                .frame(height: 10)
                                
                                // Category labels
                                HStack {
                                    Text("Underweight")
                                        .font(.caption2)
                                    Spacer()
                                    Text("Normal")
                                        .font(.caption2)
                                    Spacer()
                                    Text("Overweight")
                                        .font(.caption2)
                                    Spacer()
                                    Text("Obese")
                                        .font(.caption2)
                                }
                                .foregroundStyle(Color.appText.opacity(0.5))
                            }
                            .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.appSurface)
                                .modifier(CardShadowModifier())
                        }
                        .padding(.horizontal)
                    } else if profile.weightKg == nil || profile.heightCm == nil {
                        // Empty state - prompt to add data
                        VStack(spacing: 14) {
                            IconBadge(assetName: "progressup", size: 48)

                            Text("Add your weight and height to calculate BMI")
                                .font(.subheadline)
                                .foregroundStyle(Color.appSecondaryText)
                                .multilineTextAlignment(.center)

                            PrimaryCTAButton("Add Body Metrics", icon: "plus") {
                                let impactLight = UIImpactFeedbackGenerator(style: .light)
                                impactLight.impactOccurred()
                                showingEditSheet = true
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .background {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.appSurface)
                                .modifier(CardShadowModifier())
                        }
                        .padding(.horizontal)
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .task {
            await viewModel.loadProfile()
        }
        .sheet(isPresented: $showingEditSheet) {
            EditHealthMetricsSheet(viewModel: viewModel)
                .sheetContentTransition()
        }
        .sheet(isPresented: $showingWeightChart) {
            WeightProgressionChart(viewModel: viewModel)
                .sheetContentTransition()
        }
    }
    
    func categoryColor(for category: String) -> Color {
        switch category {
        case "Underweight":
            return .blue
        case "Normal":
            return .green
        case "Overweight":
            return .orange
        case "Obese":
            return .red
        default:
            return .gray
        }
    }
    
    func bmiToPosition(bmi: Double, width: CGFloat) -> CGFloat {
        // Map BMI value to position on scale (0 to width)
        // Scale: 15 to 35 BMI range
        let minBMI = 15.0
        let maxBMI = 35.0
        let clampedBMI = max(minBMI, min(maxBMI, bmi))
        let percentage = (clampedBMI - minBMI) / (maxBMI - minBMI)
        return CGFloat(percentage) * width
    }
}

// MARK: - Health Metric Card
struct HealthMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let color: Color
    var isSystemImage: Bool = false
    var showChevron: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if isSystemImage {
                    IconBadge(systemName: icon, color: color, size: 34)
                } else {
                    IconBadge(assetName: icon, color: color, size: 34)
                }
                
                Spacer()
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appTertiaryText)
                }
            }

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.appSecondaryText)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.appText)

                Text(unit)
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryText)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.appSurface)
                .modifier(CardShadowModifier())
        }
    }
}

// MARK: - Weight Progression Chart
struct WeightProgressionChart: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var unitManager: UnitManager
    @ObservedObject var viewModel: ProfileViewModel
    
    @State private var selectedEntry: WeightHistory?
    
    private var displayHistory: [(date: Date, weight: Double)] {
        viewModel.weightHistory.map { entry in
            (date: entry.recordedAt, weight: unitManager.displayWeight(entry.weightKg))
        }
    }
    
    private var yMin: Double {
        guard let min = displayHistory.map(\.weight).min() else { return 0 }
        return (min - 2).rounded(.down)
    }
    
    private var yMax: Double {
        guard let max = displayHistory.map(\.weight).max() else { return 100 }
        return (max + 2).rounded(.up)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            IconBadge(assetName: "scale", color: .blue, size: 48)
                            
                            Text("Weight Progression")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Color.appText)
                            
                            if let first = displayHistory.first,
                               let last = displayHistory.last,
                               displayHistory.count > 1 {
                                let change = last.weight - first.weight
                                let arrow = change >= 0 ? "↑" : "↓"
                                Text("\(arrow) \(String(format: "%.1f", abs(change))) \(unitManager.weightUnit) overall")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appSecondaryText)
                            }
                        }
                        .padding(.top, 20)
                        
                        if displayHistory.count < 2 {
                            // Not enough data
                            VStack(spacing: 14) {
                                IconBadge(assetName: "progressup", size: 48)
                                
                                Text("Not enough data yet")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(Color.appText)
                                
                                Text("Log your weight at least twice to see your progression chart.")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appSecondaryText)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)
                            .background {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.appSurface)
                                    .modifier(CardShadowModifier())
                            }
                            .padding(.horizontal)
                        } else {
                            // Chart
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Weight (\(unitManager.weightUnit))")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color.appSecondaryText)
                                
                                chartView
                                    .frame(height: 220)
                                
                                // Selected point info
                                if let selected = selectedEntry {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(formatDate(selected.recordedAt))
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(Color.appSecondaryText)
                                            Text("\(String(format: "%.1f", unitManager.displayWeight(selected.weightKg))) \(unitManager.weightUnit)")
                                                .font(.title3.weight(.bold))
                                                .foregroundStyle(Color.appText)
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color.appAccent.opacity(0.1))
                                    }
                                }
                            }
                            .padding(16)
                            .background {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.appSurface)
                                    .modifier(CardShadowModifier())
                            }
                            .padding(.horizontal)
                            
                            // History list
                            VStack(alignment: .leading, spacing: 12) {
                                Text("History")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.appText)
                                    .padding(.horizontal, 4)
                                
                                ForEach(viewModel.weightHistory.reversed()) { entry in
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(Color.appAccent)
                                            .frame(width: 8, height: 8)
                                        
                                        Text(formatDate(entry.recordedAt))
                                            .font(.subheadline)
                                            .foregroundStyle(Color.appSecondaryText)
                                        
                                        Spacer()
                                        
                                        Text("\(String(format: "%.1f", unitManager.displayWeight(entry.weightKg))) \(unitManager.weightUnit)")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.appText)
                                    }
                                    .padding(.vertical, 8)
                                    
                                    if entry.id != viewModel.weightHistory.first?.id {
                                        Divider()
                                    }
                                }
                            }
                            .padding(16)
                            .background {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.appSurface)
                                    .modifier(CardShadowModifier())
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appText)
                }
            }
        }
        .presentationBackground(Color.appBackground)
        .task {
            await viewModel.loadWeightHistory()
        }
    }
    
    @ViewBuilder
    private var chartView: some View {
        let data = displayHistory
        
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let range = yMax - yMin
            
            ZStack {
                // Grid lines
                ForEach(0..<5) { i in
                    let y = height - (CGFloat(i) / 4.0) * height
                    let value = yMin + (Double(i) / 4.0) * range
                    
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(Color.appSecondaryText.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    
                    Text(String(format: "%.0f", value))
                        .font(.caption2)
                        .foregroundStyle(Color.appSecondaryText.opacity(0.6))
                        .position(x: 16, y: y - 8)
                }
                
                if data.count >= 2 {
                    // Line
                    Path { path in
                        for (index, point) in data.enumerated() {
                            let x = xPosition(for: index, count: data.count, width: width)
                            let y = yPosition(for: point.weight, height: height, range: range)
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.appAccent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    
                    // Gradient fill
                    Path { path in
                        for (index, point) in data.enumerated() {
                            let x = xPosition(for: index, count: data.count, width: width)
                            let y = yPosition(for: point.weight, height: height, range: range)
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        path.addLine(to: CGPoint(x: xPosition(for: data.count - 1, count: data.count, width: width), y: height))
                        path.addLine(to: CGPoint(x: xPosition(for: 0, count: data.count, width: width), y: height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [Color.appAccent.opacity(0.3), Color.appAccent.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Data points
                    ForEach(Array(data.enumerated()), id: \.offset) { index, point in
                        let x = xPosition(for: index, count: data.count, width: width)
                        let y = yPosition(for: point.weight, height: height, range: range)
                        let isSelected = selectedEntry?.id == viewModel.weightHistory[index].id
                        
                        Circle()
                            .fill(isSelected ? Color.appAccent : Color.appSurface)
                            .frame(width: isSelected ? 10 : 7, height: isSelected ? 10 : 7)
                            .overlay {
                                Circle()
                                    .stroke(Color.appAccent, lineWidth: 2)
                            }
                            .position(x: x, y: y)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if selectedEntry?.id == viewModel.weightHistory[index].id {
                                        selectedEntry = nil
                                    } else {
                                        selectedEntry = viewModel.weightHistory[index]
                                    }
                                }
                            }
                    }
                }
            }
        }
    }
    
    private func xPosition(for index: Int, count: Int, width: CGFloat) -> CGFloat {
        guard count > 1 else { return width / 2 }
        let padding: CGFloat = 30
        let usableWidth = width - (padding * 2)
        return padding + usableWidth * CGFloat(index) / CGFloat(count - 1)
    }
    
    private func yPosition(for value: Double, height: CGFloat, range: Double) -> CGFloat {
        guard range > 0 else { return height / 2 }
        return height - CGFloat((value - yMin) / range) * height
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Edit Body Metrics Sheet
struct EditHealthMetricsSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var unitManager: UnitManager
    @ObservedObject var viewModel: ProfileViewModel

    @State private var weightText: String
    @State private var heightText: String
    @State private var heightFeet: String
    @State private var heightInches: String
    @State private var targetWeightText: String
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDeleteConfirmation = false

    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel

        let weightKg = viewModel.profile?.weightKg ?? 0
        let heightCm = viewModel.profile?.heightCm ?? 0
        let targetWeightKg = viewModel.profile?.targetWeightKg ?? 0

        let um = UnitManager.shared
        let displayWeight = um.displayWeight(weightKg)
        let displayTargetWeight = um.displayWeight(targetWeightKg)

        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 1
        nf.maximumFractionDigits = 1

        _weightText = State(initialValue: weightKg > 0 ? (nf.string(from: NSNumber(value: displayWeight)) ?? "") : "")
        _targetWeightText = State(initialValue: targetWeightKg > 0 ? (nf.string(from: NSNumber(value: displayTargetWeight)) ?? "") : "")
        _heightText = State(initialValue: heightCm > 0 ? String(format: "%.0f", heightCm) : "")

        if heightCm > 0 {
            _heightFeet = State(initialValue: "\(um.feetFromCm(heightCm))")
            _heightInches = State(initialValue: "\(um.inchesFromCm(heightCm))")
        } else {
            _heightFeet = State(initialValue: "")
            _heightInches = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        // Header
                        VStack(spacing: 8) {
                            IconBadge(assetName: "clipboard-text", color: .red, size: 48)

                            Text("Body Metrics")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Color.appText)

                            Text("Update your body measurements")
                                .font(.subheadline)
                                .foregroundStyle(Color.appSecondaryText)
                        }
                        .padding(.top, 20)

                        // Error message
                        if showError {
                            HStack(spacing: 8) {
                                Image("error")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .foregroundStyle(.red)
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .padding(.horizontal)
                        }

                        // Form fields
                        VStack(spacing: 16) {
                            // Height Input
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image("ruler")
                                        .foregroundStyle(Color.green)
                                        .font(.caption)
                                    Text("Height")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Color.appSecondaryText)
                                }
                                .padding(.horizontal, 4)

                                if unitManager.unitSystem == .metric {
                                    HStack {
                                        TextField("0", text: $heightText)
                                            .keyboardType(.numberPad)
                                            .textFieldStyle(.plain)
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(Color.appText)

                                        Text("cm")
                                            .font(.subheadline)
                                            .foregroundStyle(Color.appSecondaryText)
                                    }
                                    .padding(14)
                                    .background {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color.appSurface)
                                            .overlay {
                                                if colorScheme == .dark {
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                                                }
                                            }
                                            .shadow(
                                                color: colorScheme == .light ? Color.black.opacity(0.04) : Color.clear,
                                                radius: 6, x: 0, y: 2
                                            )
                                    }
                                } else {
                                    HStack(spacing: 12) {
                                        HStack {
                                            TextField("0", text: $heightFeet)
                                                .keyboardType(.numberPad)
                                                .textFieldStyle(.plain)
                                                .font(.title3.weight(.semibold))
                                                .foregroundStyle(Color.appText)

                                            Text("ft")
                                                .font(.subheadline)
                                                .foregroundStyle(Color.appSecondaryText)
                                        }
                                        .padding(14)
                                        .background {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(Color.appSurface)
                                                .overlay {
                                                    if colorScheme == .dark {
                                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                                                    }
                                                }
                                        }

                                        HStack {
                                            TextField("0", text: $heightInches)
                                                .keyboardType(.numberPad)
                                                .textFieldStyle(.plain)
                                                .font(.title3.weight(.semibold))
                                                .foregroundStyle(Color.appText)

                                            Text("in")
                                                .font(.subheadline)
                                                .foregroundStyle(Color.appSecondaryText)
                                        }
                                        .padding(14)
                                        .background {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(Color.appSurface)
                                                .overlay {
                                                    if colorScheme == .dark {
                                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                                                    }
                                                }
                                        }
                                    }
                                }
                            }

                            // Weight Input
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image("scale")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 14, height: 14)
                                        .foregroundStyle(Color.blue)
                                    Text("Weight")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Color.appSecondaryText)
                                }
                                .padding(.horizontal, 4)

                                HStack {
                                    TextField("0.0", text: $weightText)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.plain)
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(Color.appText)

                                    Text(unitManager.weightUnit)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.appSecondaryText)
                                }
                                .padding(14)
                                .background {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.appSurface)
                                        .overlay {
                                            if colorScheme == .dark {
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                                            }
                                        }
                                        .shadow(
                                            color: colorScheme == .light ? Color.black.opacity(0.04) : Color.clear,
                                            radius: 6, x: 0, y: 2
                                        )
                                }
                            }
                            
                            // Target Weight Input (optional)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image("goal")
                                        .foregroundStyle(Color.orange)
                                        .font(.caption)
                                    Text("Target Weight (Optional)")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Color.appSecondaryText)
                                }
                                .padding(.horizontal, 4)

                                HStack {
                                    TextField("0.0", text: $targetWeightText)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.plain)
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(Color.appText)

                                    Text(unitManager.weightUnit)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.appSecondaryText)
                                }
                                .padding(14)
                                .background {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.appSurface)
                                        .overlay {
                                            if colorScheme == .dark {
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                                            }
                                        }
                                        .shadow(
                                            color: colorScheme == .light ? Color.black.opacity(0.04) : Color.clear,
                                            radius: 6, x: 0, y: 2
                                        )
                                }
                            }
                        }
                        .padding(.horizontal)

                        // CTA
                        PrimaryCTAButton("Save Changes", icon: "check") {
                            let notificationFeedback = UINotificationFeedbackGenerator()
                            notificationFeedback.notificationOccurred(.success)
                            Task {
                                await saveHealthMetrics()
                            }
                        }
                        .disabled(viewModel.isSubmitting)
                        .opacity(viewModel.isSubmitting ? 0.5 : 1.0)
                        .padding(.horizontal)
                        
                        // Delete Data
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                    .font(.subheadline.weight(.semibold))
                                Text("Delete Body Metrics Data")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.red.opacity(0.1))
                            }
                        }
                        .padding(.horizontal)
                        .confirmationDialog(
                            "Delete Body Metrics",
                            isPresented: $showDeleteConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button("Delete All Data", role: .destructive) {
                                Task {
                                    let success = await viewModel.clearBodyMetrics()
                                    if success {
                                        dismiss()
                                    } else {
                                        errorMessage = viewModel.errorMessage ?? "Failed to delete body metrics"
                                        showError = true
                                    }
                                }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This will permanently delete your weight, height, target weight, and all weight history. This action cannot be undone.")
                        }

                        Spacer()
                    }
                }

                // Loading overlay
                if viewModel.isSubmitting {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)

                        Text("Saving...")
                            .foregroundStyle(.white)
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appText)
                }
            }
        }
        .presentationBackground(Color.appBackground)
    }
    
    func saveHealthMetrics() async {
        showError = false
        errorMessage = ""
        
        // Validate weight
        let weight = parseDecimal(weightText)
        
        if let weight = weight, weight <= 0 {
            errorMessage = "Weight must be greater than 0"
            showError = true
            return
        }
        
        // Convert weight from display units back to metric
        let weightKg = weight.map { unitManager.toKg($0) }
        
        // Convert height based on unit system
        let heightCm: Double?
        if unitManager.unitSystem == .metric {
            let height = parseDecimal(heightText)
            if let height = height, height <= 0 {
                errorMessage = "Height must be greater than 0"
                showError = true
                return
            }
            heightCm = height
        } else {
            let feet = Int(heightFeet) ?? 0
            let inches = Int(heightInches) ?? 0
            if feet == 0 && inches == 0 && heightFeet.isEmpty && heightInches.isEmpty {
                heightCm = nil
            } else if feet <= 0 && inches <= 0 {
                errorMessage = "Height must be greater than 0"
                showError = true
                return
            } else {
                heightCm = unitManager.toCmFromFeetInches(feet: feet, inches: inches)
            }
        }
        
        // Parse target weight (optional)
        let targetWeight = parseDecimal(targetWeightText)
        let targetWeightKg = targetWeight.map { unitManager.toKg($0) }
        
        // Save to database
        let success = await viewModel.updateHealthMetrics(weightKg: weightKg, heightCm: heightCm, targetWeightKg: targetWeightKg)
        
        if success {
            dismiss()
        } else {
            errorMessage = viewModel.errorMessage ?? "Failed to save body metrics"
            showError = true
        }
    }
    
    /// Parse a decimal string accepting both comma and dot as decimal separator.
    private func parseDecimal(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        
        // First try the locale-aware NumberFormatter (handles the device's locale)
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        if let value = nf.number(from: trimmed)?.doubleValue {
            return value
        }
        
        // Fallback: replace comma with dot and parse directly
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }
}

// MARK: - Recent Workout Card
struct RecentWorkoutCard: View {
    let session: WorkoutSession
    @ObservedObject var viewModel: ProgressStatsViewModel

    var body: some View {
        NavigationLink(destination: WorkoutDetailView(workoutSession: session).hidesTabBar()) {
            HStack(spacing: 12) {
                IconBadge(
                    assetName: "workout",
                    color: .appAccent,
                    size: 40
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appText)

                    HStack(spacing: 10) {
                        HStack(spacing: 4) {
                            Image("calendar")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 12, height: 12)
                            Text(viewModel.formatDate(session.startedAt))
                        }
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)

                        if session.completedAt != nil {
                            HStack(spacing: 4) {
                                Image("clock")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 12, height: 12)
                                Text(viewModel.formatDuration(session.durationSeconds))
                            }
                                .font(.caption)
                                .foregroundStyle(Color.appSecondaryText)
                        }
                    }

                    if session.completedAt != nil {
                        HStack(spacing: 4) {
                            Image("check-circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                            Text("Completed")
                        }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                    }
                }

                Spacer()

                Image("chevron-right")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 13, height: 13)
                    .foregroundStyle(Color.appTertiaryText)
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.appSurface)
                    .modifier(CardShadowModifier())
            }
            .padding(.horizontal)
        }
        .buttonStyle(ScalePressStyle())
    }
}

// MARK: - All Recent Workouts View
struct AllRecentWorkoutsView: View {
    @StateObject private var viewModel = ProgressStatsViewModel()

    var body: some View {
        ZStack {
            LinearGradient.dashboardBackground
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.allRecentSessions.isEmpty && !viewModel.isLoadingMore {
                        VStack(spacing: 16) {
                            IconBadge(assetName: "refresh", size: 56)

                            Text("No Workout History Yet")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color.appText)

                            Text("Complete your first workout to see it here!")
                                .font(.subheadline)
                                .foregroundStyle(Color.appSecondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 100)
                    } else {
                        StaggeredList(items: viewModel.allRecentSessions, id: \.id) { session in
                            RecentWorkoutCard(
                                session: session,
                                viewModel: viewModel
                            )
                            .onAppear {
                                if session.id == viewModel.allRecentSessions.last?.id {
                                    Task {
                                        await viewModel.loadMoreSessions()
                                    }
                                }
                            }
                        }

                        if viewModel.isLoadingMore {
                            ProgressView()
                                .tint(Color.appAccent)
                                .padding()
                        }
                    }
                }
                .padding(.vertical)
            }
            .refreshable {
                await viewModel.loadRecentSessionsPaginated()
            }
        }
        .navigationTitle("Completed Workouts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .task {
            await viewModel.loadRecentSessionsPaginated()
        }
    }
}

// MARK: - Card Shadow Modifier

struct CardShadowModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .overlay {
                if colorScheme == .dark {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }
            }
            .shadow(
                color: colorScheme == .light
                    ? Color.black.opacity(0.08)
                    : Color.clear,
                radius: 16,
                x: 0,
                y: 6
            )
    }
}

