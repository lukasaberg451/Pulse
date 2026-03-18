//
//  AIActionSheet.swift
//  Pulse
//

import SwiftUI

struct AIActionSheet: View {
    let onLogWorkout: () -> Void
    let onCreateRoutine: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.semibold))
                    Text("AI Assistant")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Color.appAccent)
                
                Text("What do you want to do?")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.appText)
            }
            .padding(.top, 8)
            
            // Option cards
            HStack(spacing: 12) {
                actionCard(
                    icon: "list.clipboard",
                    title: "Log Workout",
                    subtitle: "Log a completed session"
                ) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onLogWorkout()
                    }
                }
                
                actionCard(
                    icon: "figure.run",
                    title: "Create Routine",
                    subtitle: "Build a new routine with AI"
                ) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onCreateRoutine()
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top, 20)
        .background(Color.appBackground.ignoresSafeArea())
        .presentationDetents([.fraction(0.32)])
        .presentationDragIndicator(.visible)
        .sheetContentTransition()
    }
    
    private func actionCard(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.appAccent)
                    .frame(width: 48, height: 48)
                    .background(Color.appAccentSubtle, in: Circle())
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appText)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.appSecondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        colorScheme == .dark ? Color.white.opacity(0.08) : Color.clear,
                        lineWidth: 1
                    )
            }
            .shadow(color: colorScheme == .light ? Color.black.opacity(0.06) : Color.clear, radius: 12, x: 0, y: 4)
        }
        .buttonStyle(ScalePressStyle())
    }
}
