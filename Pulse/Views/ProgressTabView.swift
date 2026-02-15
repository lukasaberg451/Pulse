//
//  ProgressTabView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-15.
//

import SwiftUI

struct ProgressTabView: View {
    @StateObject private var viewModel = ProgressStatsViewModel()
    
    var body: some View {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Swipeable stat cards
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                StatCard(
                                    title: "Volume This Month",
                                    value: "\(viewModel.monthlyVolume)",
                                    unit: "kg",
                                    icon: "chart.bar.fill",
                                    color: .appAccent
                                )
                                
                                StatCard(
                                    title: "Workouts",
                                    value: "\(viewModel.monthlyWorkouts)",
                                    unit: "sessions",
                                    icon: "figure.strengthtraining.traditional",
                                    color: .green
                                )
                                
                                StatCard(
                                    title: "New PRs",
                                    value: "\(viewModel.monthlyPRs)",
                                    unit: "records",
                                    icon: "trophy.fill",
                                    color: .yellow
                                )
                                
                                StatCard(
                                    title: "Avg Duration",
                                    value: "\(viewModel.avgDuration)",
                                    unit: "min",
                                    icon: "timer",
                                    color: .blue
                                )
                                
                                StatCard(
                                    title: "Current Streak",
                                    value: "\(viewModel.currentStreak)",
                                    unit: "days",
                                    icon: "flame.fill",
                                    color: .orange
                                )
                            }
                            .padding(.horizontal)
                        }
                        
                        // Personal Records
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Personal Records")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.appText)
                                
                                Spacer()
                                
                                NavigationLink(destination: AllPRsView()) {
                                    Text("See All")
                                        .font(.subheadline)
                                        .foregroundColor(.appAccent)
                                }
                            }
                            .padding(.horizontal)
                            
                            if viewModel.recentPRs.isEmpty {
                                EmptyPRCard()
                            } else {
                                ForEach(viewModel.recentPRs.prefix(3)) { pr in
                                    PRCard(pr: pr)
                                }
                            }
                        }
                        
                        // This Month Summary
                        VStack(alignment: .leading, spacing: 12) {
                            Text("This Month")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.appText)
                                .padding(.horizontal)
                            
                            VStack(spacing: 16) {
                                // Volume comparison
                                ComparisonRow(
                                    title: "Total Volume",
                                    current: viewModel.monthlyVolume,
                                    previous: viewModel.lastMonthVolume,
                                    unit: "kg"
                                )
                                
                                Divider()
                                    .background(Color.appText.opacity(0.2))
                                
                                // Workout count comparison
                                ComparisonRow(
                                    title: "Workouts",
                                    current: viewModel.monthlyWorkouts,
                                    previous: viewModel.lastMonthWorkouts,
                                    unit: "sessions"
                                )
                                
                                Divider()
                                    .background(Color.appText.opacity(0.2))
                                
                                // Average duration
                                ComparisonRow(
                                    title: "Avg Duration",
                                    current: viewModel.avgDuration,
                                    previous: viewModel.lastMonthAvgDuration,
                                    unit: "min"
                                )
                            }
                            .padding()
                            .background(Color.appSurface)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        
                        // Most Trained Muscles
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Most Trained")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.appText)
                                .padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                ForEach(viewModel.topMuscleGroups, id: \.name) { muscle in
                                    MuscleGroupRow(
                                        name: muscle.name,
                                        sets: muscle.sets,
                                        percentage: muscle.percentage
                                    )
                                }
                            }
                            .padding()
                            .background(Color.appSurface)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        
                        // Lifetime Stats
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Lifetime Stats")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.appText)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                LifetimeStatCard(
                                    title: "Total Workouts",
                                    value: "\(viewModel.lifetimeWorkouts)",
                                    icon: "figure.run"
                                )
                                
                                LifetimeStatCard(
                                    title: "Total Volume",
                                    value: "\(viewModel.lifetimeVolume)kg",
                                    icon: "scalemass"
                                )
                                
                                LifetimeStatCard(
                                    title: "Time Trained",
                                    value: "\(viewModel.lifetimeHours)h",
                                    icon: "clock"
                                )
                                
                                LifetimeStatCard(
                                    title: "Best Streak",
                                    value: "\(viewModel.bestStreak) days",
                                    icon: "flame"
                                )
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    await viewModel.loadStats()
                }
            }
            .task {
                await viewModel.loadStats()
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
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.appText)
            
            Text(unit)
                .font(.caption)
                .foregroundColor(.appText.opacity(0.6))
            
            Text(title)
                .font(.caption)
                .foregroundColor(.appText.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(width: 140, height: 160)
        .padding()
        .background(Color.appSurface)
        .cornerRadius(16)
    }
}

// MARK: - PR Card
struct PRCard: View {
    let pr: PersonalRecord
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(pr.exerciseName)
                    .font(.headline)
                    .foregroundColor(.appText)
                
                Text("\(pr.weight, specifier: "%.1f")kg × \(pr.reps) reps")
                    .font(.subheadline)
                    .foregroundColor(.appAccent)
                
                Text(pr.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.appText.opacity(0.6))
            }
            
            Spacer()
            
            Image(systemName: "trophy.fill")
                .font(.title)
                .foregroundColor(.yellow)
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct EmptyPRCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy")
                .font(.system(size: 48))
                .foregroundColor(.appText.opacity(0.3))
            
            Text("No PRs Yet")
                .font(.headline)
                .foregroundColor(.appText)
            
            Text("Complete workouts to set your first personal record!")
                .font(.caption)
                .foregroundColor(.appText.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.appSurface)
        .cornerRadius(12)
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
                .foregroundColor(.appText)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(current) \(unit)")
                    .font(.headline)
                    .foregroundColor(.appText)
                
                if change != 0 {
                    HStack(spacing: 4) {
                        Image(systemName: change > 0 ? "arrow.up" : "arrow.down")
                            .font(.caption)
                        Text("\(abs(change)) (\(abs(changePercentage), specifier: "%.0f")%)")
                            .font(.caption)
                    }
                    .foregroundColor(change > 0 ? .green : .red)
                }
            }
        }
    }
}

// MARK: - Muscle Group Row
struct MuscleGroupRow: View {
    let name: String
    let sets: Int
    let percentage: Double
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(name)
                    .font(.subheadline)
                    .foregroundColor(.appText)
                
                Spacer()
                
                Text("\(sets) sets")
                    .font(.caption)
                    .foregroundColor(.appText.opacity(0.6))
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.appBackground)
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(Color.appAccent)
                        .frame(width: geometry.size.width * percentage, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Lifetime Stat Card
struct LifetimeStatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.appAccent)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.appText)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.appText.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.appSurface)
        .cornerRadius(12)
    }
}

// MARK: - All PR Card
struct AllPRsView: View {
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "trophy")
                    .font(.system(size: 60))
                    .foregroundColor(.appAccent)
                
                Text("All Personal Records")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.appText)
                
                Text("Coming Soon")
                    .font(.subheadline)
                    .foregroundColor(.appText.opacity(0.6))
            }
        }
        .navigationTitle("Personal Records")
        .navigationBarTitleDisplayMode(.inline)
    }
}
