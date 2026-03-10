//
//  WeeklyGoalSheet.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-15.
//

import SwiftUI

struct WeeklyGoalSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: DashboardViewModel
    @State private var goalMinutes: Int

    init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
        _goalMinutes = State(initialValue: viewModel.userProfile?.weeklyGoalMinutes ?? 150)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground
                    .ignoresSafeArea()

                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 8) {
                        IconBadge(assetName: "FlameIcon", color: .appAccent, size: 48)

                        Text("Weekly Workout Goal")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.appText)

                        Text("Set your target workout minutes per week")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // Large value display
                    VStack(spacing: 16) {
                        Text("\(goalMinutes)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.appAccent)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3), value: goalMinutes)

                        Text("minutes per week")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.appTertiaryText)

                        Picker("Goal", selection: $goalMinutes) {
                            ForEach([30, 60, 90, 120, 150, 180, 210, 240, 270, 300], id: \.self) { minutes in
                                Text("\(minutes) min").tag(minutes)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 140)
                    }

                    // Suggested goals
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Suggested Goals")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.appSecondaryText)
                            .padding(.horizontal, 4)

                        HStack(spacing: 10) {
                            GoalButton(minutes: 150, currentGoal: $goalMinutes, label: "Recommended")
                            GoalButton(minutes: 210, currentGoal: $goalMinutes, label: "Active")
                            GoalButton(minutes: 300, currentGoal: $goalMinutes, label: "Athlete")
                        }
                    }
                    .padding(.horizontal)

                    Spacer()
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

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.updateWeeklyGoal(minutes: goalMinutes)
                            dismiss()
                        }
                    }
                    .foregroundStyle(Color.appAccent)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationBackground(Color.appBackground)
    }
}

struct GoalButton: View {
    let minutes: Int
    @Binding var currentGoal: Int
    let label: String
    @Environment(\.colorScheme) private var colorScheme

    private var isSelected: Bool { currentGoal == minutes }

    var body: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            withAnimation(.spring(response: 0.3)) {
                currentGoal = minutes
            }
        } label: {
            VStack(spacing: 5) {
                Text("\(minutes)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(label)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(isSelected ? .white : Color.appText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(LinearGradient.accentGradient) : AnyShapeStyle(Color.appSurface))
                    .overlay {
                        if !isSelected && colorScheme == .dark {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        }
                    }
                    .shadow(
                        color: isSelected
                            ? Color.appAccent.opacity(0.3)
                            : (colorScheme == .light ? Color.black.opacity(0.06) : Color.clear),
                        radius: isSelected ? 8 : 6,
                        x: 0,
                        y: isSelected ? 4 : 3
                    )
            }
        }
        .buttonStyle(ScalePressStyle())
    }
}
