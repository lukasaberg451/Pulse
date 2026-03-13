//
//  SpotlightOverlay.swift
//  Pulse
//
//  Full-screen dimmed overlay that cuts out a transparent spotlight hole
//  over the highlighted element, with a pulsing border and a floating
//  tooltip card.
//

import SwiftUI

struct SpotlightOverlay: View {
    @ObservedObject var manager: OnboardingTourManager
    /// Frames already resolved into the overlay's local coordinate space.
    let spotlightFrames: [String: CGRect]
    @Binding var selectedTab: HomeTab

    @Environment(\.colorScheme) private var colorScheme

    @State private var animatedFrame: CGRect = .zero
    @State private var animatedCornerRadius: CGFloat = 22
    @State private var cardSize: CGSize = CGSize(width: 300, height: 220)

    private var currentStep: TourStep? { manager.currentStep }

    /// The target frame for the current step, with padding applied.
    private var targetFrame: CGRect {
        guard let step = currentStep,
              let raw = spotlightFrames[step.id] else { return .zero }
        return raw.insetBy(dx: -step.spotlightPadding, dy: -step.spotlightPadding)
    }

    private var targetCornerRadius: CGFloat {
        guard let step = currentStep else { return 22 }
        return step.spotlightCornerRadius + step.spotlightPadding
    }

    var body: some View {
        if manager.isActive, let step = currentStep {
            GeometryReader { geo in
                let screenW = geo.size.width
                let screenH = geo.size.height
                let gap: CGFloat = 16
                let cardW = min(screenW - 40, 340.0)
                let hidesCutout = step.hidesSpotlight
                let spaceAbove = animatedFrame.minY
                let spaceBelow = screenH - animatedFrame.maxY
                let showAbove = spaceAbove > spaceBelow

                let cardCenterY: CGFloat = {
                    if hidesCutout {
                        return screenH / 2
                    }
                    let half = cardSize.height / 2
                    if showAbove {
                        return max(half + 8, animatedFrame.minY - gap - half)
                    } else {
                        return min(screenH - half - 8, animatedFrame.maxY + gap + half)
                    }
                }()

                ZStack {
                    // MARK: - Dimmed backdrop with cutout
                    Canvas { ctx, size in
                        let full = CGRect(origin: .zero, size: size)
                        if hidesCutout {
                            ctx.fill(Rectangle().path(in: full), with: .color(.black.opacity(0.6)))
                        } else {
                            let hole = RoundedRectangle(cornerRadius: animatedCornerRadius, style: .continuous)
                                .path(in: animatedFrame)
                            var combined = Rectangle().path(in: full)
                            combined.addPath(hole)
                            ctx.fill(combined, with: .color(.black.opacity(0.6)), style: FillStyle(eoFill: true))
                        }
                    }
                    .allowsHitTesting(false)

                    // MARK: - Border around cutout
                    if !hidesCutout {
                        RoundedRectangle(cornerRadius: animatedCornerRadius, style: .continuous)
                            .stroke(Color.appAccent.opacity(0.5), lineWidth: 2)
                            .frame(width: animatedFrame.width, height: animatedFrame.height)
                            .position(x: animatedFrame.midX, y: animatedFrame.midY)
                            .allowsHitTesting(false)
                    }

                    // MARK: - Tooltip card
                    cardContent(for: step, width: cardW)
                        .background(
                            GeometryReader { cardGeo in
                                Color.clear
                                    .onAppear { cardSize = cardGeo.size }
                                    .onChange(of: manager.currentIndex) { _, _ in
                                        DispatchQueue.main.async { cardSize = cardGeo.size }
                                    }
                            }
                        )
                        .position(x: screenW / 2, y: cardCenterY)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: manager.currentIndex)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: animatedFrame)
                }
            }
            .ignoresSafeArea()
            .onTapGesture { advanceOrFinish() }
            .onAppear {
                animatedFrame = targetFrame
                animatedCornerRadius = targetCornerRadius
            }
            .onChange(of: manager.currentIndex) { _, _ in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    animatedFrame = targetFrame
                    animatedCornerRadius = targetCornerRadius
                }
            }
            .onChange(of: targetFrame) { _, newFrame in
                guard newFrame != .zero else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    animatedFrame = newFrame
                }
            }
        }
    }

    // MARK: - Card content

    @ViewBuilder
    private func cardContent(for step: TourStep, width: CGFloat) -> some View {
        VStack(spacing: 12) {
            Text("Step \(manager.progress.current) of \(manager.progress.total)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.appAccent)

            Text(step.title)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.appText)
                .multilineTextAlignment(.center)

            Text(step.body)
                .font(.subheadline)
                .foregroundStyle(Color.appSecondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                ForEach(0..<manager.steps.count, id: \.self) { i in
                    Circle()
                        .fill(i == manager.currentIndex ? Color.appAccent : Color.appText.opacity(0.18))
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.top, 2)

            HStack(spacing: 12) {
                if manager.currentIndex < manager.steps.count - 1 {
                    Button {
                        manager.skip()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                            selectedTab = .dashboard
                        }
                    } label: {
                        Text("Skip")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.appTertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                }

                Button { advanceOrFinish() } label: {
                    Text(manager.currentIndex < manager.steps.count - 1 ? "Next" : "Done")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(LinearGradient.accentGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding(20)
        .frame(width: width)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appSurface)
                .overlay {
                    if colorScheme == .dark {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    }
                }
                .shadow(
                    color: colorScheme == .light ? .black.opacity(0.12) : .black.opacity(0.4),
                    radius: 20, x: 0, y: 10
                )
        }
    }

    // MARK: - Navigation

    private func advanceOrFinish() {
        if manager.currentIndex < manager.steps.count - 1 {
            manager.next()
        } else {
            manager.next()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                selectedTab = .dashboard
            }
        }
    }

}
