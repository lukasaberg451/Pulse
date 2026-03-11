//
//  ProgressTabView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-15.
//

import SwiftUI

struct ProgressTabView: View {
    @ObservedObject var viewModel: ProgressStatsViewModel
    @ObservedObject var milestoneViewModel: MilestoneViewModel
    @EnvironmentObject var syncService: WorkoutSyncService
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var unitManager: UnitManager
    @State private var showingPaywall = false
    @Environment(\.tabBarBottomInset) private var tabBarBottomInset
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground
                    .ignoresSafeArea()
                
                // Pro upgrade prompt
                if !subscriptionManager.isProUser {
                    VStack(spacing: 24) {
                        Spacer()
                        
                        IconBadge(assetName: "arrow-trending-up", color: .appAccent, size: 72)
                        
                        Text("Unlock Progress Tracking")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.appText)
                        
                        Text("Upgrade to Pro to access detailed analytics, personal records, and training insights.")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        PrimaryCTAButton("Upgrade to Pulse Pro", icon: "star") {
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
                        // Milestones
                        MilestonesSection(viewModel: milestoneViewModel)
                        
                        // Current Streak
                        HStack(spacing: 14) {
                            IconBadge(assetName: "FlameIcon", color: .orange, size: 44)
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Current Streak")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color.appSecondaryText)
                                
                                Text("\(viewModel.currentStreak) days")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(Color.appText)
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
                        
                        // Monthly Stats
                        VStack(alignment: .leading, spacing: 12) {
                            DashboardSectionHeader(title: "This Month")
                            
                            VStack(spacing: 12) {
                                StatCard(
                                    title: "Volume",
                                    value: "\(Int(unitManager.displayWeight(Double(viewModel.monthlyVolume))))",
                                    unit: unitManager.weightUnit,
                                    icon: "chart.bar.fill",
                                    color: .appAccent
                                )
                                .padding(.horizontal)
                                
                                HStack(spacing: 12) {
                                    StatCard(
                                        title: "Workouts",
                                        value: "\(viewModel.monthlyWorkouts)",
                                        unit: "sessions",
                                        icon: "figure.strengthtraining.traditional",
                                        color: .green
                                    )
                                    
                                    StatCard(
                                        title: "Avg Duration",
                                        value: "\(viewModel.avgDuration)",
                                        unit: "min",
                                        icon: "timer",
                                        color: .blue
                                    )
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Health Metrics Section
                        HealthMetricsSection()
                        
                        // Personal Records
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Personal Records")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(Color.appText)
                                
                                Spacer()
                                
                                NavigationLink(destination: AllPRsView().hidesTabBar()) {
                                    Text("See All")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                            .padding(.horizontal)
                            
                            if viewModel.recentPRs.isEmpty {
                                EmptyPRCard()
                            } else {
                                ForEach(viewModel.recentPRs.prefix(3)) { pr in
                                    PRCard(pr: pr, formattedDate: viewModel.formatDate(pr.date))
                                }
                            }
                        }
                        
                        // Most Trained Muscles
                        VStack(alignment: .leading, spacing: 12) {
                            DashboardSectionHeader(title: "Most Trained")
                            
                            VStack(spacing: 8) {
                                if viewModel.topMuscleGroups.isEmpty {
                                    EmptyMuscleGroupRow()
                                } else {
                                    ForEach(viewModel.topMuscleGroups, id: \.name) { muscle in
                                        MuscleGroupRow(
                                            name: muscle.name,
                                            sets: muscle.sets,
                                            percentage: muscle.percentage
                                        )
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
                        
                        // Lifetime Stats
                        VStack(alignment: .leading, spacing: 12) {
                            DashboardSectionHeader(title: "Lifetime Stats")
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                LifetimeStatCard(
                                    title: "Total Workouts",
                                    value: "\(viewModel.lifetimeWorkouts)",
                                    icon: "figure.run",
                                    isSystemImage: true
                                )
                                
                                LifetimeStatCard(
                                    title: "Total Volume",
                                    value: "\(Int(unitManager.displayWeight(Double(viewModel.lifetimeVolume))))\(unitManager.weightUnit)",
                                    icon: "scale"
                                )
                                
                                LifetimeStatCard(
                                    title: "Time Trained",
                                    value: "\(viewModel.lifetimeHours)h",
                                    icon: "clock"
                                )
                                
                                LifetimeStatCard(
                                    title: "Best Streak",
                                    value: "\(viewModel.bestStreak) days",
                                    icon: "FlameIcon"
                                )
                            }
                            .padding(.horizontal)
                        }
                        
                        // Recent Workouts
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Recent Workouts")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(Color.appText)
                                
                                Spacer()
                                
                                if !viewModel.recentSessions.isEmpty {
                                    NavigationLink(destination: AllRecentWorkoutsView().hidesTabBar()) {
                                        Text("See All")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(Color.appAccent)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            if viewModel.recentSessions.isEmpty {
                                VStack(spacing: 14) {
                                    IconBadge(systemName: "clock.arrow.circlepath", size: 48)
                                    
                                    Text("No workout history yet")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.appText)
                                    
                                    Text("Complete your first workout to see it here")
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
                            } else {
                                ForEach(viewModel.recentSessions.prefix(3)) { session in
                                    RecentWorkoutCard(
                                        session: session,
                                        viewModel: viewModel
                                    )
                                }
                            }
                        }
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

// MARK: - PR Card
struct PRCard: View {
    let pr: PersonalRecord
    let formattedDate: String
    @EnvironmentObject var unitManager: UnitManager

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(assetName: "trophy", color: .yellow, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(pr.exerciseName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appText)

                Text("\(unitManager.displayWeight(pr.weight), specifier: "%.1f")\(unitManager.weightUnit) × \(pr.reps) reps")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.appAccent)

                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(Color.appTertiaryText)
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
}

struct EmptyPRCard: View {
    var body: some View {
        VStack(spacing: 14) {
            IconBadge(assetName: "trophy", size: 48)

            Text("No PRs Yet")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appText)

            Text("Complete workouts to set your first personal record!")
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
                        Image(systemName: change > 0 ? "arrow.up" : "arrow.down")
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

// MARK: - Most Trained
struct MuscleGroupRow: View {
    let name: String
    let sets: Int
    let percentage: Double

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.appText)

                Spacer()

                Text("\(sets) sets")
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryText)
            }

            PremiumProgressBar(progress: percentage, height: 8)
        }
    }
}

struct EmptyMuscleGroupRow: View {
    var body: some View {
        VStack(spacing: 14) {
            IconBadge(systemName: "clock.arrow.circlepath", size: 48)

            Text("No history yet")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appText)

            Text("Complete your first workout to see data")
                .font(.caption)
                .foregroundStyle(Color.appSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
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

// MARK: - All PR Card
struct AllPRsView: View {
    @StateObject private var viewModel = ProgressStatsViewModel()

    var body: some View {
        ZStack {
            LinearGradient.dashboardBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    if viewModel.recentPRs.isEmpty {
                        VStack(spacing: 16) {
                            IconBadge(assetName: "trophy", size: 56)

                            Text("No Personal Records Yet")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color.appText)

                            Text("Complete workouts to set your first personal record!")
                                .font(.subheadline)
                                .foregroundStyle(Color.appSecondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 100)
                    } else {
                        ForEach(viewModel.recentPRs) { pr in
                            PRCard(pr: pr, formattedDate: viewModel.formatDate(pr.date))
                        }
                    }
                }
                .padding(.vertical)
            }
            .refreshable {
                await viewModel.loadStats()
            }
        }
        .navigationTitle("Personal Records")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .task {
            await viewModel.loadStats()
        }
    }
}
// MARK: - Health Metrics Section
struct HealthMetricsSection: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var unitManager: UnitManager
    @State private var showingEditSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Health Metrics")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.appText)

                Spacer()

                Button {
                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                    impactLight.impactOccurred()
                    showingEditSheet = true
                } label: {
                    Image("pencil-square")
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
                    // Weight and Height Row
                    HStack(spacing: 16) {
                        // Weight Card
                        HealthMetricCard(
                            icon: "scale",
                            title: "Weight",
                            value: profile.weightKg != nil ? String(format: "%.1f", unitManager.displayWeight(profile.weightKg!)) : "--",
                            unit: unitManager.weightUnit,
                            color: .blue
                        )
                        
                        // Height Card
                        HealthMetricCard(
                            icon: "ruler.fill",
                            title: "Height",
                            value: profile.heightCm != nil ? unitManager.displayHeightFormatted(profile.heightCm!) : "--",
                            unit: unitManager.unitSystem == .metric ? "cm" : "",
                            color: .green,
                            isSystemImage: true
                        )
                    }
                    .padding(.horizontal)
                    
                    // BMI Card
                    if let bmi = profile.bmi, let category = profile.bmiCategory {
                        VStack(alignment: .leading, spacing: 8) {
                            // Icon
                            HStack {
                                Image(systemName: "heart.text.square.fill")
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
                            IconBadge(assetName: "arrow-trending-up", size: 48)

                            Text("Add your weight and height to calculate BMI")
                                .font(.subheadline)
                                .foregroundStyle(Color.appSecondaryText)
                                .multilineTextAlignment(.center)

                            PrimaryCTAButton("Add Health Metrics", icon: "plus") {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isSystemImage {
                IconBadge(systemName: icon, color: color, size: 34)
            } else {
                IconBadge(assetName: icon, color: color, size: 34)
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

// MARK: - Edit Health Metrics Sheet
struct EditHealthMetricsSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var unitManager: UnitManager
    @ObservedObject var viewModel: ProfileViewModel

    @State private var weightText: String
    @State private var heightText: String
    @State private var heightFeet: String
    @State private var heightInches: String
    @State private var showError = false
    @State private var errorMessage = ""

    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel

        let weightKg = viewModel.profile?.weightKg ?? 0
        let heightCm = viewModel.profile?.heightCm ?? 0

        let um = UnitManager.shared
        let displayWeight = um.displayWeight(weightKg)

        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 1
        nf.maximumFractionDigits = 1

        _weightText = State(initialValue: weightKg > 0 ? (nf.string(from: NSNumber(value: displayWeight)) ?? "") : "")
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
                            IconBadge(systemName: "heart.text.square.fill", color: .red, size: 48)

                            Text("Health Metrics")
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
                                Image("exclamation-triangle")
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

                            // Height Input
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "ruler.fill")
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
        
        // Save to database
        let success = await viewModel.updateHealthMetrics(weightKg: weightKg, heightCm: heightCm)
        
        if success {
            dismiss()
        } else {
            errorMessage = viewModel.errorMessage ?? "Failed to save health metrics"
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
                    systemName: "figure.strengthtraining.traditional",
                    color: .appAccent,
                    size: 40
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appText)

                    HStack(spacing: 10) {
                        HStack(spacing: 4) {
                            Image("calendar-days")
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
                            IconBadge(systemName: "clock.arrow.circlepath", size: 56)

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
                        ForEach(viewModel.allRecentSessions) { session in
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
        .navigationTitle("All Workouts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .task {
            await viewModel.loadRecentSessionsPaginated()
        }
    }
}

// MARK: - Card Shadow Modifier

private struct CardShadowModifier: ViewModifier {
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

