//
//  PulseApp.swift
//  Pulse
//
//  Created by lukasaberg on 2/5/26.
//

import SwiftUI

@main
struct PulseApp: App {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("hasSeenWelcomeTour") private var hasSeenWelcomeTour = false
    @StateObject private var authViewModel = AuthViewModel()
    
    init() {
            // Initialize WatchConnectivity
                _ = WorkoutSyncManager.shared
        
            // Tab bar appearance
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithOpaqueBackground()
            tabBarAppearance.backgroundColor = UIColor(Color.appSurface)
            
            // Selected item color (orange)
            tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.appAccent)
            tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor(Color.appAccent)
            ]
            
            // Unselected item color (gray)
            tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.appText.opacity(0.5))
            tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor(Color.appText.opacity(0.5))
            ]
            
            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            
            // Navigation bar appearance
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color.appBackground)
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
            appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
            
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
        }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if !hasSeenOnboarding {
                    OnboardingView(authViewModel: authViewModel)
                        .onDisappear {
                            hasSeenOnboarding = true
                        }
                } else if authViewModel.isAuthenticated {
                    HomeView(authViewModel: authViewModel)
                        .environmentObject(authViewModel)
                        .fullScreenCover(isPresented: Binding(
                            get: { !hasSeenWelcomeTour },
                            set: { hasSeenWelcomeTour = !$0}
                        )) {
                            WelcomeTourView()
                                .onDisappear {
                                    hasSeenWelcomeTour = true
                                }
                        }
                    
                } else {
                    AuthSelectionView(authViewModel: authViewModel)
                        .environmentObject(authViewModel)
                }
            }
            .id(authViewModel.isAuthenticated)
        }
    }
}
