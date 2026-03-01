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

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let POSTHOG_API_KEY = "phc_Ot8pm2ingc4NkRMyD7aR1uv6k4Fyg0hNrtnbQtEuQNK"
        let POSTHOG_HOST = "https://eu.i.posthog.com"

        let config = PostHogConfig(apiKey: POSTHOG_API_KEY, host: POSTHOG_HOST)
        PostHogSDK.shared.setup(config)

        // Configure RevenueCat
        SubscriptionManager.shared.configure()

        return true
    }
}

struct IdentifiableString: Identifiable {
    let id = UUID()
    let value: String
}

struct DismissAllSheetsKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var dismissAllSheets: () -> Void {
        get { self[DismissAllSheetsKey.self] }
        set { self[DismissAllSheetsKey.self] = newValue }
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
    @State private var showPasswordReset = false
    @State private var recoveryCode: IdentifiableString?
    @State private var showPostSignInGuide = false
    
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
                if authViewModel.isAuthenticated {
                    HomeView(authViewModel: authViewModel)
                        .environmentObject(authViewModel)
                        .overlay {
                            if showPostSignInGuide {
                                PostSignInGuideView(isPresented: $showPostSignInGuide)
                            }
                        }
                        .onChange(of: authViewModel.isAuthenticated) { _, newValue in
                            // Show guide ONLY on first launch after user authenticates
                            if newValue && !hasCompletedFirstLaunchGuide {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showPostSignInGuide = true
                                }
                            }
                        }
                        .onAppear {
                            // Also check on appear in case already authenticated
                            if authViewModel.isAuthenticated && !hasCompletedFirstLaunchGuide {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showPostSignInGuide = true
                                }
                            }
                        }
                } else {
                    AuthSelectionView(authViewModel: authViewModel)
                        .environmentObject(authViewModel)
                }
            }
            .id(authViewModel.isAuthenticated)
            .environmentObject(themeManager)
            .environmentObject(syncService)
            .environmentObject(subscriptionManager)
            .preferredColorScheme(themeManager.selectedTheme.colorScheme)
            .task(id: authViewModel.isAuthenticated) {
                if authViewModel.isAuthenticated {
                    await subscriptionManager.syncUser()
                } else {
                    await subscriptionManager.logout()
                }
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .sheet(item: $recoveryCode) { codeWrapper in
                        ResetPasswordInAppView(recoveryCode: codeWrapper.value)
            }
            .sheet(isPresented: $authViewModel.showRecoveryPrompt) {
                ResetPasswordInAppView(recoveryCode: nil)
            }
        }
        .modelContainer(modelContainer)
    }
    
    func handleDeepLink(_ url: URL) {
        print("📱 Deep link received: \(url)")
        
        if url.path.contains("reset-password") {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let code = components?.queryItems?.first(where: { $0.name == "code" })?.value {
                print("📱 Code extracted: \(code)")
                
                // Mark that we're in recovery mode
                UserDefaults.standard.set(true, forKey: "pendingPasswordReset")
                
                recoveryCode = IdentifiableString(value: code)
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    rootViewController.dismiss(animated: false)
                }
                
                showPasswordReset = true
            }
        }
    }
}
