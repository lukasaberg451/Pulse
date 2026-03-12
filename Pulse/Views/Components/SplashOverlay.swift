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
    @State private var breatheScale: CGFloat = 1.0
    
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
        // Start breathe after 0.3s delay
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            guard !isDismissing else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                breatheScale = 1.06
            }
        }
    }
    
    private func dismiss() {
        let elapsed = Date().timeIntervalSince(appearTime)
        let remaining = max(minimumDisplayTime - elapsed, 0)
        
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(remaining))
            
            // Stop breathe animation cleanly before exit
            isDismissing = true
            
            // Small delay to let state settle
            try? await Task.sleep(for: .milliseconds(50))
            
            // Logo scales up to 1.08 and fades out over 0.5s
            withAnimation(.easeIn(duration: 0.5)) {
                logoOpacity = 0
                exitScale = 1.08
            }
            
            // Background fades out slightly after, over 0.3s
            try? await Task.sleep(for: .seconds(0.2))
            withAnimation(.easeIn(duration: 0.3)) {
                backgroundOpacity = 0
            }
            
            // Wait for background fade to complete, then hide
            try? await Task.sleep(for: .seconds(0.3))
            isVisible = false
        }
    }
}

/// Loading screen shown after sign-in/sign-out transitions.
struct PostLoginLoadingView: View {
    @Binding var isVisible: Bool
    
    private let displayDuration: TimeInterval = 2.0
    
    var body: some View {
        ZStack {
            Color.appBackground
            LinearGradient.dashboardBackground
            
            Image("LoadingLogo")
        }
        .ignoresSafeArea()
        .task {
            try? await Task.sleep(for: .seconds(displayDuration))
            withAnimation(.easeOut(duration: 0.4)) {
                isVisible = false
            }
        }
    }
}
