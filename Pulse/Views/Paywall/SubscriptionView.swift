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
    @State private var isPurchasing = false
    @State private var safariURL: URL?
    
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
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // Pricing & CTA
                        VStack(spacing: 12) {
                            if subscriptionManager.isLoading && !isPurchasing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .appAccent))
                                    .padding(.vertical, 30)
                            } else if let package = subscriptionManager.currentOffering?.availablePackages.first {
                                if let intro = package.storeProduct.introductoryDiscount,
                                   intro.paymentMode == .freeTrial {
                                    Text("\(intro.subscriptionPeriod.trialDescription) free, then \(package.localizedPriceString)/month")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.appText)
                                } else {
                                    Text("Unlock Pro for \(package.localizedPriceString)/month")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.appText)
                                }
                                
                                Button {
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
                                            let hasFreeTrial = package.storeProduct.introductoryDiscount?.paymentMode == .freeTrial
                                            Text(hasFreeTrial ? "Start Free Trial" : "Continue")
                                                .font(.headline)
                                        }
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.appAccent)
                                    .foregroundStyle(Color.appText)
                                    .cornerRadius(12)
                                }
                                .disabled(isPurchasing)
                                
                                if package.storeProduct.introductoryDiscount?.paymentMode == .freeTrial {
                                    Text("Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.")
                                        .font(.caption2)
                                        .foregroundStyle(Color.appText.opacity(0.4))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 4)
                                }
                            }
                        }
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
                            Button("Terms of Use") {
                                safariURL = URL(string: "https://pulsefitness.io/terms.html")
                            }
                            .font(.caption2)
                            .foregroundStyle(Color.appText.opacity(0.4))
                            
                            Text("·")
                                .foregroundStyle(Color.appText.opacity(0.3))
                            
                            Button("Privacy Policy") {
                                safariURL = URL(string: "https://pulsefitness.io/privacy.html")
                            }
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
            }
            .sheet(item: $safariURL) { url in
                SafariView(url: url)
                    .ignoresSafeArea()
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
                RoundedRectangle(cornerRadius: 12)
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

// MARK: - Trial Period Formatting

private extension SubscriptionPeriod {
    var trialDescription: String {
        switch unit {
        case .day:
            return value == 1 ? "1 day" : "\(value) days"
        case .week:
            return value == 1 ? "7 days" : "\(value) weeks"
        case .month:
            return value == 1 ? "1 month" : "\(value) months"
        case .year:
            return value == 1 ? "1 year" : "\(value) years"
        }
    }
}
