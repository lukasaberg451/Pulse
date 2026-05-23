//
//  MilestoneCard.swift
//  Pulse
//

import SwiftUI

/// Compact card for the Dashboard showing the next milestone to achieve
/// or a pending-unlock milestone with an unlock button.
struct MilestoneCard: View {
    let milestone: UserMilestone
    @ObservedObject var viewModel: MilestoneViewModel

    @State private var isUnlocking = false
    @State private var cardScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.0
    @State private var showCheckmark = false
    @State private var showNextButton = false

    @State private var borderGlow: Double = 0.7

    var body: some View {
        DashboardCard {
            if milestone.isPendingUnlock {
                pendingUnlockContent
            } else {
                inProgressContent
            }
        }
        .overlay {
            if milestone.isPendingUnlock {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.green, lineWidth: 2)
                    .opacity(borderGlow)
            }
        }
        .scaleEffect(cardScale)
        .overlay {
            if glowOpacity > 0 {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.green.opacity(glowOpacity))
                    .blur(radius: 8)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Pending Unlock Content

    private var pendingUnlockContent: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                IconBadge(assetName: milestone.icon, color: .green, size: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Achievement Complete!", comment: "Milestone card status")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)

                    Text(milestone.localizedName)
                        .font(.headline)
                        .foregroundStyle(Color.appText)
                }

                Spacer()

                if showCheckmark {
                    Image("check-circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            Text(milestone.localizedDescription)
                .font(.caption)
                .foregroundStyle(Color.appTertiaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !showCheckmark {
                Button {
                    performUnlock()
                } label: {
                    HStack(spacing: 6) {
                        Image("trophy")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                        Text("Unlock Achievement", comment: "Milestone unlock button")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(.green, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(ScalePressStyle())
                .disabled(isUnlocking)
                .transition(.opacity)
            }

            if showNextButton {
                Button {
                    advanceToNext()
                } label: {
                    HStack(spacing: 6) {
                        Text(viewModel.dashboardMilestone != nil ? String(localized: "Next Achievement") : String(localized: "Done"))
                            .font(.subheadline.weight(.bold))
                        if viewModel.dashboardMilestone != nil {
                            Image("chevron-right")
                                .font(.caption.weight(.bold))
                        }
                    }
                    .foregroundStyle(Color.appAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.appAccentSubtle, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(ScalePressStyle())
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showCheckmark)
        .animation(.easeInOut(duration: 0.3), value: showNextButton)
    }

    // MARK: - In Progress Content

    private var inProgressContent: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                IconBadge(assetName: milestone.icon, color: .appAccent, size: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Next Milestone", comment: "In-progress milestone label")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.appSecondaryText)

                    Text(milestone.localizedName)
                        .font(.headline)
                        .foregroundStyle(Color.appText)
                }

                Spacer()

                Text(milestone.progress.formatted(.percent.precision(.fractionLength(0))))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appAccent)
            }

            PremiumProgressBar(progress: milestone.progress, height: 10)

            Text(milestone.localizedDescription)
                .font(.caption)
                .foregroundStyle(Color.appTertiaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Unlock Animation

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

        // Phase 3: Settle back + show next button
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.6)) {
                cardScale = 1.0
                glowOpacity = 0.0
                borderGlow = 0.0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showNextButton = true
            }
        }

        // Persist unlock
        Task {
            await viewModel.unlockMilestone(milestone)
        }
    }

    private func advanceToNext() {
        let impactLight = UIImpactFeedbackGenerator(style: .light)
        impactLight.impactOccurred()

        // Commit the unlock to local state - this changes dashboardMilestone
        // and SwiftUI will create a fresh card via .id(dashboardMilestone.id)
        viewModel.commitUnlock(milestone)
    }
}
