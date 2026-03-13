//
//  SheetContentTransition.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-03-12.
//

import SwiftUI

struct SheetContentTransition: ViewModifier {
    var delay: TimeInterval

    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 16)
            .onAppear {
                guard !isVisible else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                        isVisible = true
                    }
                }
            }
    }
}

extension View {
    func sheetContentTransition(delay: TimeInterval = 0.25) -> some View {
        modifier(SheetContentTransition(delay: delay))
    }
}
