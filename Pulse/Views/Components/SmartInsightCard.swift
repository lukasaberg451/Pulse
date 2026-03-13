//
//  SmartInsightCard.swift
//  Pulse
//

import SwiftUI

struct SmartInsightCard: View {
    let insight: SmartInsight
    
    /// Whether the icon name refers to an SF Symbol (contains a dot) or a custom asset.
    private var isSystemImage: Bool {
        insight.iconAsset.contains(".")
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            IconBadge(
                systemName: isSystemImage ? insight.iconAsset : "lightbulb.fill",
                color: .appAccent,
                size: 44
            )
            .opacity(isSystemImage ? 1 : 0)
            .overlay {
                if !isSystemImage {
                    IconBadge(assetName: insight.iconAsset, color: .appAccent, size: 44)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(insight.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.appText)
                
                Text(insight.message)
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.appSurface)
                .modifier(CardShadowModifier())
        }
        .padding(.horizontal)
    }
}
