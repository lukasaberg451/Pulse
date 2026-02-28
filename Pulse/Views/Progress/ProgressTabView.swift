//
//  ProgressTabView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-15.
//

import SwiftUI

struct ProgressTabView: View {
    @StateObject private var viewModel = ProgressStatsViewModel()
    @EnvironmentObject var syncService: WorkoutSyncService
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Monthly Stats
                        VStack(alignment: .leading, spacing: 12) {
                            Text("This Month")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.appText)
                                .padding(.horizontal)
                            
                            VStack(spacing: 16) {
                                HStack(spacing: 16) {
                                    StatCard(
                                        title: "Volume",
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
                                }
                                .padding(.horizontal)
                                
                                HStack(spacing: 16) {
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
                        }
                        
                        // Health Metrics Section
                        HealthMetricsSection()
                        
                        // Personal Records
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Personal Records")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.appText)
                                
                                Spacer()
                                
                                NavigationLink(destination: AllPRsView()) {
                                    Text("See All")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.appAccent)
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
                        
                        // Most Trained Muscles
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Most Trained")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.appText)
                                .padding(.horizontal)
                            
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
                            .padding()
                            .background(Color.appSurface)
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                        
                        // Lifetime Stats
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Lifetime Stats")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.appText)
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
                    .padding(.top, 30)
                    .padding(.bottom)
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
                .foregroundStyle(color)
            
            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Color.appText)
            
            Text(unit)
                .font(.caption)
                .foregroundStyle(Color.appText.opacity(0.6))
            
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.appText.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding()
        .background(Color.appSurface)
        .cornerRadius(10)
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
                    .foregroundStyle(Color.appText)
                
                Text("\(pr.weight, specifier: "%.1f")kg × \(pr.reps) reps")
                    .font(.subheadline)
                    .foregroundStyle(Color.appAccent)
                
                Text(pr.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(Color.appText.opacity(0.6))
            }
            
            Spacer()
            
            Image(systemName: "trophy.fill")
                .font(.title)
                .foregroundStyle(Color.yellow)
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct EmptyPRCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy")
                .font(.system(size: 48))
                .foregroundStyle(Color.appAccent.opacity(0.4))
            
            Text("No PRs Yet")
                .font(.headline)
                .foregroundStyle(Color.appText)
            
            Text("Complete workouts to set your first personal record!")
                .font(.caption)
                .foregroundStyle(Color.appText.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.appSurface)
        .cornerRadius(10)
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

// MARK: - Muscle Group Row (Most Trained)
struct MuscleGroupRow: View {
    let name: String
    let sets: Int
    let percentage: Double
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(Color.appText)
                
                Spacer()
                
                Text("\(sets) sets")
                    .font(.caption)
                    .foregroundStyle(Color.appText.opacity(0.6))
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.appBackground)
                        .frame(height: 8)
                        .cornerRadius(10)
                    
                    Rectangle()
                        .fill(Color.appAccent)
                        .frame(width: geometry.size.width * percentage, height: 8)
                        .cornerRadius(10)
                }
            }
            .frame(height: 8)
        }
    }
}

struct EmptyMuscleGroupRow: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(Color.appAccent.opacity(0.4))
            Text("No history yet")
                .font(.headline)
                .foregroundStyle(Color.appText)
            Text("Complete your first workout to see data")
                .font(.caption)
                .foregroundStyle(Color.appText.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.appSurface)
        .cornerRadius(10)
        .padding(.horizontal)
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
                .foregroundStyle(Color.appAccent)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.appText)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.appText.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.appSurface)
        .cornerRadius(10)
    }
}

// MARK: - All PR Card
struct AllPRsView: View {
    @StateObject private var viewModel = ProgressStatsViewModel()
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.recentPRs.isEmpty {
                        // Empty state
                        VStack(spacing: 16) {
                            Image(systemName: "trophy")
                                .font(.system(size: 60))
                                .foregroundStyle(Color.appAccent.opacity(0.4))
                            
                            Text("No Personal Records Yet")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.appText)
                            
                            Text("Complete workouts to set your first personal record!")
                                .font(.subheadline)
                                .foregroundStyle(Color.appText.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 100)
                    } else {
                        // Show all PRs
                        ForEach(viewModel.recentPRs) { pr in
                            PRCard(pr: pr)
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
    @State private var showingEditSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Health Metrics")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.appText)
                
                Spacer()
                
                Button {
                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                    impactLight.impactOccurred()
                    showingEditSheet = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.appAccent)
                }
            }
            .padding(.horizontal)
            
