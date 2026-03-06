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
        VStack(spacing: 16) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly Goal")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.appText.opacity(0.8))
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(completedMinutes)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.appText)
                        
                        Text("/ \(goalMinutes) min")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.appText.opacity(0.5))
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    Button {
                        onEditGoal()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.body)
                            .foregroundStyle(Color.appText.opacity(0.4))
                    }
                    
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(goalReached ? .green : Color.appAccent)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.appAccent.opacity(0.15))
                        .frame(height: 10)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: goalReached
                                    ? [.green, .green.opacity(0.8)]
                                    : [Color.appAccent, Color.appAccent.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(10, geometry.size.width * min(progress, 1.0)), height: 10)
                        .animation(.spring(response: 0.6), value: progress)
                }
            }
            .frame(height: 10)
            
            // Footer
            HStack {
                if goalReached {
                    Label("Goal reached!", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                } else {
                    Text("")
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(Color.appSurface)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 5)
    }
}
