//
//  SplashOverlay.swift
//  Pulse
//

import SwiftUI

/// Loading screen shown after sign-in while dashboard data loads.
/// Uses the same background color and logo as the iOS launch screen.
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
                .frame(width: 120, height: 120)
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
