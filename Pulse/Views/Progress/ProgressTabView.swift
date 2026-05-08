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
    
    private func formattedDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }

    private func formattedDurationFull(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(mins)m"
    }

    private func formattedVolume(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
    
    private var lastWorkoutDaysAgoText: String {
        guard let days = viewModel.daysSinceLastWorkout else {
            return "—"
        }
        switch days {
        case 0: return String(localized: "Today")
        case 1: return String(localized: "Yesterday")
        default: return String(localized: "\(days) days ago")
        }
    }

    private var daysLeftInWeek: Int {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        let isoWeekday = weekday == 1 ? 7 : weekday - 1
        return 7 - isoWeekday
    }

    private var streakStatus: (left: String, right: String?, color: Color)? {
        guard let streak = viewModel.userStreak else { return nil }
        guard streak.currentStreak > 0 || streak.workoutsThisWeek > 0 else { return nil }

        if streak.weekCompleted {
            return (String(localized: "Streak secured this week!"), nil, .green)
        }

        if streak.currentStreak == 0 && streak.workoutsThisWeek == 0 {
            return nil
        }

        let workoutsNeeded = streak.workoutsRequired - streak.workoutsThisWeek
        let leftText = String(localized: "\(workoutsNeeded) more \(workoutsNeeded == 1 ? String(localized: "workout") : String(localized: "workouts")) to stay on track")

        let remaining = daysLeftInWeek
        let rightText: String
        switch remaining {
        case 0: rightText = String(localized: "Last day")
        case 1: rightText = String(localized: "Week ends in 1 day")
        default: rightText = String(localized: "Week ends in \(remaining) days")
        }

        let color: Color
        switch remaining {
        case 0: color = .red
        case 1...2: color = .yellow
        default: color = .appSecondaryText
        }

        return (leftText, rightText, color)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 14) {
                        // Smart Insight
                        if let insight = viewModel.currentInsight {
                            Text("Progress", comment: "Section header on progress tab")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color.appText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            SmartInsightCard(insight: insight)
                                .accessibilityIdentifier("smartInsightCard")
                        }
                        
                        // Activity Section
                        Text("Activity", comment: "Section header on progress tab")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.appText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)

                        // Streak Card
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                IconBadge(assetName: "flame", color: .orange, size: 36)
                                Text("\(viewModel.userStreak?.currentStreak ?? viewModel.currentStreak) \((viewModel.userStreak?.currentStreak ?? viewModel.currentStreak) == 1 ? String(localized: "week") : String(localized: "weeks")) streak")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.appText)
                                Spacer()
                                Text("\(String(localized: "Last workout:")) \(lastWorkoutDaysAgoText)")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color.appSecondaryText)
                            }
                            .padding(12)

                            if let status = streakStatus {
                                Divider().background(Color.appText.opacity(0.06))
                                HStack {
                                    Circle()
                                        .fill(status.color)
                                        .frame(width: 6, height: 6)
                                    Text(status.left)
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(status.color)
                                    Spacer()
                                    if let right = status.right {
                                        Text(right)
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(status.color)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                        }
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.appSurface)
                                .modifier(CardShadowModifier())
                        }
                        .padding(.horizontal)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("progressStreakCard")


                        Text("Last 7 days", comment: "Subheadline above stat cards")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.appSecondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)

                        // 2x2 Stats Grid
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            // Volume
                            WeeklyStatCard(
                                icon: .asset("volume"),
                                iconColor: .blue,
                                title: String(localized: "Volume"),
                                value: "\(formattedVolume(unitManager.displayWeight(Double(viewModel.weeklyVolume)))) \(unitManager.weightUnit)",
                                current: viewModel.weeklyVolume,
                                previous: viewModel.lastWeekVolume
                            )
                            .accessibilityIdentifier("progressVolumeCard")

                            // Workouts
                            WeeklyStatCard(
                                icon: .asset("strengthtraining"),
                                iconColor: .appAccent,
                                title: String(localized: "Workouts"),
                                value: "\(viewModel.weeklyWorkouts ?? 0) \((viewModel.weeklyWorkouts ?? 0) == 1 ? String(localized: "workout") : String(localized: "workouts"))",
                                current: viewModel.weeklyWorkouts ?? 0,
                                previous: viewModel.lastWeekWorkouts
                            )
                            .accessibilityIdentifier("progressWorkoutsCard")

                            // Workout Time
                            WeeklyStatCard(
                                icon: .system("clock"),
                                iconColor: .purple,
                                title: String(localized: "Workout Time"),
                                value: formattedDurationFull(viewModel.weeklyDurationMinutes),
                                current: viewModel.weeklyDurationMinutes,
                                previous: viewModel.lastWeekDurationMinutes
                            )
                            .accessibilityIdentifier("progressTimeCard")

                            // Sets
                            WeeklyStatCard(
                                icon: .system("number"),
                                iconColor: .green,
                                title: String(localized: "Sets"),
                                value: "\(viewModel.weeklySets ?? 0) \((viewModel.weeklySets ?? 0) == 1 ? String(localized: "set") : String(localized: "sets"))",
                                current: viewModel.weeklySets ?? 0,
                                previous: viewModel.lastWeekSets
                            )
                            .accessibilityIdentifier("progressSetsCard")
                        }
                        .padding(.horizontal)

                        if !subscriptionManager.isProUser {
                            VStack(spacing: 16) {
                                IconBadge(assetName: "progressup", color: .appAccent, size: 56)

                                Text("Unlock More Insights", comment: "Inline pro upgrade prompt title")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(Color.appText)

                                Text("Upgrade to Pro to access personal records, weight progress, and body metrics.", comment: "Inline pro upgrade prompt subtitle")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appSecondaryText)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)

                                PrimaryCTAButton("Upgrade to Pulse Pro", icon: "starshine") {
                                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                                    impactLight.impactOccurred()
                                    showingPaywall = true
                                }
                            }
                            .padding(.vertical, 24)
                            .padding(.horizontal)
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("progressPaywallPrompt")
                        } else {

                        // Estimated 1RM Section
                        Estimated1RMSection(viewModel: viewModel)
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("progressEstimated1RMSection")
                        
                        // Weight Progress
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Weight Progress", comment: "Section header")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(Color.appText)
                                
                                Spacer()
                                
                                if !viewModel.strengthProgress.isEmpty {
                                    NavigationLink(destination: AllStrengthProgressView(viewModel: viewModel).hidesTabBar()) {
                                        Text("See All", comment: "Navigation link")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(Color.appAccent)
                                    }
                                    .accessibilityIdentifier("strengthProgressSeeAllButton")
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
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("progressStrengthSection")
                        
                        // Body Metrics Section
                        HealthMetricsSection()
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("progressBodyMetricsSection")
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
                    if !viewModel.hasLoaded {
                        await viewModel.loadStats()
                    }
                }
            }
            .sentryScreen("Progress")
            .sheet(isPresented: $showingPaywall) {
                SubscriptionView()
                    .sheetContentTransition()
            }
        }
    }
}

