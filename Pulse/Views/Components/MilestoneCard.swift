//
//  MilestoneCard.swift
//  Pulse
//

import SwiftUI

/// Compact card for the Dashboard showing the next milestone to achieve.
struct MilestoneCard: View {
    let milestone: UserMilestone

    var body: some View {
        DashboardCard {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    IconBadge(systemName: milestone.icon, color: .appAccent, size: 38)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Next Milestone")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.appSecondaryText)

                        Text(milestone.name)
                            .font(.headline)
                            .foregroundStyle(Color.appText)
                    }

                    Spacer()

                    Text("\(Int(milestone.progress * 100))%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appAccent)
                }

                PremiumProgressBar(progress: milestone.progress, height: 10)

                Text(milestone.description)
                    .font(.caption)
                    .foregroundStyle(Color.appTertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
