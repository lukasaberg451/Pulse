//
//  ActivityRing.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-15.
//

import SwiftUI

struct ActivityRing: View {
    let progress: Double  // 0.0 to 1.0
    let lineWidth: CGFloat = 20
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.appSurface, lineWidth: lineWidth)
            
            // Progress arc
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.appAccent,
                            Color.appAccent.opacity(0.7),
                            Color.appAccent
                        ]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6), value: progress)
        }
    }
}

struct WeeklyGoalCard: View {
    let completedMinutes: Int
    let goalMinutes: Int
    let onEditGoal: () -> Void
    
    var progress: Double {
        guard goalMinutes > 0 else { return 0 }
        return Double(completedMinutes) / Double(goalMinutes)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Weekly Goal")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.appText)
                
                Spacer()
                
                Button {
                    onEditGoal()
                } label: {
                    Image(systemName: "gear")
                        .foregroundColor(.appText.opacity(0.6))
                }
            }
            
            ZStack {
                ActivityRing(progress: progress)
                    .frame(width: 200, height: 200)
                
                VStack(spacing: 4) {
                    Text("\(completedMinutes)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.appAccent)
                    
                    Text("of \(goalMinutes) min")
                        .font(.caption)
                        .foregroundColor(.appText.opacity(0.7))
                    
                    Text("\(Int(progress * 100))%")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.appText)
                        .padding(.top, 4)
                }
            }
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This Week")
                        .font(.caption)
                        .foregroundColor(.appText.opacity(0.6))
                    Text("\(completedMinutes) min")
                        .font(.headline)
                        .foregroundColor(.appText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Remaining")
                        .font(.caption)
                        .foregroundColor(.appText.opacity(0.6))
                    Text("\(max(0, goalMinutes - completedMinutes)) min")
                        .font(.headline)
                        .foregroundColor(.appText)
                }
            }
            .padding(.horizontal)
        }
        .padding(20)
        .background(Color.appSurface)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}
