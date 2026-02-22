//
//  PrivacyPolicyView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-22.
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("This Privacy Policy describes how Pulse collects, uses, and protects your information.")
                        .foregroundStyle(Color.appText)
                    
                    sectionTitle("Information We Collect")
                    sectionText("We collect information you provide when creating an account (name, email) and workout data you enter into the app.")
                    
                    sectionTitle("How We Use Your Information")
                    sectionText("Your information is used to provide and improve the app experience, including workout tracking, progress monitoring, and personalized features.")
                    
                    sectionTitle("Data Storage")
                    sectionText("Your data is securely stored using Supabase and is encrypted both in transit and at rest.")
                    
                    sectionTitle("Data Sharing")
                    sectionText("We do not sell or share your personal information with third parties. Your workout data is private and only visible to you.")
                    
                    sectionTitle("Your Rights")
                    sectionText("You have the right to access, modify, or delete your data at any time through the app settings.")
                    
                    sectionTitle("Apple Watch Data")
                    sectionText("Workout data synced with your Apple Watch is stored locally on your devices and in our secure database.")
                    
                    sectionTitle("Contact Us")
                    sectionText("If you have questions about this Privacy Policy, please contact us at support@pulsefitness.io")
                    
                    Text("Last updated: \(Date().formatted(date: .long, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(Color.appText.opacity(0.5))
                        .padding(.top, 20)
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle("Privacy Policy")
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
