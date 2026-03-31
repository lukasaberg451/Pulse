//
//  HealthKitPermissionSheet.swift
//  Pulse
//
//  Shown after onboarding to explain why HealthKit access is needed
//  and request authorization.
//

import SwiftUI

struct HealthKitPermissionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient.dashboardBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer().frame(height: 8)

                // Icon
                Image(systemName: "heart.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.red, Color.pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(20)
                    .background {
                        Circle()
                            .fill(Color.red.opacity(0.12))
                    }

                // Title
                Text("Connect Apple Health")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.appText)
                    .multilineTextAlignment(.center)

                // Description
                Text("Pulse works best with Apple Health. It keeps your workouts running in the background and syncs your data automatically.")
                    .font(.subheadline)
                    .foregroundStyle(Color.appSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                // Benefits
                VStack(spacing: 14) {
                    BenefitRow(
                        icon: "lock.shield.fill",
                        title: "Background Workouts",
                        description: "Your workout keeps tracking even with the screen off."
                    )
                    BenefitRow(
                        icon: "chart.bar.fill",
                        title: "Health Integration",
                        description: "Save your workouts to Apple Health automatically."
                    )
                }
                .padding(.horizontal, 4)

                Spacer()

                // Dismiss button
                Button {
                    Task {
                        await HealthKitManager.shared.requestAuthorization()
                        dismiss()
                    }
                } label: {
                    Text("Got It")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient.accentGradient,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                }
                .buttonStyle(ScalePressStyle())
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appBackground)
    }
}

// MARK: - Benefit Row

private struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.appAccent)
                .frame(width: 32, height: 32)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.appAccent.opacity(0.12))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appText)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(Color.appTertiaryText)
            }

            Spacer()
        }
    }
}
