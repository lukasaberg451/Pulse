//
//  SplashOverlay.swift
//  Pulse
//

import SwiftUI

struct SplashOverlay: View {
    let isInitializing: Bool
    
    @State private var isVisible = true
    @State private var appearTime = Date()
    
    private let minimumDisplayTime: TimeInterval = 2.0
    
    var body: some View {
        if isVisible {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
            }
            .preferredColorScheme(.dark)
            .transition(.opacity)
            .onAppear {
                appearTime = Date()
                if !isInitializing {
                    dismiss()
                }
            }
            .onChange(of: isInitializing) { _, newValue in
                guard !newValue else { return }
                dismiss()
            }
        }
    }
    
    private func dismiss() {
        let elapsed = Date().timeIntervalSince(appearTime)
        let remaining = max(minimumDisplayTime - elapsed, 0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining) {
            withAnimation(.easeOut(duration: 0.4)) {
                isVisible = false
            }
        }
    }
}
