//
//  SubscriptionView.swift
//  Pulse
//
//  Created by Lukas Åberg on 3/1/26.
//

import SwiftUI
import RevenueCat

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Hero section
                        VStack(spacing: 16) {
                            ZStack {
                                Image(.pulseProLogo)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 140, height: 80)
                            }
                            .padding(.top, 10)
                            .padding(.bottom, 20)
                            
                            Text("Upgrade to Pro")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(Color.appText)
                            
                            Text("Take your training to the next level")
                                .font(.body)
                                .foregroundStyle(Color.appText.opacity(0.6))
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 32)
                        
                        // Features
                        VStack(spacing: 0) {
                            SubscriptionFeatureRow(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "Advanced Analytics",
                                subtitle: "Detailed progress insights and trends"
                            )
                            
                            Divider()
                                .background(Color.appText.opacity(0.1))
                                .padding(.leading, 60)
                            
                            SubscriptionFeatureRow(
                                icon: "clock.arrow.circlepath",
                                title: "Unlimited History",
                                subtitle: "Access all your past workouts"
                            )
                            
                            Divider()
                                .background(Color.appText.opacity(0.1))
                                .padding(.leading, 60)
                            
                            SubscriptionFeatureRow(
                                icon: "list.bullet",
                                title: "Unlimited Routines",
                                subtitle: "Create and track your own routines"
                            )
                            
                            Divider()
                                .background(Color.appText.opacity(0.1))
                                .padding(.leading, 60)
                            
                            SubscriptionFeatureRow(
                                icon: "applewatch.and.arrow.forward",
                                title: "Apple Watch",
                                subtitle: "Log workouts straight from your wrist"
                            )
                        }
                        .background(Color.appSurface)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        
                        // Pricing section
                        VStack(spacing: 16) {
                            if subscriptionManager.isLoading && !isPurchasing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .appAccent))
                                    .padding(.vertical, 30)
                            } else if let offering = subscriptionManager.currentOffering {
                                ForEach(offering.availablePackages) { package in
                                    SubscriptionPackageCard(
                                        package: package,
                                        isSelected: selectedPackage?.identifier == package.identifier
                                    ) {
                                        let impactLight = UIImpactFeedbackGenerator(style: .light)
                                        impactLight.impactOccurred()
                                        selectedPackage = package
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 24)
                        
                        // CTA button
                        Button {
                            guard let package = selectedPackage else { return }
                            isPurchasing = true
                            Task {
                                let success = await subscriptionManager.purchase(package)
                                isPurchasing = false
                                if success {
                                    dismiss()
                                }
                            }
                        } label: {
                            HStack {
                                Spacer()
                                if isPurchasing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .appText))
                                } else {
                                    Text("Continue")
                                        .font(.headline)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(selectedPackage != nil ? Color.appAccent : Color.appAccent.opacity(0.3))
                            .foregroundStyle(Color.appText)
                            .cornerRadius(10)
                        }
                        .disabled(selectedPackage == nil || isPurchasing)
                        .padding(.horizontal)
                        .padding(.top, 24)
                        
                        // Error
                        if let error = subscriptionManager.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.top, 8)
                                .padding(.horizontal)
                        }
                        
                        // Restore
                        Button {
                            Task {
                                await subscriptionManager.restorePurchases()
                                if subscriptionManager.isProUser {
                                    dismiss()
                                }
                            }
                        } label: {
                            Text("Restore Purchases")
                                .font(.subheadline)
                                .foregroundStyle(Color.appAccent)
                        }
                        .padding(.top, 16)
                        
                        // Legal
                        HStack(spacing: 16) {
                            Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                                .font(.caption2)
                                .foregroundStyle(Color.appText.opacity(0.4))
                            
                            Text("·")
                                .foregroundStyle(Color.appText.opacity(0.3))
                            
                            Link("Privacy Policy", destination: URL(string: "https://www.apple.com/legal/privacy/")!)
                                .font(.caption2)
                                .foregroundStyle(Color.appText.opacity(0.4))
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.appText.opacity(0.6))
                    }
                }
            }
            .task {
                await subscriptionManager.fetchOfferings()
                if selectedPackage == nil {
                    selectedPackage = subscriptionManager.currentOffering?.availablePackages.first
                }
            }
        }
        .presentationBackground(Color.appBackground)
    }
}

// MARK: - Feature Row

private struct SubscriptionFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.appText)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.appText.opacity(0.5))
            }
            
            Spacer()
            
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.appAccent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Package Card

private struct SubscriptionPackageCard: View {
    let package: Package
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.appAccent : Color.appText.opacity(0.2), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.appAccent)
                            .frame(width: 14, height: 14)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(package.storeProduct.localizedTitle)
                        .font(.headline)
                        .foregroundStyle(Color.appText)
                    
                    Text(package.storeProduct.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(Color.appText.opacity(0.5))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(package.localizedPriceString)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.appText)
                    
                    Text("/month")
                        .font(.caption2)
                        .foregroundStyle(Color.appText.opacity(0.4))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.appSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.appAccent : Color.clear, lineWidth: 2)
                    )
            )
        }
    }
}
