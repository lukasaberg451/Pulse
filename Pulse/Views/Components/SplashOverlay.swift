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
    private let minimumDisplayTime: TimeInterval = 2.0
    
    var body: some View {
        ZStack {
            Color("LoadingBackground")
            
            Image("LoadingLogo")
        }
        .ignoresSafeArea()
        .onAppear {
            appearTime = Date()
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
    
    private func dismiss() {
        let elapsed = Date().timeIntervalSince(appearTime)
        let remaining = max(minimumDisplayTime - elapsed, 0)
        
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(remaining))
            withAnimation(.easeOut(duration: 0.4)) {
                isVisible = false
            }
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
            
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
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
