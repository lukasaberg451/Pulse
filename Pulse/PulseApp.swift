//
//  PulseApp.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/5/26.
//

import SwiftUI
import SwiftData
import PostHog
import UIKit
import RevenueCat
import Sentry

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        guard let posthogAPIKey = Bundle.main.object(forInfoDictionaryKey: "POSTHOG_API_KEY") as? String,
              let posthogHost = Bundle.main.object(forInfoDictionaryKey: "POSTHOG_HOST") as? String else {
            fatalError("Missing PostHog configuration in Info.plist. Ensure Secrets.xcconfig is set up correctly.")
        }

        let config = PostHogConfig(apiKey: posthogAPIKey, host: posthogHost)
        PostHogSDK.shared.setup(config)

        // Configure RevenueCat
        SubscriptionManager.shared.configure()

        // Configure Sentry
        if let sentryDSN = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String {
            SentrySDK.start { options in
                options.dsn = sentryDSN
                options.debug = false
                options.tracesSampleRate = 0.2
                options.attachScreenshot = false
                options.attachViewHierarchy = false
            }
        }

        return true
    }
}



struct DismissAllSheetsKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

private struct SplashDismissedKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var dismissAllSheets: () -> Void {
        get { self[DismissAllSheetsKey.self] }
        set { self[DismissAllSheetsKey.self] = newValue }
    }

    var splashDismissed: Bool {
        get { self[SplashDismissedKey.self] }
        set { self[SplashDismissedKey.self] = newValue }
    }
}

@main
struct PulseApp: App {
    // Connect the AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage("hasCompletedFirstLaunchGuide") private var hasCompletedFirstLaunchGuide = false
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var syncService = WorkoutSyncService.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var unitManager = UnitManager.shared
    @StateObject private var tourManager = OnboardingTourManager()

    @State private var showPostLoginLoading = false
    @State private var showPostLogoutLoading = false
    @State private var showSplash = true
    @State private var selectedTab: HomeTab = .dashboard
    
    // SwiftData model container for offline support
    let modelContainer: ModelContainer
    
    init() {
        // Initialize SwiftData model container for offline support
        // Only store user-created data: workout sessions, sets, routines, and routine exercises
        // Exercise browsing requires online connectivity
        do {
            let schema = Schema([
                // Workout models - user-created data
                LocalWorkoutSession.self,
                LocalWorkoutSet.self,
                // Routine models - user's routines only
                LocalRoutine.self,
                LocalRoutineExercise.self,
                // Exercise cache - only exercises used in user's routines
                LocalExercise.self
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
        
        // Initialize WatchConnectivity
        _ = WorkoutSyncManager.shared
        
        // Navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.appBackground)
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.appText)]
        appearance.titleTextAttributes = [.foregroundColor: UIColor(Color.appText)]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().compactScrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(Color.appAccent)
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    HomeView(authViewModel: authViewModel, selectedTab: $selectedTab)
                        .environmentObject(authViewModel)
                        .environmentObject(tourManager)
                        .overlay {
                            if showPostLoginLoading {
                                PostLoginLoadingView(isVisible: $showPostLoginLoading)
                            }
                        }
                        .onChange(of: authViewModel.isAuthenticated) { _, newValue in
                            // Start spotlight tour on first launch after user authenticates
                            if newValue && !hasCompletedFirstLaunchGuide {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    hasCompletedFirstLaunchGuide = true
                                    tourManager.start()
                                }
                            }
                        }
                        .onAppear {
                            if authViewModel.isAuthenticated && !hasCompletedFirstLaunchGuide {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    hasCompletedFirstLaunchGuide = true
                                    tourManager.start()
                                }
                            }
                        }
                } else {
                    AuthSelectionView(authViewModel: authViewModel)
                        .environmentObject(authViewModel)
                        .overlay {
                            if showPostLogoutLoading {
                                PostLoginLoadingView(isVisible: $showPostLogoutLoading)
                            }
                        }
                }
            }
            .id(authViewModel.isAuthenticated)
            .environmentObject(themeManager)
            .environmentObject(syncService)
            .environmentObject(subscriptionManager)
            .environmentObject(healthKitManager)
            .environmentObject(unitManager)
            .preferredColorScheme(themeManager.selectedTheme.colorScheme)
            .environment(\.splashDismissed, !showSplash && !showPostLoginLoading)
            .overlay {
                if showSplash {
                    SplashOverlay(
                        isInitializing: authViewModel.isInitializing,
                        isVisible: $showSplash
                    )
                    .ignoresSafeArea()
                }
            }
            .onChange(of: authViewModel.isAuthenticated) { oldValue, isAuthenticated in
                if !authViewModel.isInitializing {
                    if isAuthenticated && !oldValue {
                        // User just signed in
                        selectedTab = .dashboard
                        showPostLoginLoading = true
                    } else if !isAuthenticated && oldValue {
                        // User just signed out
                        showPostLogoutLoading = true
                    }
                }
                Task {
                    if isAuthenticated {
                        await subscriptionManager.syncUser()
                    } else {
                        await subscriptionManager.logout()
                    }
                    WorkoutSyncManager.shared.syncProStatus(subscriptionManager.isProUser)
                }
            }

        }
        .modelContainer(modelContainer)
    }
    

}
