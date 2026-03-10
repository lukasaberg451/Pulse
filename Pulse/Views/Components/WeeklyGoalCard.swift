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
                            IconBadge(assetName: "FlameIcon", color: .appAccent, size: 28)
                            Text("Weekly Goal")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.appSecondaryText)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(completedMinutes)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.appText)

                            Text("/ \(goalMinutes) min")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.appTertiaryText)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        Button {
                            onEditGoal()
                        } label: {
                            Image("adjustments-horizontal")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundStyle(Color.appTertiaryText)
                        }
                        .buttonStyle(ScalePressStyle())

                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(goalReached ? .green : Color.appAccent)
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
                            Text("Goal reached!")
                        }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    Spacer()
                }
            }
        }
    }
}
