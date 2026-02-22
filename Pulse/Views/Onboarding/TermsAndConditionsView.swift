//
//  TermsAndConditionsView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-22.
//

import SwiftUI

struct TermsAndConditionsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("By using Pulse, you agree to the following terms:")
                        .foregroundStyle(Color.appText)
                    
                    sectionTitle("1. Acceptance of Terms")
                    sectionText("By accessing and using Pulse, you accept and agree to be bound by the terms and provision of this agreement.")
                    
                    sectionTitle("2. Use License")
                    sectionText("Permission is granted to use Pulse for personal, non-commercial fitness tracking purposes.")
                    
                    sectionTitle("3. User Account")
                    sectionText("You are responsible for maintaining the confidentiality of your account and password.")
                    
                    sectionTitle("4. Privacy")
                    sectionText("Your use of Pulse is also governed by our Privacy Policy.")
                    
                    sectionTitle("5. Disclaimer")
                    sectionText("Pulse is provided 'as is' without warranty of any kind. Always consult with a healthcare professional before starting any fitness program.")
                    
                    sectionTitle("6. Limitation of Liability")
                    sectionText("Pulse shall not be liable for any damages arising from the use or inability to use the app.")
                    
                    sectionTitle("7. Changes to Terms")
                    sectionText("We reserve the right to modify these terms at any time. Continued use of the app constitutes acceptance of modified terms.")
                    
                    Text("Last updated: \(Date().formatted(date: .long, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(Color.appText.opacity(0.5))
                        .padding(.top, 20)
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle("Terms & Conditions")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appAccent)
                }
            }
        }
        .presentationBackground(Color.appBackground)
    }
    
    func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(Color.appText)
            .padding(.top, 8)
    }
    
    func sectionText(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(Color.appText.opacity(0.8))
    }
}
