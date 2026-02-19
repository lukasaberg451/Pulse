//
//  WeeklyGoalSheet.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-15.
//

import SwiftUI

struct WeeklyGoalSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: DashboardViewModel
    @State private var goalMinutes: Int
    
    init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
        _goalMinutes = State(initialValue: viewModel.userProfile?.weeklyGoalMinutes ?? 150)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Weekly Workout Goal")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.appText)
                        
                        Text("Set your target workout minutes per week")
                            .font(.subheadline)
                            .foregroundStyle(Color.appText.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Picker for goal
                    VStack(spacing: 16) {
                        Text("\(goalMinutes) minutes")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(Color.appAccent)
                        
                        Picker("Goal", selection: $goalMinutes) {
                            ForEach([30, 60, 90, 120, 150, 180, 210, 240, 270, 300], id: \.self) { minutes in
                                Text("\(minutes) min").tag(minutes)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 150)
                    }
                    
                    // Suggestions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Suggested Goals")
                            .font(.caption)
                            .foregroundStyle(Color.appText.opacity(0.6))
                        
                        HStack(spacing: 12) {
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
            .toolbarColorScheme(.dark, for: .navigationBar)
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
    }
}

struct GoalButton: View {
    let minutes: Int
    @Binding var currentGoal: Int
    let label: String
    
    var body: some View {
        Button {
            currentGoal = minutes
        } label: {
            VStack(spacing: 4) {
                Text("\(minutes)")
                    .font(.title3)
                    .fontWeight(.bold)
                Text(label)
                    .font(.caption)
            }
            .foregroundStyle(currentGoal == minutes ? Color.white : Color.appText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(currentGoal == minutes ? Color.appAccent : Color.appSurface)
            .cornerRadius(10)
        }
    }
}
