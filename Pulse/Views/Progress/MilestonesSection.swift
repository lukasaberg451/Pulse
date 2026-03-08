//
//  MilestonesSection.swift
//  Pulse
//

import SwiftUI

struct MilestonesSection: View {
    @ObservedObject var viewModel: MilestoneViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Milestones")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.appText)
                
                Spacer()
                
                if !viewModel.allMilestones.isEmpty {
                    NavigationLink(destination: AllMilestonesView(viewModel: viewModel)) {
                        Text("See All")
                            .font(.subheadline)
                            .foregroundStyle(Color.appAccent)
                    }
                }
            }
            .padding(.horizontal)
            
            if viewModel.allMilestones.isEmpty && !viewModel.isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "trophy")
                        .font(.largeTitle)
                        .foregroundStyle(Color.appAccent.opacity(0.4))
                    
                    Text("No Milestones Yet")
                        .font(.headline)
                        .foregroundStyle(Color.appText)
                    
                    Text("Complete your first workout to start tracking milestones!")
                        .font(.caption)
                        .foregroundStyle(Color.appText.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .background(Color.appSurface)
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                ForEach(viewModel.inProgressMilestones.prefix(3)) { milestone in
                    MilestoneRow(milestone: milestone)
                }
            }
        }
    }
}

// MARK: - All Milestones View
struct AllMilestonesView: View {
    @ObservedObject var viewModel: MilestoneViewModel
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    // In Progress
                    if !viewModel.inProgressMilestones.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("In Progress")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.appText.opacity(0.7))
                                .padding(.horizontal)
                            
                            ForEach(viewModel.inProgressMilestones) { milestone in
                                MilestoneRow(milestone: milestone)
                            }
                        }
                    }
                    
                    // Achieved
                    if !viewModel.achievedMilestones.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Achieved")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.appText.opacity(0.7))
                                .padding(.horizontal)
                            
                            ForEach(viewModel.achievedMilestones) { milestone in
                                AchievedMilestoneRow(
                                    milestone: milestone,
                                    formattedDate: viewModel.formatDate(milestone.achievedAt ?? Date())
                                )
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .refreshable {
                await viewModel.loadMilestones()
            }
        }
        .navigationTitle("Milestones")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
    }
}

// MARK: - In-Progress Row
struct MilestoneRow: View {
    let milestone: UserMilestone
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: milestone.icon)
                    .font(.title3)
                    .foregroundStyle(Color.appAccent)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(milestone.name)
                        .font(.headline)
                        .foregroundStyle(Color.appText)
                    
                    Text(milestone.description)
                        .font(.caption)
                        .foregroundStyle(Color.appText.opacity(0.6))
                }
                
                Spacer()
                
                Text("\(Int(milestone.currentValue))/\(Int(milestone.targetValue))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.appText.opacity(0.8))
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.appAccent.opacity(0.15))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(Color.appAccent)
                        .frame(
                            width: max(6, geometry.size.width * milestone.progress),
                            height: 6
                        )
                }
            }
            .frame(height: 6)
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Achieved Row
struct AchievedMilestoneRow: View {
    let milestone: UserMilestone
    let formattedDate: String
    
    var body: some View {
        HStack {
            Image(systemName: milestone.icon)
                .font(.title3)
                .foregroundStyle(.green)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.name)
                    .font(.headline)
                    .foregroundStyle(Color.appText)
                
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(Color.appText.opacity(0.6))
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