// MARK: - Weekly Stat Card (2x2 Grid)

enum StatIconSource {
    case system(String)
    case asset(String)
}

struct WeeklyStatCard: View {
    let icon: StatIconSource
    let iconColor: Color
    let title: String
    let value: String
    let current: Int
    let previous: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                switch icon {
                case .system(let name):
                    IconBadge(systemName: name, color: iconColor, size: 24)
                case .asset(let name):
                    IconBadge(assetName: name, color: iconColor, size: 24)
                }
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.appSecondaryText)
            }

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.appText)

            trendIndicator
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appSurface)
                .modifier(CardShadowModifier())
        }
    }

    @ViewBuilder
    private var trendIndicator: some View {
        if let previous, previous > 0 {
            let pct = Double(current - previous) / Double(previous) * 100
            if pct > 15 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                    Text("Above your usual")
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.green)
            } else if pct < -15 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.right")
                    Text("Below your usual")
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.red.opacity(0.65))
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                    Text("About the same")
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.appSecondaryText.opacity(0.7))
            }
        } else if let previous, previous == 0, current > 0 {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.right")
                Text("Above your usual")
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(Color.green)
        } else {
            EmptyView()
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: LocalizedStringKey
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

// MARK: - Weight Progress Card
struct StrengthProgressCard: View {
    let progress: StrengthProgress
    @EnvironmentObject var unitManager: UnitManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                IconBadge(assetName: "trophy", color: .appAccent, size: 36)

                Text(progress.exerciseName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appText)

                Spacer()
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Best", comment: "Strength progress label")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.appSecondaryText)
                    Text("\(unitManager.displayWeight(progress.bestWeight), specifier: "%.1f") \(unitManager.weightUnit)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.appAccent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Start", comment: "Strength progress start label")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.appSecondaryText)
                    Text("\(unitManager.displayWeight(progress.firstWeight), specifier: "%.1f") \(unitManager.weightUnit)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.appText)
                }

                Spacer()

                if progress.improvementPercent != 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text({
                            let formatted = (abs(progress.improvementPercent) / 100).formatted(.percent.precision(.fractionLength(0)))
                            return progress.improvementPercent > 0 ? "+\(formatted)" : "-\(formatted)"
                        }())
                            .font(.caption.weight(.bold))
                            .foregroundStyle(progress.improvementPercent > 0 ? .green : .red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                (progress.improvementPercent > 0 ? Color.green : Color.red)
                                    .opacity(0.12),
                                in: Capsule()
                            )
                        Text("since start", comment: "Improvement percentage context")
                            .font(.caption2)
                            .foregroundStyle(Color.appTertiaryText)
                    }
                }
            }
            .padding(.leading, 48)
        }
        .padding(12)
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

            Text("No Strength Data Yet", comment: "Empty state title")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appText)

            Text("Complete workouts to start tracking your weight progress!", comment: "Empty state subtitle")
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
                        Text("\(abs(change)) (\((abs(changePercentage) / 100).formatted(.percent.precision(.fractionLength(0)))))")
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
                Text("Estimated 1RM", comment: "Section header")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.appText)

                Spacer()

                if !viewModel.exercise1RMStats.isEmpty {
                    NavigationLink(destination: AllEstimated1RMView(viewModel: viewModel).hidesTabBar()) {
                        Text("See All", comment: "Navigation link")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.appAccent)
                    }
                    .accessibilityIdentifier("estimated1RMSeeAllButton")
                }
            }
            .padding(.horizontal)

            if viewModel.exercise1RMStats.isEmpty {
                Empty1RMCard()
            } else {
                ForEach(viewModel.exercise1RMStats.prefix(3)) { stat in
                    Estimated1RMCard(stat: stat, timeZone: viewModel.userProfile?.resolvedTimeZone ?? .current)
                }
            }
        }
    }
}

// MARK: - Estimated 1RM Card
struct Estimated1RMCard: View {
    let stat: Exercise1RMRow
    var timeZone: TimeZone = .current
    @EnvironmentObject var unitManager: UnitManager

    private var displayLatest1rm: Double {
        unitManager.displayWeight(stat.latestEstimated1rm ?? stat.bestEstimated1rm)
    }

    private var displayLatestWeight: Double {
        unitManager.displayWeight(stat.latestWeight ?? stat.bestWeight)
    }

    private var displayLatestReps: Int {
        stat.latestReps ?? stat.bestReps
    }

