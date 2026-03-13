//
//  SplashOverlay.swift
//  Pulse
//

import SwiftUI

/// Splash screen shown on app launch after the iOS launch screen.
/// Uses LoadingBackground color (always dark) with logo, independent of light/dark theme.
struct SplashOverlay: View {
    let isInitializing: Bool
    @Binding var isVisible: Bool
    
    @State private var appearTime = Date()
    private let minimumDisplayTime: TimeInterval = 3.5
    
    // Breathe animation
    private let breatheDelay: TimeInterval = 0.3
    private let breatheHalfCycle: TimeInterval = 1.4
    @State private var breatheScale: CGFloat = 1.0
    @State private var breatheStartTime = Date.distantFuture
    
    // Exit animation
    @State private var isDismissing = false
    @State private var exitScale: CGFloat = 1.0
    @State private var logoOpacity: Double = 1
    @State private var backgroundOpacity: Double = 1
    
    var body: some View {
        ZStack {
            Color("LoadingBackground")
                .opacity(backgroundOpacity)
            
            Image("LoadingLogo")
                .scaleEffect(isDismissing ? exitScale : breatheScale)
                .opacity(logoOpacity)
        }
        .ignoresSafeArea()
        .onAppear {
            appearTime = Date()
            startLoadingAnimations()
            if !isInitializing {
                dismiss()
            }
        }
        .onChange(of: isInitializing) { _, newValue in
            if !newValue {
                dismiss()
            }
        }
    }
    
    private func startLoadingAnimations() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(breatheDelay))
            guard !isDismissing else { return }
            breatheStartTime = Date()
            withAnimation(.easeInOut(duration: breatheHalfCycle).repeatForever(autoreverses: true)) {
                breatheScale = 1.10
            }
        }
    }
    
    /// Time until the next cycle end (scale back at 1.0)
    private func timeUntilCycleEnd() -> TimeInterval {
        let elapsed = Date().timeIntervalSince(breatheStartTime)
        guard elapsed >= 0 else { return 0 }
        let fullCycle = breatheHalfCycle * 2
        let positionInCycle = elapsed.truncatingRemainder(dividingBy: fullCycle)
        if positionInCycle < 0.05 || (fullCycle - positionInCycle) < 0.05 {
            return 0 // Close enough to cycle end
        }
        return fullCycle - positionInCycle
    }
    
    private func dismiss() {
        let elapsed = Date().timeIntervalSince(appearTime)
        let remaining = max(minimumDisplayTime - elapsed, 0)
        
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(remaining))
            
            // Wait for the current breathe cycle to finish so the logo is back at scale 1.0
            let waitForCycle = timeUntilCycleEnd()
            if waitForCycle > 0 {
                try? await Task.sleep(for: .seconds(waitForCycle))
            }
            
            isDismissing = true
            
            try? await Task.sleep(for: .milliseconds(50))
            
            withAnimation(.easeIn(duration: 0.5)) {
                logoOpacity = 0
                exitScale = 1.08
            }
            
            try? await Task.sleep(for: .seconds(0.2))
            withAnimation(.easeIn(duration: 0.3)) {
                backgroundOpacity = 0
            }
            
            try? await Task.sleep(for: .seconds(0.3))
            isVisible = false
        }
    }
}

/// Loading screen shown after sign-in/sign-out transitions.
struct PostLoginLoadingView: View {
    @Binding var isVisible: Bool
    
    private let displayDuration: TimeInterval = 3.5
    
    // Breathe animation
    private let breatheDelay: TimeInterval = 0.3
    private let breatheHalfCycle: TimeInterval = 1.4
    @State private var breatheScale: CGFloat = 1.0
    @State private var breatheStartTime = Date.distantFuture
    
    // Exit animation
    @State private var isDismissing = false
    @State private var exitScale: CGFloat = 1.0
    @State private var logoOpacity: Double = 1
    @State private var backgroundOpacity: Double = 1
    
    var body: some View {
        ZStack {
            Color.appBackground
                .opacity(backgroundOpacity)
            LinearGradient.dashboardBackground
                .opacity(backgroundOpacity)
            
            Image("LoadingLogo")
                .scaleEffect(isDismissing ? exitScale : breatheScale)
                .opacity(logoOpacity)
        }
        .ignoresSafeArea()
        .onAppear {
            startBreathAnimation()
        }
        .task {
            try? await Task.sleep(for: .seconds(displayDuration))
            await dismiss()
        }
    }
    
    private func startBreathAnimation() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(breatheDelay))
            guard !isDismissing else { return }
            breatheStartTime = Date()
            withAnimation(.easeInOut(duration: breatheHalfCycle).repeatForever(autoreverses: true)) {
                breatheScale = 1.10
            }
        }
    }
    
    /// Time until the next cycle end (scale back at 1.0)
    private func timeUntilCycleEnd() -> TimeInterval {
        let elapsed = Date().timeIntervalSince(breatheStartTime)
        guard elapsed >= 0 else { return 0 }
        let fullCycle = breatheHalfCycle * 2
        let positionInCycle = elapsed.truncatingRemainder(dividingBy: fullCycle)
        if positionInCycle < 0.05 || (fullCycle - positionInCycle) < 0.05 {
            return 0
        }
        return fullCycle - positionInCycle
    }
    
    @MainActor
    private func dismiss() async {
        // Wait for the current breathe cycle to finish so the logo is back at scale 1.0
        let waitForCycle = timeUntilCycleEnd()
        if waitForCycle > 0 {
            try? await Task.sleep(for: .seconds(waitForCycle))
        }
        
        isDismissing = true
        
        try? await Task.sleep(for: .milliseconds(50))
        
        withAnimation(.easeIn(duration: 0.5)) {
            logoOpacity = 0
            exitScale = 1.08
        }
        
        try? await Task.sleep(for: .seconds(0.2))
        withAnimation(.easeIn(duration: 0.3)) {
            backgroundOpacity = 0
        }
        
        try? await Task.sleep(for: .seconds(0.3))
        isVisible = false
    }
}
