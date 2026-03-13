//
//  DashboardComponents.swift
//  Pulse
//
//  Reusable UI components for the dashboard redesign.
//

import SwiftUI

// MARK: - Dashboard Card Container

/// A floating card surface with adaptive shadows (light) and borders (dark).
struct DashboardCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.appSurface)
                    .overlay {
                        if colorScheme == .dark {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        }
                    }
                    .shadow(
                        color: colorScheme == .light
                            ? Color.black.opacity(0.08)
                            : Color.clear,
                        radius: 16,
                        x: 0,
                        y: 6
                    )
            }
    }
}

// MARK: - Primary CTA Button

/// An orange-gradient CTA button with scale press effect.
struct PrimaryCTAButton: View {
    let title: String
    let icon: String?
    let systemIcon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, systemIcon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.systemIcon = systemIcon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemIcon {
                    Image(systemName: systemIcon)
                        .font(.body.weight(.semibold))
                } else if let icon {
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                }
                Text(title)
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(LinearGradient.accentGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(ScalePressStyle())
    }
}

// MARK: - Primary CTA Navigation Link

/// An orange-gradient CTA as a NavigationLink.
struct PrimaryCTALink<Destination: View>: View {
    let title: String
    let icon: String?
    let systemIcon: String?
    let destination: () -> Destination

    init(_ title: String, icon: String? = nil, systemIcon: String? = nil, @ViewBuilder destination: @escaping () -> Destination) {
        self.title = title
        self.icon = icon
        self.systemIcon = systemIcon
        self.destination = destination
    }

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 8) {
                if let systemIcon {
                    Image(systemName: systemIcon)
                        .font(.body.weight(.semibold))
                } else if let icon {
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                }
                Text(title)
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(LinearGradient.accentGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(ScalePressStyle())
    }
}

// MARK: - Premium Progress Bar

/// A thick, rounded progress bar with gradient fill and tinted track.
struct PremiumProgressBar: View {
    let progress: Double
    var height: CGFloat = 12
    var useGreen: Bool = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.appAccentSubtle)
                    .frame(height: height)

                Capsule()
                    .fill(fillGradient)
                    .frame(
                        width: max(height, geometry.size.width * min(progress, 1.0)),
                        height: height
                    )
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: progress)
            }
        }
        .frame(height: height)
    }

    private var fillGradient: LinearGradient {
        if useGreen {
            return LinearGradient(
                colors: [.green, .green.opacity(0.75)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        return .progressGradient
    }
}

// MARK: - Icon Badge

/// An icon inside a subtle tinted circular background.
/// Supports both SF Symbols (`systemName:`) and asset catalog images (`assetName:`).
struct IconBadge: View {
    let systemName: String?
    let assetName: String?
    var color: Color = .appAccent
    var size: CGFloat = 36

    init(systemName: String, color: Color = .appAccent, size: CGFloat = 36) {
        self.systemName = systemName
        self.assetName = nil
        self.color = color
        self.size = size
    }

    init(assetName: String, color: Color = .appAccent, size: CGFloat = 36) {
        self.systemName = nil
        self.assetName = assetName
        self.color = color
        self.size = size
    }

    var body: some View {
        Group {
            if let systemName {
                Image(systemName: systemName)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
            } else if let assetName {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.44, height: size * 0.44)
            }
        }
        .foregroundStyle(color)
        .frame(width: size, height: size)
        .background(color.opacity(0.12), in: Circle())
    }
}

// MARK: - Stat Pill

/// A compact inline stat display (e.g. streak count).
struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    var triggerHighlight: Bool = false

    @State private var hasPlayedInitial = false
    @State private var isAnimating = false
    @State private var glowOpacity: Double = 0.0
    @State private var pillScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 8) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(Color.appAccent)

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.appText)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.appSecondaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.appAccentSubtle, in: Capsule())
        .overlay {
            Capsule()
                .fill(Color.appAccent.opacity(glowOpacity))
                .blur(radius: 4)
        }
        .scaleEffect(pillScale)
        .onTapGesture {
            guard !isAnimating else { return }
            runHighlight()
        }
        .onChange(of: triggerHighlight) { _, newValue in
            guard newValue, !hasPlayedInitial else { return }
            hasPlayedInitial = true
            runHighlight()
        }
    }

    private func runHighlight() {
        isAnimating = true

        // Phase 1: scale up + glow on
        withAnimation(.easeOut(duration: 0.45)) {
            pillScale = 1.06
            glowOpacity = 0.25
        }

        // Phase 2: hold, then settle back
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.8)) {
                pillScale = 1.0
                glowOpacity = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                isAnimating = false
            }
        }
    }
}

// MARK: - Section Header

struct DashboardSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title3.weight(.bold))
            .foregroundStyle(Color.appText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
    }
}

// MARK: - Scale Press Button Style

struct ScalePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(configuration.isPressed ? .easeOut(duration: 0.05) : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
