//
//  CustomTabView.swift
//  Pulse
//
//  Created by lukasaberg on 2/9/26.
//

import SwiftUI

struct CustomTabView: View {
    @Binding var selectedTab: Int
    let tabs: [String]
    
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                VStack(spacing: 8) {
                    Text(tab)
                        .font(.system(size: 16, weight: selectedTab == index ? .semibold : .regular))
                        .foregroundStyle(selectedTab == index ? Color.appText : Color.appText.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = index
                            }
                        }
                    
                    // Underline indicator
                    if selectedTab == index {
                        Rectangle()
                            .fill(Color.appAccent)
                            .frame(height: 3)
                            .matchedGeometryEffect(id: "underline", in: animation)
                    } else {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 3)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .background(Color.appBackground)
    }
}
