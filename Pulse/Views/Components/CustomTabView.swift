//
//  CustomTabView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/9/26.
//

import SwiftUI

struct CustomTabView: View {
    @Binding var selectedTab: Int
    let tabs: [String]

    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedTab = index
                    }
                } label: {
                    Text(tab)
                        .font(.subheadline.weight(selectedTab == index ? .semibold : .medium))
                        .foregroundStyle(selectedTab == index ? Color.appText : Color.appSecondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if selectedTab == index {
                                Capsule()
                                    .fill(Color.appSurface)
                                    .shadow(
                                        color: colorScheme == .light
                                            ? Color.black.opacity(0.08)
                                            : Color.clear,
                                        radius: 6,
                                        x: 0,
                                        y: 2
                                    )
                                    .matchedGeometryEffect(id: "segmentBg", in: animation)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.appText.opacity(0.06), in: Capsule())
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
