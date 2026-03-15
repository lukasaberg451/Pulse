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
    
    @State private var isAnimating = false
    @State private var waveOffset: CGFloat = -1.5
    
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
        .overlay {
            GeometryReader { geo in
                let waveWidth = geo.size.width * 0.6
                LinearGradient(
                    stops: [
                        .init(color: Color.appAccent.opacity(0), location: 0),
                        .init(color: Color.appAccent.opacity(0.18), location: 0.4),
                        .init(color: Color.appAccent.opacity(0.25), location: 0.5),
                        .init(color: Color.appAccent.opacity(0.18), location: 0.6),
                        .init(color: Color.appAccent.opacity(0), location: 1)
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
                .frame(width: waveWidth)
                .blur(radius: 12)
                .offset(x: waveOffset * geo.size.width)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topTrailing)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .allowsHitTesting(false)
        }
        .onTapGesture {
            guard !isAnimating else { return }
            runWave()
        }
        .padding(.horizontal)
    }
    
    private func runWave() {
        isAnimating = true
        waveOffset = -1.5
        withAnimation(.easeInOut(duration: 2.0)) {
            waveOffset = 1.5
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isAnimating = false
            waveOffset = -1.5
        }
    }
}
