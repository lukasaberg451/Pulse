//
//  MilestonesSection.swift
//  Pulse
//

import SwiftUI

struct MilestonesSection: View {
    @ObservedObject var viewModel: MilestoneViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Milestones")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.appText)

                Spacer()

                if !viewModel.allMilestones.isEmpty {
                    NavigationLink(destination: AllMilestonesView(viewModel: viewModel).hidesTabBar()) {
                        Text("See All")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.appAccent)
                    }
                }
            }
            .padding(.horizontal)

            if viewModel.allMilestones.isEmpty && !viewModel.isLoading {
                VStack(spacing: 14) {
                    IconBadge(assetName: "trophy", size: 48)

                    Text("No Milestones Yet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appText)

                    Text("Complete your first workout to start tracking milestones!")
                        .font(.caption)
                        .foregroundStyle(Color.appSecondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(28)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.appSurface)
                        .overlay {
                            if colorScheme == .dark {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            }
                        }
                        .shadow(
                            color: colorScheme == .light ? Color.black.opacity(0.08) : Color.clear,
                            radius: 16, x: 0, y: 6
                        )
                }
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
            LinearGradient.dashboardBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // In Progress
                    if !viewModel.inProgressMilestones.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("In Progress")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.appSecondaryText)
                                .textCase(.uppercase)
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
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.appSecondaryText)
                                .textCase(.uppercase)
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                IconBadge(assetName: milestone.icon, color: .appAccent, size: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text(milestone.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appText)

                    Text(milestone.description)
                        .font(.caption)
                        .foregroundStyle(Color.appSecondaryText)
                }

                Spacer()

                Text("\(Int(milestone.currentValue))/\(Int(milestone.targetValue))")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.appAccent)
            }

            PremiumProgressBar(progress: milestone.progress, height: 8)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appSurface)
                .overlay {
                    if colorScheme == .dark {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    }
                }
                .shadow(
                    color: colorScheme == .light ? Color.black.opacity(0.08) : Color.clear,
                    radius: 16, x: 0, y: 6
                )
        }
        .padding(.horizontal)
    }
}

// MARK: - Achieved Row
struct AchievedMilestoneRow: View {
    let milestone: UserMilestone
    let formattedDate: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(assetName: milestone.icon, color: .green, size: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(milestone.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appText)

                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryText)
            }

            Spacer()

            Image("check-circle")
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(.green)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appSurface)
                .overlay {
                    if colorScheme == .dark {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    }
                }
                .shadow(
                    color: colorScheme == .light ? Color.black.opacity(0.08) : Color.clear,
                    radius: 16, x: 0, y: 6
                )
        }
        .padding(.horizontal)
    }
}