    var body: some View {
        NavigationLink(destination: Exercise1RMDetailView(stat: stat, timeZone: timeZone).hidesTabBar()) {
            HStack(spacing: 12) {
                IconBadge(assetName: "crown", color: .orange, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(stat.exerciseName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appText)

                    Text("Based on \(displayLatestWeight, specifier: "%.1f") \(unitManager.weightUnit) × \(displayLatestReps) reps", comment: "1RM basis description")
                        .font(.caption)
                        .foregroundStyle(Color.appSecondaryText)
                }

                Spacer()

                Text("\(displayLatest1rm, specifier: "%.1f") \(unitManager.weightUnit)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.appAccent)

                Image("chevron-right")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .foregroundStyle(Color.appSecondaryText)
            }
            .padding(12)
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

// MARK: - Exercise 1RM Detail View
struct Exercise1RMDetailView: View {
    let stat: Exercise1RMRow
    var timeZone: TimeZone = .current
    @EnvironmentObject var unitManager: UnitManager
    @State private var history: [Exercise1RMHistoryRow] = []
    @State private var isLoading = true
    @State private var selectedEntry: Exercise1RMHistoryRow?
    @State private var animationTrigger = false

    private var displayHistory: [(date: Date, value: Double)] {
        history.map { entry in
            (date: entry.recordedAt, value: unitManager.displayWeight(entry.estimated1rm))
        }
    }

    private var movingAverageData: [(date: Date, value: Double)] {
        let data = displayHistory
        guard data.count >= 2 else { return [] }
        let window = max(3, data.count / 5)
        return data.enumerated().map { index, point in
            let start = max(0, index - window + 1)
            let slice = data[start...index]
            let avg = slice.map(\.value).reduce(0, +) / Double(slice.count)
            return (date: point.date, value: avg)
        }
    }

    private var yMin: Double {
        guard let minVal = displayHistory.map(\.value).min(),
              let maxVal = displayHistory.map(\.value).max() else { return 0 }
        let range = maxVal - minVal
        let padding = Swift.max(range * 0.15, 1)
        return (minVal - padding).rounded(.down)
    }

    private var yMax: Double {
        guard let minVal = displayHistory.map(\.value).min(),
              let maxVal = displayHistory.map(\.value).max() else { return 100 }
        let range = maxVal - minVal
        let padding = Swift.max(range * 0.15, 1)
        return (maxVal + padding).rounded(.up)
    }

    private var latest1rm: Double {
        stat.latestEstimated1rm ?? stat.bestEstimated1rm
    }

    private var latestWeight: Double {
        stat.latestWeight ?? stat.bestWeight
    }

    private var latestReps: Int {
        stat.latestReps ?? stat.bestReps
    }

    private var latestDate: Date {
        stat.latestRecordedAt ?? stat.achievedAt
    }

    private var diffFromBest: Double {
        unitManager.displayWeight(latest1rm) - unitManager.displayWeight(stat.bestEstimated1rm)
    }

    private var formattedLatestDate: String {
        let formatter = SharedFormatters.mediumDate
        formatter.timeZone = timeZone
        return formatter.string(from: latestDate)
    }

    private var trendMessage: (text: String, color: Color) {
        let ma = movingAverageData
        let gapFromBest = unitManager.displayWeight(stat.bestEstimated1rm) - unitManager.displayWeight(latest1rm)
        let gapStr = String(format: "%.1f", gapFromBest)
        let unit = unitManager.weightUnit
        let atBest = gapFromBest < 0.1

        guard ma.count >= 3 else {
            if atBest {
                return ("→ " + String(localized: "Stable (at personal best)"), Color.appSecondaryText)
            }
            return ("→ " + String(localized: "Stable (\(gapStr) \(unit) below best)"), Color.appSecondaryText)
        }

        let recent = ma.suffix(3)
        let first = recent.first!.value
        let last = recent.last!.value
        let change = last - first
        let threshold = stat.bestEstimated1rm * 0.01

        if change > threshold {
            if atBest {
                return ("↑ " + String(localized: "Improving (at personal best)"), Color.green)
            }
            return ("↑ " + String(localized: "Improving (still \(gapStr) \(unit) below best)"), Color.green)
        } else if change < -threshold {
            if atBest {
                return ("↓ " + String(localized: "Declining (at personal best)"), Color.red)
            }
            return ("↓ " + String(localized: "Declining (\(gapStr) \(unit) below best)"), Color.red)
        } else {
            if atBest {
                return ("→ " + String(localized: "Stable (at personal best)"), Color.appSecondaryText)
            }
            return ("→ " + String(localized: "Stable (\(gapStr) \(unit) below best)"), Color.appSecondaryText)
        }
    }

    var body: some View {
        ZStack {
            LinearGradient.dashboardBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        IconBadge(assetName: "crown", color: .orange, size: 48)

                        Text(stat.exerciseName)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.appText)

                        Text("Estimated 1RM: \(unitManager.displayWeight(latest1rm), specifier: "%.1f") \(unitManager.weightUnit)", comment: "Estimated 1RM value display")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)

                        if !isLoading, history.count >= 2 {
                            let trendInfo = trendMessage
                            Text(trendInfo.text)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(trendInfo.color)
                        }
                    }
                    .padding(.top, 20)
                    .opacity(animationTrigger ? 1 : 0)
                    .offset(y: animationTrigger ? 0 : 16)
                    .animation(.easeOut(duration: 0.4).delay(0.1), value: animationTrigger)

                    // Chart
                    if isLoading {
                        ProgressView()
                            .tint(Color.appAccent)
                            .frame(height: 220)
                    } else if displayHistory.count < 2 {
                        VStack(spacing: 14) {
                            IconBadge(assetName: "progressup", size: 48)

                            Text("Not enough data yet", comment: "Empty chart state")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(Color.appText)

                            Text("You need at least 2 sessions logged to see your 1RM progression chart.", comment: "Empty chart state")
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
                        VStack(alignment: .leading, spacing: 12) {
                            Text("1RM Progression (\(unitManager.weightUnit))", comment: "Chart title for 1RM progression")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.appSecondaryText)

                            chartView
                                .frame(height: 220)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedEntry = nil
                                    }
                                }

                            // X-axis date labels
                            if let first = displayHistory.first, let last = displayHistory.last {
                                HStack {
                                    Text(formatShortDate(first.date))
                                        .font(.caption2)
                                        .foregroundStyle(Color.appSecondaryText.opacity(0.6))

                                    Spacer()

                                    Text(formatShortDate(last.date))
                                        .font(.caption2)
                                        .foregroundStyle(Color.appSecondaryText.opacity(0.6))
                                }
                                .padding(.horizontal, 30)
                            }

                            // Legend
                            HStack(spacing: 16) {
                                HStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(Color.appAccent.opacity(0.25))
                                        .frame(width: 16, height: 2)
                                    Text("Session 1RM", comment: "Chart legend for session line")
                                        .font(.caption2)
                                        .foregroundStyle(Color.appSecondaryText)
                                }

                                HStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(Color.appAccent)
                                        .frame(width: 16, height: 3)
                                    Text("Trend", comment: "Chart legend for moving average line")
                                        .font(.caption2)
                                        .foregroundStyle(Color.appSecondaryText)
                                }
                            }

                            if let selected = selectedEntry {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(formatDate(selected.recordedAt))
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(Color.appSecondaryText)
                                        Text("\(unitManager.displayWeight(selected.estimated1rm), specifier: "%.1f") \(unitManager.weightUnit)")
                                            .font(.title3.weight(.bold))
                                            .foregroundStyle(Color.appText)
                                        Text("\(unitManager.displayWeight(selected.weight), specifier: "%.1f") \(unitManager.weightUnit) × \(selected.reps) reps")
                                            .font(.caption)
                                            .foregroundStyle(Color.appSecondaryText)
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
                        .opacity(animationTrigger ? 1 : 0)
                        .offset(y: animationTrigger ? 0 : 16)
                        .animation(.easeOut(duration: 0.4).delay(0.25), value: animationTrigger)
                    }

                    // Training Weights Grid
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Training Weights", comment: "Section header for training weights grid")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.appText)

                            Spacer()
                        }

