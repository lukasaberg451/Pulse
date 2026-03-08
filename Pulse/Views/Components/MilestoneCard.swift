//
//  MilestoneCard.swift
//  Pulse
//

import SwiftUI

/// Compact card for the Dashboard showing the next milestone to achieve.
struct MilestoneCard: View {
    let milestone: UserMilestone
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: milestone.icon)
                    .font(.title2)
                    .foregroundStyle(Color.appAccent)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next Milestone")
                        .font(.caption)
                        .foregroundStyle(Color.appText.opacity(0.6))
                    
                    Text(milestone.name)
                        .font(.headline)
                        .foregroundStyle(Color.appText)
                }
                
                Spacer()
                
                Text("\(Int(milestone.progress * 100))%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appAccent)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.appAccent.opacity(0.15))
                        .frame(height: 8)
                    
                    Capsule()
                        .fill(Color.appAccent)
                        .frame(
                            width: max(8, geometry.size.width * milestone.progress),
                            height: 8
                        )
                        .animation(.spring(response: 0.6), value: milestone.progress)
                }
            }
            .frame(height: 8)
            
            Text(milestone.description)
                .font(.caption)
                .foregroundStyle(Color.appText.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(Color.appSurface)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 5)
    }
}
