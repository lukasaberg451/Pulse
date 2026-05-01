//
//  MilestonesSection.swift
//  Pulse
//

import SwiftUI

struct MilestonesSection: View {
    @ObservedObject var viewModel: MilestoneViewModel
    @Environment(\.colorScheme) private var colorScheme

    /// Combined list: pending unlock first, then in-progress (up to 3 total)
    private var previewMilestones: [UserMilestone] {
        let pending = viewModel.pendingUnlockMilestones
        let inProgress = viewModel.inProgressMilestones
        return Array((pending + inProgress).prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Milestones", comment: "Section header")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.appText)

                Spacer()

                if !viewModel.allMilestones.isEmpty {
                    NavigationLink(destination: AllMilestonesView(viewModel: viewModel).hidesTabBar()) {
                        Text("See All", comment: "Navigation link")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.appAccent)
                    }
                }
            }
            .padding(.horizontal)

            if viewModel.allMilestones.isEmpty && !viewModel.isLoading {
                VStack(spacing: 14) {
                    IconBadge(assetName: "trophy", size: 48)

                    Text("No Milestones Yet", comment: "Empty state title")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appText)

                    Text("Complete your first workout to start tracking milestones!", comment: "Empty state message")
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
                ForEach(previewMilestones) { milestone in
                    if milestone.isPendingUnlock {
                        UnlockableMilestoneRow(milestone: milestone, viewModel: viewModel)
                    } else {
                        MilestoneRow(milestone: milestone)
                    }
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
                    // Ready to Unlock
                    if !viewModel.pendingUnlockMilestones.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ready to Unlock", comment: "Milestone section header")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.appSecondaryText)
                                .textCase(.uppercase)
                                .padding(.horizontal)

                            StaggeredList(items: viewModel.pendingUnlockMilestones, id: \.id) { milestone in
                                UnlockableMilestoneRow(milestone: milestone, viewModel: viewModel)
                            }
                        }
                    }

                    // In Progress
                    if !viewModel.inProgressMilestones.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("In Progress", comment: "Milestone section header")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.appSecondaryText)
                                .textCase(.uppercase)
                                .padding(.horizontal)

                            StaggeredList(
                                items: viewModel.inProgressMilestones,
                                id: \.id,
                                initialDelay: viewModel.pendingUnlockMilestones.isEmpty ? 0.1 : 0.1 + Double(viewModel.pendingUnlockMilestones.count) * 0.08
                            ) { milestone in
                                MilestoneRow(milestone: milestone)
                            }
                        }
                    }

                    // Completed (Unlocked)
                    if !viewModel.unlockedMilestones.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Completed", comment: "Milestone section header")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.appSecondaryText)
                                .textCase(.uppercase)
                                .padding(.horizontal)

                            StaggeredList(
                                items: viewModel.unlockedMilestones,
                                id: \.id,
                                initialDelay: {
                                    let pendingCount = viewModel.pendingUnlockMilestones.count
                                    let inProgressCount = viewModel.inProgressMilestones.count
                                    let previousCount = pendingCount + inProgressCount
                                    return previousCount == 0 ? 0.1 : 0.1 + Double(previousCount) * 0.08
                                }()
                            ) { milestone in
                                AchievedMilestoneRow(
                                    milestone: milestone,
                                    formattedDate: viewModel.formatDate(milestone.unlockedAt ?? milestone.achievedAt ?? Date())
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
        .sentryScreen("AllMilestones")
        .navigationTitle(String(localized: "Milestones"))
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
                    Text(milestone.localizedName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appText)

                    Text(milestone.localizedDescription)
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

// MARK: - Unlockable Row (Pending Unlock)
struct UnlockableMilestoneRow: View {
    let milestone: UserMilestone
    @ObservedObject var viewModel: MilestoneViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var isUnlocking = false
    @State private var cardScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.0
    @State private var borderGlow: Double = 0.7
    @State private var showCheckmark = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                IconBadge(assetName: milestone.icon, color: .green, size: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text(milestone.localizedName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appText)

                    Text(milestone.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(Color.appSecondaryText)
                }

                Spacer()

                if showCheckmark {
                    Image("check-circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Button {
                        performUnlock()
                    } label: {
                        Text("Unlock", comment: "Milestone unlock button")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(.green, in: Capsule())
                    }
                    .buttonStyle(ScalePressStyle())
                    .disabled(isUnlocking)
                    .transition(.opacity)
                }
            }
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
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.green, lineWidth: 2)
                .opacity(borderGlow)
        }
        .overlay {
            if glowOpacity > 0 {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.green.opacity(glowOpacity))
                    .blur(radius: 6)
                    .allowsHitTesting(false)
            }
        }
        .scaleEffect(cardScale)
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.3), value: showCheckmark)
    }

    private func performUnlock() {
        guard !isUnlocking else { return }
        isUnlocking = true

        let impactMed = UIImpactFeedbackGenerator(style: .medium)
        impactMed.impactOccurred()

        // Phase 1: Scale up + glow
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            cardScale = 1.06
            glowOpacity = 0.2
        }

        // Phase 2: Show checkmark
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                showCheckmark = true
            }

            let impactLight = UIImpactFeedbackGenerator(style: .light)
            impactLight.impactOccurred()
        }

        // Phase 3: Settle back
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.6)) {
                cardScale = 1.0
                glowOpacity = 0.0
                borderGlow = 0.0
            }
        }

        // Phase 4: Update local state after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.commitUnlock(milestone)
            }
        }

        // Persist unlock to server
        Task {
            await viewModel.unlockMilestone(milestone)
        }
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
                Text(milestone.localizedName)
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