            if let profile = viewModel.profile {
                VStack(spacing: 16) {
                    // Weight and Height Row
                    HStack(spacing: 16) {
                        // Weight Card
                        HealthMetricCard(
                            icon: "scalemass.fill",
                            title: "Weight",
                            value: profile.weightKg != nil ? String(format: "%.1f", profile.weightKg!) : "--",
                            unit: "kg",
                            color: .blue
                        )
                        
                        // Height Card
                        HealthMetricCard(
                            icon: "ruler.fill",
                            title: "Height",
                            value: profile.heightCm != nil ? String(format: "%.0f", profile.heightCm!) : "--",
                            unit: "cm",
                            color: .green
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
                                                .fill(Color.orange.opacity(0.3))
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
                                        .cornerRadius(10)
                                        
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
                                        .font(.system(size: 9))
                                    Spacer()
                                    Text("Normal")
                                        .font(.system(size: 9))
                                    Spacer()
                                    Text("Overweight")
                                        .font(.system(size: 9))
                                    Spacer()
                                    Text("Obese")
                                        .font(.system(size: 9))
                                }
                                .foregroundStyle(Color.appText.opacity(0.5))
                            }
                            .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.appSurface)
                        .cornerRadius(10)
                        .padding(.horizontal)
                    } else if profile.weightKg == nil || profile.heightCm == nil {
                        // Empty state - prompt to add data
                        VStack(spacing: 12) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.appAccent.opacity(0.5))
                            
                            Text("Add your weight and height to calculate BMI")
                                .font(.subheadline)
                                .foregroundStyle(Color.appText.opacity(0.6))
                                .multilineTextAlignment(.center)
                            
                            Button {
                                let impactLight = UIImpactFeedbackGenerator(style: .light)
                                impactLight.impactOccurred()
                                showingEditSheet = true
                            } label: {
                                Text("Add Health Metrics")
                                    .font(.headline)
                                    .foregroundStyle(Color.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.appAccent)
                                    .cornerRadius(10)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .padding(.horizontal)
                        .background(Color.appSurface)
                        .cornerRadius(10)
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
            return .orange
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.appText.opacity(0.7))
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.appText)
                
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(Color.appText.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .padding()
        .background(Color.appSurface)
        .cornerRadius(10)
    }
}

// MARK: - Edit Health Metrics Sheet
struct EditHealthMetricsSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ProfileViewModel
    
    @State private var weightText: String
    @State private var heightText: String
    @State private var showError = false
    @State private var errorMessage = ""
    
    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
        
        let weight = viewModel.profile?.weightKg ?? 0
        let height = viewModel.profile?.heightCm ?? 0
        
        _weightText = State(initialValue: weight > 0 ? String(format: "%.1f", weight) : "")
        _heightText = State(initialValue: height > 0 ? String(format: "%.0f", height) : "")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Error message
                        if showError {
                            Text(errorMessage)
                                .foregroundStyle(Color.red)
                                .font(.caption)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(10)
                        }
                        
                        // Weight Input
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "scalemass.fill")
                                    .foregroundStyle(Color.blue)
                                Text("Weight")
                                    .font(.headline)
                                    .foregroundStyle(Color.appText)
                            }
                            
                            HStack {
                                TextField("0.0", text: $weightText)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.plain)
                                    .font(.title2)
                                    .foregroundStyle(Color.appText)
                                    .multilineTextAlignment(.leading)
                                
                                Text("kg")
                                    .font(.title3)
                                    .foregroundStyle(Color.appText.opacity(0.6))
                            }
                            .padding()
                            .background(Color.appSurface)
                            .cornerRadius(10)
                        }
                        
                        // Height Input
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "ruler.fill")
                                    .foregroundStyle(Color.green)
                                Text("Height")
                                    .font(.headline)
                                    .foregroundStyle(Color.appText)
                            }
                            
                            HStack {
                                TextField("0", text: $heightText)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.plain)
                                    .font(.title2)
                                    .foregroundStyle(Color.appText)
                                    .multilineTextAlignment(.leading)
                                
                                Text("cm")
                                    .font(.title3)
                                    .foregroundStyle(Color.appText.opacity(0.6))
                            }
                            .padding()
                            .background(Color.appSurface)
                            .cornerRadius(10)
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
                
                // Loading overlay
                if viewModel.isSubmitting {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("Saving...")
                            .foregroundStyle(Color.white)
                            .font(.headline)
                    }
                }
            }
            .navigationTitle("Health Metrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appText)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let notificationFeedback = UINotificationFeedbackGenerator()
                        notificationFeedback.notificationOccurred(.success)
                        Task {
                            await saveHealthMetrics()
                        }
                    }
                    .foregroundStyle(Color.appAccent)
                    .fontWeight(.semibold)
                    .disabled(viewModel.isSubmitting)
                }
            }
        }
        .presentationBackground(Color.appBackground)
    }
    
    func saveHealthMetrics() async {
        showError = false
        errorMessage = ""
        
        // Validate inputs
        let weight = Double(weightText)
        let height = Double(heightText)
        
        if let weight = weight, weight <= 0 {
            errorMessage = "Weight must be greater than 0"
            showError = true
            return
        }
        
        if let height = height, height <= 0 {
            errorMessage = "Height must be greater than 0"
            showError = true
            return
        }
        
        // Save to database
        let success = await viewModel.updateHealthMetrics(weightKg: weight, heightCm: height)
        
        if success {
            dismiss()
        } else {
            errorMessage = viewModel.errorMessage ?? "Failed to save health metrics"
            showError = true
        }
    }
}

