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
    
    // Breathe animation (timer-driven to allow freeze without jump)
    private let breatheDelay: TimeInterval = 0.3
    private let breatheHalfCycle: TimeInterval = 1.4
    private let breatheAmount: CGFloat = 0.10
    @State private var breatheStartTime: Date? = nil
    @State private var timer: Timer? = nil
    @State private var breatheScale: CGFloat = 1.0
    
    // Exit animation
    @State private var frozenScale: CGFloat? = nil
    @State private var logoOpacity: Double = 1
    @State private var backgroundOpacity: Double = 1
    
    private var logoScale: CGFloat {
        frozenScale ?? breatheScale
    }
    
    var body: some View {
        ZStack {
            Color("LoadingBackground")
                .opacity(backgroundOpacity)
            
            Image("LoadingLogo")
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
        }
        .ignoresSafeArea()
        .onAppear {
            appearTime = Date()
            startBreathTimer()
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
    
    private func startBreathTimer() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(breatheDelay))
            guard frozenScale == nil else { return }
            breatheStartTime = Date()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
                Task { @MainActor in
                    updateBreatheScale()
                }
            }
        }
    }
    
    @MainActor
    private func updateBreatheScale() {
        guard let start = breatheStartTime, frozenScale == nil else { return }
        let elapsed = Date().timeIntervalSince(start)
        let fullCycle = breatheHalfCycle * 2
        let t = elapsed.truncatingRemainder(dividingBy: fullCycle)
        let normalized = t / fullCycle
        let cosValue = (1.0 - cos(normalized * 2.0 * .pi)) / 2.0
        breatheScale = 1.0 + breatheAmount * cosValue
    }
    
    private func dismiss() {
        let elapsed = Date().timeIntervalSince(appearTime)
        let remaining = max(minimumDisplayTime - elapsed, 0)
        
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(remaining))
            
            // Freeze at the exact current scale - no jump
            timer?.invalidate()
            timer = nil
            frozenScale = breatheScale
            
            // Fade out the logo with a slight scale-up from frozen position
            withAnimation(.easeIn(duration: 0.5)) {
                logoOpacity = 0
                frozenScale = (frozenScale ?? 1.0) + 0.04
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
///
/// Uses a manual timer-driven breathe animation so the scale can be
/// frozen at its exact current value when dismissing - no jump.
struct PostLoginLoadingView: View {
    @Binding var isVisible: Bool
    
    private let displayDuration: TimeInterval = 3.5
    private let breatheDelay: TimeInterval = 0.3
    private let breatheHalfCycle: TimeInterval = 1.4
    private let breatheAmount: CGFloat = 0.10
    
    // Timer-driven breathe
    @State private var breatheStartTime: Date? = nil
    @State private var timer: Timer? = nil
    @State private var breatheScale: CGFloat = 1.0
    
    // Exit animation
    @State private var frozenScale: CGFloat? = nil
    @State private var logoOpacity: Double = 1
    @State private var backgroundOpacity: Double = 1
    
    /// The effective logo scale: once frozen, exit animation drives it.
    private var logoScale: CGFloat {
        frozenScale ?? breatheScale
    }
    
    var body: some View {
        ZStack {
            Color.appBackground
                .opacity(backgroundOpacity)
            LinearGradient.dashboardBackground
                .opacity(backgroundOpacity)
            
            Image("LoadingLogo")
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
        }
        .ignoresSafeArea()
        .task {
            // Start breathing after initial delay
            try? await Task.sleep(for: .seconds(breatheDelay))
            startBreathTimer()
            
            // Wait for display duration (minus the delay already spent)
            try? await Task.sleep(for: .seconds(displayDuration - breatheDelay))
            await dismiss()
        }
    }
    
    private func startBreathTimer() {
        breatheStartTime = Date()
        // ~60 fps timer to update breathe scale
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            Task { @MainActor in
                updateBreatheScale()
            }
        }
    }
    
    @MainActor
    private func updateBreatheScale() {
        guard let start = breatheStartTime, frozenScale == nil else { return }
        let elapsed = Date().timeIntervalSince(start)
        let fullCycle = breatheHalfCycle * 2
        let t = elapsed.truncatingRemainder(dividingBy: fullCycle)
        
        // Ease in-out using cosine: goes 1.0 → 1.10 → 1.0 over one full cycle
        let normalized = t / fullCycle
        let cosValue = (1.0 - cos(normalized * 2.0 * .pi)) / 2.0
        breatheScale = 1.0 + breatheAmount * cosValue
    }
    
    @MainActor
    private func dismiss() async {
        // Freeze at the exact current scale - no jump
        timer?.invalidate()
        timer = nil
        frozenScale = breatheScale
        
        // Fade out the logo with a slight scale-up from the frozen position
        withAnimation(.easeIn(duration: 0.5)) {
            logoOpacity = 0
            frozenScale = (frozenScale ?? 1.0) + 0.04
        }
        
        try? await Task.sleep(for: .seconds(0.2))
        withAnimation(.easeIn(duration: 0.3)) {
            backgroundOpacity = 0
        }
        
        try? await Task.sleep(for: .seconds(0.3))
        isVisible = false
    }
}