                        Text("Based on your recent performance", comment: "Subtitle for training weights")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color.appSecondaryText)

                        TrainingWeightsGrid(estimated1rm: latest1rm)
                    }
                    .padding(16)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.appSurface)
                            .modifier(CardShadowModifier())
                    }
                    .padding(.horizontal)
                    .opacity(animationTrigger ? 1 : 0)
                    .offset(y: animationTrigger ? 0 : 16)
                    .animation(.easeOut(duration: 0.4).delay(0.4), value: animationTrigger)

                    Text("Estimated using the Epley formula", comment: "Note explaining the 1RM calculation method")
                        .font(.caption2)
                        .foregroundStyle(Color.appSecondaryText.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                        .opacity(animationTrigger ? 1 : 0)
                        .offset(y: animationTrigger ? 0 : 16)
                        .animation(.easeOut(duration: 0.4).delay(0.5), value: animationTrigger)

                    Spacer(minLength: 20)
                }
            }
        }
        .navigationTitle(String(localized: "Estimated 1RM"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .task {
            await loadHistory()
            withAnimation {
                animationTrigger = true
            }
        }
    }

    private func loadHistory() async {
        do {
            history = try await WorkoutRepository().fetchExercise1RMHistoryForCurrentUser(exerciseId: stat.exerciseId)
        } catch {
            debugLog("Failed to load 1RM history: \(error)")
        }
        isLoading = false
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
                    // Session line
                    smoothLinePath(for: data, width: width, height: height, range: range)
                        .stroke(Color.appAccent.opacity(0.25), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))

                    // Gradient fill
                    smoothFillPath(for: data, width: width, height: height, range: range)
                        .fill(
                            LinearGradient(
                                colors: [Color.appAccent.opacity(0.1), Color.appAccent.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // Trend line
                    let maData = movingAverageData
                    if maData.count >= 2 {
                        smoothLinePath(for: maData, width: width, height: height, range: range)
                            .stroke(Color.appAccent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    }

                    // Data points
                    ForEach(Array(data.enumerated()), id: \.offset) { index, point in
                        let x = xPosition(for: index, count: data.count, width: width)
                        let y = yPosition(for: point.value, height: height, range: range)
                        let isSelected = selectedEntry?.id == history[index].id
                        let isLatest = index == data.count - 1

                        Circle()
                            .fill(isSelected || isLatest ? Color.appAccent : Color.appSurface)
                            .frame(width: isSelected ? 10 : isLatest ? 9 : 7,
                                   height: isSelected ? 10 : isLatest ? 9 : 7)
                            .overlay {
                                Circle()
                                    .stroke(Color.appAccent, lineWidth: isLatest ? 2.5 : 2)
                            }
                            .shadow(color: isLatest ? Color.appAccent.opacity(0.4) : .clear, radius: 4)
                            .position(x: x, y: y)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if selectedEntry?.id == history[index].id {
                                        selectedEntry = nil
                                    } else {
                                        selectedEntry = history[index]
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
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }

    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }

    private func smoothLinePath(for data: [(date: Date, value: Double)], width: CGFloat, height: CGFloat, range: Double) -> Path {
        Path { path in
            let points = data.enumerated().map { index, point -> CGPoint in
                CGPoint(
                    x: xPosition(for: index, count: data.count, width: width),
                    y: yPosition(for: point.value, height: height, range: range)
                )
            }
            guard points.count >= 2 else { return }
            path.move(to: points[0])

            for i in 0..<(points.count - 1) {
                let p0 = i > 0 ? points[i - 1] : points[i]
                let p1 = points[i]
                let p2 = points[i + 1]
                let p3 = i + 2 < points.count ? points[i + 2] : points[i + 1]

                let cp1 = CGPoint(
                    x: p1.x + (p2.x - p0.x) / 6,
                    y: p1.y + (p2.y - p0.y) / 6
                )
                let cp2 = CGPoint(
                    x: p2.x - (p3.x - p1.x) / 6,
                    y: p2.y - (p3.y - p1.y) / 6
                )

                path.addCurve(to: p2, control1: cp1, control2: cp2)
            }
        }
    }

    private func smoothFillPath(for data: [(date: Date, value: Double)], width: CGFloat, height: CGFloat, range: Double) -> Path {
        var fillPath = smoothLinePath(for: data, width: width, height: height, range: range)
        fillPath.addLine(to: CGPoint(
            x: xPosition(for: data.count - 1, count: data.count, width: width),
            y: height
        ))
        fillPath.addLine(to: CGPoint(
            x: xPosition(for: 0, count: data.count, width: width),
            y: height
        ))
        fillPath.closeSubpath()
        return fillPath
    }
}

// MARK: - Empty 1RM Card
struct Empty1RMCard: View {
    var body: some View {
        VStack(spacing: 14) {
            IconBadge(assetName: "crown", size: 48)

            Text("No 1RM Data Yet", comment: "Empty state title for 1RM card")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appText)

            Text("Log strength sets with 10 or fewer reps to estimate your one rep max!", comment: "Empty state subtitle for 1RM card")
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

                            Text("No 1RM Data Yet", comment: "Empty state title for all 1RM view")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color.appText)

                            Text("Log strength sets with 10 or fewer reps to estimate your one rep max!", comment: "Empty state subtitle for all 1RM view")
                                .font(.subheadline)
                                .foregroundStyle(Color.appSecondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 100)
                    } else {
                        StaggeredList(items: viewModel.exercise1RMStats, id: \.id) { stat in
                            Estimated1RMCard(stat: stat, timeZone: viewModel.userProfile?.resolvedTimeZone ?? .current)
                        }
                    }
                }
                .padding(.vertical)
            }
            .refreshable {
                await viewModel.loadStats()
            }
        }
        .navigationTitle(String(localized: "Estimated 1RM"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
    }
}

// MARK: - All Weight Progress View
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

                            Text("No Strength Data Yet", comment: "Empty state title for all strength progress view")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color.appText)

                            Text("Complete workouts to start tracking your weight progress!", comment: "Empty state subtitle for all strength progress view")
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
        .navigationTitle(String(localized: "Weight Progress"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
    }
}
// MARK: - Body Metrics Section
struct HealthMetricsSection: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var unitManager: UnitManager
    @State private var showingHeightSheet = false
    @State private var showingWeightSheet = false
    @State private var showingTargetWeightSheet = false
    @State private var showingWeightChart = false
    @State private var showDeleteConfirmation = false

    private var hasAnyData: Bool {
        guard let profile = viewModel.profile else { return false }
        return profile.weightKg != nil || profile.heightCm != nil || (profile.targetWeightKg ?? 0) > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Body Metrics", comment: "Section header")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.appText)
                
                Spacer()
                
                if hasAnyData {
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image("trash")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                    .buttonStyle(ScalePressStyle())
                    .accessibilityIdentifier("deleteBodyMetricsButton")
                }
            }
            .padding(.horizontal)
            
            if let profile = viewModel.profile {
                VStack(spacing: 16) {
                    // Height and Weight Row (tappable)
                    HStack(spacing: 16) {
                        // Height Card
                        Button {
                            let impactLight = UIImpactFeedbackGenerator(style: .light)
                            impactLight.impactOccurred()
                            showingHeightSheet = true
                        } label: {
                            HealthMetricCard(
                                icon: "ruler",
                                title: String(localized: "Height"),
                                value: profile.heightCm != nil ? unitManager.displayHeightFormatted(profile.heightCm!) : "--",
                                unit: unitManager.unitSystem == .metric ? "cm" : "",
                                color: .green,
                                showChevron: true
                            )
                        }
                        .buttonStyle(ScalePressStyle())
                        .accessibilityIdentifier("bodyMetricsHeightButton")

                        // Weight Card
                        Button {
                            let impactLight = UIImpactFeedbackGenerator(style: .light)
                            impactLight.impactOccurred()
                            showingWeightSheet = true
                        } label: {
                            HealthMetricCard(
                                icon: "scale",
                                title: String(localized: "Weight"),
                                value: profile.weightKg != nil ? String(format: "%.1f", unitManager.displayWeight(profile.weightKg!)) : "--",
                                unit: unitManager.weightUnit,
                                color: .blue,
                                showChevron: true
                            )
                        }
                        .buttonStyle(ScalePressStyle())
                    }
                    .padding(.horizontal)
                    
                    // Weight Trend
                    if let currentWeight = profile.weightKg,
                       let startWeight = viewModel.startWeightKg,
                       startWeight > 0 {
                        
                        Button {
                            let impactLight = UIImpactFeedbackGenerator(style: .light)
                            impactLight.impactOccurred()
                            showingWeightChart = true
                        } label: {
                            VStack(spacing: 12) {
                                // Header
                                HStack(spacing: 14) {
                                    IconBadge(assetName: "scale", color: .appAccent, size: 40)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Weight Trend", comment: "Weight trend card title")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.appText)
                                        
                                        let change = currentWeight - startWeight
                                        let displayChange = abs(unitManager.displayWeight(currentWeight) - unitManager.displayWeight(startWeight))
                                        
                                        if abs(change) >= 0.1 {
                                            let arrow = change > 0 ? "↑" : "↓"
                                            Text("\(arrow) \(String(format: "%.1f", displayChange)) \(unitManager.weightUnit) since start", comment: "Weight change since start")
                                                .font(.caption)
                                                .foregroundStyle(Color.appSecondaryText)
                                        } else {
                                            Text("No change since start", comment: "No weight change label")
                                                .font(.caption)
                                                .foregroundStyle(Color.appSecondaryText)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image("chevron-right")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 12, height: 12)
                                        .foregroundStyle(Color.appSecondaryText)
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
                        .buttonStyle(ScalePressStyle())
                        
                        // Weight Goal Card
                        Button {
                            let impactLight = UIImpactFeedbackGenerator(style: .light)
                            impactLight.impactOccurred()
                            showingTargetWeightSheet = true
                        } label: {
                            HStack(spacing: 14) {
                                if let targetWeight = profile.targetWeightKg, targetWeight > 0 {
                                    let remaining = abs(currentWeight - targetWeight)
                                    let reached = remaining < 0.1

                                    IconBadge(
                                        assetName: reached ? "check-circle" : "circle-dashed",
                                        color: reached ? .green : .orange,
                                        size: 40
                                    )

                                    Text("Target: \(String(format: "%.1f", unitManager.displayWeight(targetWeight))) \(unitManager.weightUnit)", comment: "Target weight display")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.appText)

                                    Spacer()

                                    if reached {
                                        Text("Reached!", comment: "Target weight reached indicator")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.green)
                                    } else {
                                        Text("\(String(format: "%.1f", unitManager.displayWeight(remaining))) \(unitManager.weightUnit) from target", comment: "Remaining weight to target")
                                            .font(.caption)
                                            .foregroundStyle(Color.appSecondaryText)
                                    }

                                    Image("pencil")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 16, height: 16)
                                        .foregroundStyle(Color.appTertiaryText)
                                } else {
                                    IconBadge(assetName: "circle-dashed", color: .orange, size: 40)

                                    Text("Add a weight goal", comment: "Prompt to set target weight")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.appText)

                                    Spacer()

                                    Image("chevron-right")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 12, height: 12)
                                        .foregroundStyle(Color.appSecondaryText)
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
                        .buttonStyle(ScalePressStyle())
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
                            Text("BMI", comment: "Body Mass Index label")
                                .font(.caption)
                                .foregroundStyle(Color.appText.opacity(0.7))
                            
                            // Value and Category
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(String(format: "%.1f", bmi))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.appText)
                                
                                Text(profile.bmiCategoryDisplayName ?? "")
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
                                                .fill(Color.blue.opacity(0.5))
                                                .frame(width: geometry.size.width * 0.25)
                                            
                                            Rectangle()
                                                .fill(Color.green.opacity(0.5))
                                                .frame(width: geometry.size.width * 0.25)
                                            
                                            Rectangle()
                                                .fill(Color.orange.opacity(0.5))
                                                .frame(width: geometry.size.width * 0.25)
                                            
                                            Rectangle()
                                                .fill(Color.red.opacity(0.5))
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
                                    Text("Underweight", comment: "BMI category label")
                                        .font(.caption2)
                                    Spacer()
                                    Text("Normal", comment: "BMI category label")
                                        .font(.caption2)
                                    Spacer()
                                    Text("Overweight", comment: "BMI category label")
                                        .font(.caption2)
                                    Spacer()
                                    Text("Obese", comment: "BMI category label")
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

                            Text("Add your height and weight to see BMI and track your progress", comment: "Empty state for body metrics")
                                .font(.subheadline)
                                .foregroundStyle(Color.appSecondaryText)
                                .multilineTextAlignment(.center)
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
        .sheet(isPresented: $showingHeightSheet) {
            EditHeightSheet(viewModel: viewModel)
                .sheetContentTransition()
        }
        .sheet(isPresented: $showingWeightSheet) {
            EditWeightSheet(viewModel: viewModel)
                .sheetContentTransition()
        }
        .sheet(isPresented: $showingTargetWeightSheet) {
            EditTargetWeightSheet(viewModel: viewModel)
                .sheetContentTransition()
        }
        .sheet(isPresented: $showingWeightChart) {
            WeightProgressionChart(viewModel: viewModel)
                .sheetContentTransition()
        }
        .confirmationDialog(
            String(localized: "Delete Body Metrics"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete All Data"), role: .destructive) {
                Task {
                    _ = await viewModel.clearBodyMetrics()
                }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text("This will permanently delete your weight, height, target weight, and all weight history. This action cannot be undone.", comment: "Delete body metrics confirmation message")
        }
    }
    
    func categoryColor(for category: String) -> Color {
        switch category {
        case "underweight":
            return .blue
        case "normal":
            return .green
        case "overweight":
            return .orange
        case "obese":
            return .red
        default:
            return .gray
        }
    }
    
    func bmiToPosition(bmi: Double, width: CGFloat) -> CGFloat {
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
                    Image("pencil")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
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
                            
                            Text("Weight Progression", comment: "Weight progression chart title")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Color.appText)
                            
                            if let first = displayHistory.first,
                               let last = displayHistory.last,
                               displayHistory.count > 1 {
                                let change = last.weight - first.weight
                                let arrow = change >= 0 ? "↑" : "↓"
                                Text("\(arrow) \(String(format: "%.1f", abs(change))) \(unitManager.weightUnit) since start", comment: "Overall weight change summary")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appSecondaryText)
                            }
                        }
                        .padding(.top, 20)
                        
                        if displayHistory.count < 2 {
                            // Not enough data
                            VStack(spacing: 14) {
                                IconBadge(assetName: "progressup", size: 48)
                                
                                Text("Not enough data yet", comment: "Empty weight chart state title")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(Color.appText)

                                Text("Log your weight at least twice to see your progression chart.", comment: "Empty weight chart state subtitle")
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
                                Text("Weight (\(unitManager.weightUnit))", comment: "Weight chart Y-axis label")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color.appSecondaryText)
                                
                                chartView
                                    .frame(height: 220)

                                // X-axis date labels
                                if let first = displayHistory.first, let last = displayHistory.last {
                                    HStack {
                                        Text(formatShortDate(first.date))
                                            .font(.caption2)
                                            .foregroundStyle(Color.appSecondaryText.opacity(0.6))

                                        Spacer()

                                        Text(formatShortDate(last.date))
                                            .font(.caption2)
                                            .foregroundStyle(Color.appSecondaryText.opacity(0.6))
                                    }
                                    .padding(.horizontal, 30)
                                }

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
                                Text("History", comment: "Weight history list header")
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
                    Button(String(localized: "Close")) {
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
                    // Smooth line
                    smoothLinePath(for: data, width: width, height: height, range: range)
                        .stroke(Color.appAccent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    // Gradient fill
                    smoothFillPath(for: data, width: width, height: height, range: range)
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
            .contentShape(Rectangle())
            .onTapGesture {
                if selectedEntry != nil {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedEntry = nil
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
        formatter.timeZone = viewModel.profile?.resolvedTimeZone ?? .current
        return formatter.string(from: date)
    }

    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        formatter.timeZone = viewModel.profile?.resolvedTimeZone ?? .current
        return formatter.string(from: date)
    }

    private func smoothLinePath(for data: [(date: Date, weight: Double)], width: CGFloat, height: CGFloat, range: Double) -> Path {
        Path { path in
            let points = data.enumerated().map { index, point -> CGPoint in
                CGPoint(
                    x: xPosition(for: index, count: data.count, width: width),
                    y: yPosition(for: point.weight, height: height, range: range)
                )
            }
            guard points.count >= 2 else { return }
            path.move(to: points[0])

            for i in 0..<(points.count - 1) {
                let p0 = i > 0 ? points[i - 1] : points[i]
                let p1 = points[i]
                let p2 = points[i + 1]
                let p3 = i + 2 < points.count ? points[i + 2] : points[i + 1]

                let cp1 = CGPoint(
                    x: p1.x + (p2.x - p0.x) / 6,
                    y: p1.y + (p2.y - p0.y) / 6
                )
                let cp2 = CGPoint(
                    x: p2.x - (p3.x - p1.x) / 6,
                    y: p2.y - (p3.y - p1.y) / 6
                )

                path.addCurve(to: p2, control1: cp1, control2: cp2)
            }
        }
    }

    private func smoothFillPath(for data: [(date: Date, weight: Double)], width: CGFloat, height: CGFloat, range: Double) -> Path {
        var fillPath = smoothLinePath(for: data, width: width, height: height, range: range)
        fillPath.addLine(to: CGPoint(
            x: xPosition(for: data.count - 1, count: data.count, width: width),
            y: height
        ))
        fillPath.addLine(to: CGPoint(
            x: xPosition(for: 0, count: data.count, width: width),
            y: height
        ))
        fillPath.closeSubpath()
        return fillPath
    }
}

// MARK: - Edit Height Sheet
struct EditHeightSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var unitManager: UnitManager
    @ObservedObject var viewModel: ProfileViewModel

    @State private var heightText: String
    @State private var heightFeet: String
    @State private var heightInches: String
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var focusedHeight: HeightField?
    private enum HeightField { case metric, feet, inches }

    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
        let heightCm = viewModel.profile?.heightCm ?? 0
        let um = UnitManager.shared
        let heightStr = heightCm > 0 ? String(format: "%.0f", heightCm) : ""
        let feetStr: String
        let inchesStr: String
        if heightCm > 0 {
            feetStr = "\(um.feetFromCm(heightCm))"
            inchesStr = "\(um.inchesFromCm(heightCm))"
        } else {
            feetStr = ""
            inchesStr = ""
        }
        _heightText = State(initialValue: heightStr)
        _heightFeet = State(initialValue: feetStr)
        _heightInches = State(initialValue: inchesStr)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        VStack(spacing: 8) {
                            IconBadge(assetName: "ruler", color: .green, size: 48)
                            Text("Height", comment: "Edit height sheet title")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Color.appText)
                            Text(viewModel.profile?.heightCm != nil ? String(localized: "Update your height") : String(localized: "Add your height"))
                                .font(.subheadline)
                                .foregroundStyle(Color.appSecondaryText)
                        }
                        .padding(.top, 20)

                        if showError {
                            HStack(spacing: 8) {
                                Image("error")
                                    .resizable().scaledToFit()
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

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image("ruler")
                                    .foregroundStyle(Color.green)
                                    .font(.caption)
                                Text("Height", comment: "Height input field label")
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
                                        .focused($focusedHeight, equals: .metric)
                                    Text("cm")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.appSecondaryText)
                                }
                                .padding(14)
                                .contentShape(Rectangle())
                                .onTapGesture { focusedHeight = .metric }
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
                                            .focused($focusedHeight, equals: .feet)
                                        Text("ft")
                                            .font(.subheadline)
                                            .foregroundStyle(Color.appSecondaryText)
                                    }
                                    .padding(14)
                                    .contentShape(Rectangle())
                                    .onTapGesture { focusedHeight = .feet }
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
                                            .focused($focusedHeight, equals: .inches)
                                        Text("in")
                                            .font(.subheadline)
                                            .foregroundStyle(Color.appSecondaryText)
                                    }
                                    .padding(14)
                                    .contentShape(Rectangle())
                                    .onTapGesture { focusedHeight = .inches }
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
                        .padding(.horizontal)

                        PrimaryCTAButton("Save", icon: "check") {
                            let notificationFeedback = UINotificationFeedbackGenerator()
                            notificationFeedback.notificationOccurred(.success)
                            Task { await saveHeight() }
                        }
                        .disabled(viewModel.isSubmitting)
                        .opacity(viewModel.isSubmitting ? 0.5 : 1.0)
                        .padding(.horizontal)

                        Spacer()
                    }
                }

                if viewModel.isSubmitting {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView().tint(.white).scaleEffect(1.5)
                        Text("Saving...", comment: "Loading indicator while saving").foregroundStyle(.white).font(.subheadline.weight(.semibold))
                    }
                }
            }
            .sentryScreen("EditHeight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                        .foregroundStyle(Color.appText)
                }
            }
        }
        .presentationBackground(Color.appBackground)
    }

    func saveHeight() async {
        showError = false
        let heightCm: Double?
        if unitManager.unitSystem == .metric {
            let height = parseDecimal(heightText)
            if let height = height, height <= 0 {
                errorMessage = String(localized: "Height must be greater than 0")
                showError = true
                return
            }
            heightCm = height
        } else {
            let feet = Int(heightFeet) ?? 0
            let inches = Int(heightInches) ?? 0
            if feet == 0 && inches == 0 && heightFeet.isEmpty && heightInches.isEmpty {
                dismiss()
                return
            } else if feet <= 0 && inches <= 0 {
                errorMessage = String(localized: "Height must be greater than 0")
                showError = true
                return
            } else {
                heightCm = unitManager.toCmFromFeetInches(feet: feet, inches: inches)
            }
        }
        guard heightCm != nil else { dismiss(); return }
        let success = await viewModel.updateHealthMetrics(
            weightKg: nil, heightCm: heightCm, targetWeightKg: nil,
            weightChanged: false, heightChanged: true, targetWeightChanged: false
        )
        if success { dismiss() } else {
            errorMessage = viewModel.errorMessage ?? String(localized: "Failed to save height")
            showError = true
        }
    }

    private func parseDecimal(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        if let value = nf.number(from: trimmed)?.doubleValue { return value }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }
}

