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
    let spotlightFrames: [String: CGRect]
    @Binding var selectedTab: HomeTab

    @Environment(\.colorScheme) private var colorScheme

    @State private var animatedFrame: CGRect = .zero
    @State private var animatedCornerRadius: CGFloat = 22
    @State private var pulseScale: CGFloat = 1.0
    @State private var cardSize: CGSize = .zero

    private var currentStep: TourStep? { manager.currentStep }

    private var targetFrame: CGRect {
        guard let step = currentStep,
              let raw = spotlightFrames[step.id] else { return .zero }
        return raw.insetBy(dx: -step.spotlightPadding, dy: -step.spotlightPadding)
    }

    var body: some View {
        if manager.isActive, let step = currentStep {
            // Use Canvas for the dimmed overlay — it works in the view's own coordinate space.
            // Since this view sits inside HomeView's ZStack, we use coordinateSpace to
            // convert global frames to local.
            GeometryReader { geo in
                let origin = geo.frame(in: .global).origin
                // Convert the animated (global) frame to local coordinates
                let localFrame = CGRect(
                    x: animatedFrame.minX - origin.x,
                    y: animatedFrame.minY - origin.y,
                    width: animatedFrame.width,
                    height: animatedFrame.height
                )

                let screenW = geo.size.width
                let screenH = geo.size.height
                let gap: CGFloat = 16
                let spaceBelow = screenH - localFrame.maxY
                let spaceAbove = localFrame.minY
                let showAbove = spaceAbove > spaceBelow
                let cardW = min(screenW - 40, 340.0)

                // Card Y: place its center above or below the cutout
                let cardCenterY: CGFloat = {
                    let halfCard = cardSize.height / 2
                    if showAbove {
                        // Card bottom edge at localFrame.minY - gap
                        let y = localFrame.minY - gap - halfCard
                        // Clamp so card doesn't go above screen
                        return max(halfCard + 8, y)
                    } else {
                        // Card top edge at localFrame.maxY + gap
                        let y = localFrame.maxY + gap + halfCard
                        // Clamp so card doesn't go below screen
                        return min(screenH - halfCard - 8, y)
                    }
                }()

                ZStack {
                    // MARK: - Dimmed backdrop with cutout
                    Canvas { ctx, size in
                        let fullRect = CGRect(origin: .zero, size: size)
                        let cutout = RoundedRectangle(cornerRadius: animatedCornerRadius, style: .continuous)
                            .path(in: localFrame)

                        var path = Rectangle().path(in: fullRect)
                        path.addPath(cutout)

                        ctx.fill(path, with: .color(.black.opacity(0.6)), style: FillStyle(eoFill: true))
                    }
                    .allowsHitTesting(false)

                    // MARK: - Pulsing border
                    RoundedRectangle(cornerRadius: animatedCornerRadius, style: .continuous)
                        .stroke(Color.appAccent.opacity(0.6), lineWidth: 2)
                        .frame(width: localFrame.width, height: localFrame.height)
                        .position(x: localFrame.midX, y: localFrame.midY)
                        .scaleEffect(pulseScale, anchor: .center)
                        .allowsHitTesting(false)

                    // MARK: - Tooltip card
                    cardContent(for: step, width: cardW)
                        .background(
                            GeometryReader { cardGeo in
                                Color.clear
                                    .onAppear { cardSize = cardGeo.size }
                                    .onChange(of: manager.currentIndex) { _, _ in
                                        DispatchQueue.main.async {
                                            cardSize = cardGeo.size
                                        }
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
                animatedCornerRadius = step.spotlightCornerRadius
                startPulse()
            }
            .onChange(of: manager.currentIndex) { _, _ in
                guard let step = manager.currentStep else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    animatedFrame = targetFrame
                    animatedCornerRadius = step.spotlightCornerRadius
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

    // MARK: - Pulse animation

    private func startPulse() {
        withAnimation(
            .easeInOut(duration: 1.1)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.03
        }
    }
}
