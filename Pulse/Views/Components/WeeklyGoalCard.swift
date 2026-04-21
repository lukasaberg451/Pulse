//
//  WeeklyGoalCard.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-15.
//

import SwiftUI

struct WeeklyGoalCard: View {
    let completedMinutes: Int
    let goalMinutes: Int
    let onEditGoal: () -> Void
    var celebrate: Bool = false

    @State private var glowOpacity: Double = 0.0
    @State private var showUpdatedLabel = false
    @State private var labelOffset: CGFloat = 8
    @State private var labelOpacity: Double = 0

    var progress: Double {
        guard goalMinutes > 0 else { return 0 }
        return Double(completedMinutes) / Double(goalMinutes)
    }

    var goalReached: Bool {
        completedMinutes >= goalMinutes
    }

    var body: some View {
        DashboardCard {
            VStack(spacing: 16) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            IconBadge(assetName: "goal", color: .appAccent, size: 28)
                            Text("Weekly Goal", comment: "Weekly workout goal card title")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.appSecondaryText)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(completedMinutes)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.appText)
                                .contentTransition(.numericText())

                            Text("/ \(goalMinutes) min")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.appTertiaryText)
                                .contentTransition(.numericText())
                        }
                        .animation(.spring(response: 0.4), value: goalMinutes)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        Button {
                            onEditGoal()
                        } label: {
                            Image("sliders-double-horizontal")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundStyle(Color.appTertiaryText)
                        }
                        .buttonStyle(ScalePressStyle())
                        .accessibilityIdentifier("editWeeklyGoalButton")

                        Text(progress.formatted(.percent.precision(.fractionLength(0))))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(goalReached ? .green : Color.appAccent)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4), value: goalMinutes)
                    }
                }

                // Progress bar
                PremiumProgressBar(
                    progress: progress,
                    height: 12,
                    useGreen: goalReached
                )

                // Footer
                HStack {
                    if goalReached {
                        HStack(spacing: 4) {
                            Image("check-circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                            Text("Goal reached!", comment: "Shown when weekly goal is completed")
                        }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                            .opacity(showUpdatedLabel ? 0 : 1)
                    }

                    Spacer()
                }
                .overlay(alignment: .leading) {
                    if showUpdatedLabel {
                        HStack(spacing: 4) {
                            Image("check-circle")
                                .font(.caption)
                            Text("Goal updated!", comment: "Shown after updating weekly goal")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appAccent)
                        .offset(y: labelOffset)
                        .opacity(labelOpacity)
                    }
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.appAccent, lineWidth: 2)
                .opacity(glowOpacity)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("weeklyGoalCard")
        .onChange(of: celebrate) { _, newValue in
            guard newValue else { return }
            runCelebration()
        }
    }

    private func runCelebration() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        showUpdatedLabel = true

        // Phase 1: glow border + label entrance
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            glowOpacity = 0.7
            labelOffset = 0
            labelOpacity = 1
        }

        // Phase 2: fade glow
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeInOut(duration: 0.6)) {
                glowOpacity = 0.0
            }
        }

        // Phase 3: fade out label
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.4)) {
                labelOpacity = 0
                labelOffset = -4
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showUpdatedLabel = false
                labelOffset = 8
            }
        }
    }
}