// MARK: - Edit Weight Sheet
struct EditWeightSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var unitManager: UnitManager
    @ObservedObject var viewModel: ProfileViewModel

    @State private var weightText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var isFieldFocused: Bool

    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
        let weightKg = viewModel.profile?.weightKg ?? 0
        let um = UnitManager.shared
        let displayWeight = um.displayWeight(weightKg)
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 1
        nf.maximumFractionDigits = 1
        let weightStr = weightKg > 0 ? (nf.string(from: NSNumber(value: displayWeight)) ?? "") : ""
        _weightText = State(initialValue: weightStr)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        VStack(spacing: 8) {
                            IconBadge(assetName: "scale", color: .blue, size: 48)
                            Text("Weight", comment: "Edit weight sheet title")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Color.appText)
                            Text("Log your current weight", comment: "Edit weight sheet subtitle")
                                .font(.subheadline)
                                .foregroundStyle(Color.appSecondaryText)
                        }
                        .padding(.top, 20)

                        if showError {
                            HStack(spacing: 8) {
                                Image("error")
                                    .resizable().scaledToFit()
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

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image("scale")
                                    .resizable().scaledToFit()
                                    .frame(width: 14, height: 14)
                                    .foregroundStyle(Color.blue)
                                Text("Weight", comment: "Weight input field label")
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
                                    .focused($isFieldFocused)
                                Text(unitManager.weightUnit)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appSecondaryText)
                            }
                            .padding(14)
                            .contentShape(Rectangle())
                            .onTapGesture { isFieldFocused = true }
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
                        .padding(.horizontal)

                        PrimaryCTAButton("Save", icon: "check") {
                            let notificationFeedback = UINotificationFeedbackGenerator()
                            notificationFeedback.notificationOccurred(.success)
                            Task { await saveWeight() }
                        }
                        .disabled(viewModel.isSubmitting)
                        .opacity(viewModel.isSubmitting ? 0.5 : 1.0)
                        .padding(.horizontal)

                        Spacer()
                    }
                }

                if viewModel.isSubmitting {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView().tint(.white).scaleEffect(1.5)
                        Text("Saving...", comment: "Loading indicator while saving").foregroundStyle(.white).font(.subheadline.weight(.semibold))
                    }
                }
            }
            .sentryScreen("EditWeight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                        .foregroundStyle(Color.appText)
                }
            }
        }
        .presentationBackground(Color.appBackground)
    }

    func saveWeight() async {
        showError = false
        let weight = parseDecimal(weightText)
        guard let weight = weight, weight > 0 else {
            errorMessage = String(localized: "Weight must be greater than 0")
            showError = true
            return
        }
        let weightKg = unitManager.toKg(weight)
        // Always save weight and log to history (even if same value as before)
        let success = await viewModel.updateHealthMetrics(
            weightKg: weightKg, heightCm: nil, targetWeightKg: nil,
            weightChanged: true, heightChanged: false, targetWeightChanged: false
        )
        if success { dismiss() } else {
            errorMessage = viewModel.errorMessage ?? String(localized: "Failed to save weight")
            showError = true
        }
    }

    private func parseDecimal(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        if let value = nf.number(from: trimmed)?.doubleValue { return value }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }
}

// MARK: - Edit Target Weight Sheet
struct EditTargetWeightSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var unitManager: UnitManager
    @ObservedObject var viewModel: ProfileViewModel

    @State private var targetWeightText: String
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var hadExistingTarget: Bool
    @FocusState private var isFieldFocused: Bool

    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
        let targetWeightKg = viewModel.profile?.targetWeightKg ?? 0
        let um = UnitManager.shared
        let displayTargetWeight = um.displayWeight(targetWeightKg)
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 1
        nf.maximumFractionDigits = 1
        let targetWeightStr = targetWeightKg > 0 ? (nf.string(from: NSNumber(value: displayTargetWeight)) ?? "") : ""
        _targetWeightText = State(initialValue: targetWeightStr)
        _hadExistingTarget = State(initialValue: targetWeightKg > 0)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        VStack(spacing: 8) {
                            IconBadge(assetName: "circle-dashed", color: .orange, size: 48)
                            Text("Weight Goal", comment: "Edit target weight sheet title")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Color.appText)
                            Text("Set your target weight", comment: "Edit target weight sheet subtitle")
                                .font(.subheadline)
                                .foregroundStyle(Color.appSecondaryText)
                        }
                        .padding(.top, 20)

                        if showError {
                            HStack(spacing: 8) {
                                Image("error")
                                    .resizable().scaledToFit()
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

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image("goal")
                                    .foregroundStyle(Color.orange)
                                    .font(.caption)
                                Text("Target Weight", comment: "Target weight input field label")
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
                                    .focused($isFieldFocused)
                                Text(unitManager.weightUnit)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appSecondaryText)
                            }
                            .padding(14)
                            .contentShape(Rectangle())
                            .onTapGesture { isFieldFocused = true }
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
                        .padding(.horizontal)

                        PrimaryCTAButton("Save", icon: "check") {
                            let notificationFeedback = UINotificationFeedbackGenerator()
                            notificationFeedback.notificationOccurred(.success)
                            Task { await saveTargetWeight() }
                        }
                        .disabled(viewModel.isSubmitting)
                        .opacity(viewModel.isSubmitting ? 0.5 : 1.0)
                        .padding(.horizontal)
                        
                        // Clear target weight option
                        if hadExistingTarget {
                            Button {
                                Task {
                                    let success = await viewModel.updateHealthMetrics(
                                        weightKg: nil, heightCm: nil, targetWeightKg: 0,
                                        weightChanged: false, heightChanged: false, targetWeightChanged: true
                                    )
                                    if success { dismiss() }
                                }
                            } label: {
                                Text("Remove Target Weight", comment: "Button to remove target weight")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.red)
                            }
                        }

                        Spacer()
                    }
                }

                if viewModel.isSubmitting {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView().tint(.white).scaleEffect(1.5)
                        Text("Saving...", comment: "Loading indicator while saving").foregroundStyle(.white).font(.subheadline.weight(.semibold))
                    }
                }
            }
            .sentryScreen("EditTargetWeight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                        .foregroundStyle(Color.appText)
                }
            }
        }
        .presentationBackground(Color.appBackground)
    }

    func saveTargetWeight() async {
        showError = false
        let targetWeight = parseDecimal(targetWeightText)
        if let targetWeight = targetWeight, targetWeight <= 0 {
            errorMessage = String(localized: "Target weight must be greater than 0")
            showError = true
            return
        }
        let targetWeightKg = targetWeight.map { unitManager.toKg($0) }
        let success = await viewModel.updateHealthMetrics(
            weightKg: nil, heightCm: nil, targetWeightKg: targetWeightKg,
            weightChanged: false, heightChanged: false, targetWeightChanged: true
        )
        if success { dismiss() } else {
            errorMessage = viewModel.errorMessage ?? String(localized: "Failed to save target weight")
            showError = true
        }
    }

    private func parseDecimal(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        if let value = nf.number(from: trimmed)?.doubleValue { return value }
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
                            Text("Completed", comment: "Workout completed status label")
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

                            Text("No Workout History Yet", comment: "Empty state title for workout history")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color.appText)

                            Text("Complete your first workout to see it here!", comment: "Empty state subtitle for workout history")
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
        .sentryScreen("CompletedWorkouts")
        .navigationTitle(String(localized: "Completed Workouts"))
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

