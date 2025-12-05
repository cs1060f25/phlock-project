//
//  phlockApp.swift
//  phlock
//
//  Created by Woon Lee on 10/24/25.
//

import SwiftUI
import Supabase
import UserNotifications
import GoogleSignIn

// MARK: - App Delegate for Push Notifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: - Remote Notification Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationService.shared.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushNotificationService.shared.didFailToRegisterForRemoteNotifications(withError: error)
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task {
            let options = await PushNotificationService.shared.willPresent(notification: notification)
            completionHandler(options)
        }
    }

    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task {
            await PushNotificationService.shared.didReceive(response: response)
            completionHandler()
        }
    }
}

@main
struct phlockApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authState = AuthenticationState()

    // DEBUG: Set to true to force clear session on launch (for testing onboarding)
    private static let forceSignOutOnLaunch = false

    init() {
        // DEBUG: Clear keychain session if flag is set
        if Self.forceSignOutOnLaunch {
            PhlockSupabaseClient.shared.clearKeychainSession()
            UserDefaults.standard.set(false, forKey: "isOnboardingComplete")
            print("⚠️ DEBUG: Forced sign out on launch")
        }


        // Configure navigation bar to use Lora font
        configureNavigationBarAppearance()
    }

    private func configureNavigationBarAppearance() {
        // Create Lora fonts for navigation bar titles
        let loraRegular = UIFont(name: "Lora-SemiBold", size: 17) ?? UIFont.systemFont(ofSize: 17)
        let loraLarge = UIFont(name: "Lora-Bold", size: 34) ?? UIFont.boldSystemFont(ofSize: 34)

        // Configure standard navigation bar appearance (inline titles)
        let standardAppearance = UINavigationBarAppearance()
        standardAppearance.configureWithDefaultBackground()
        standardAppearance.titleTextAttributes = [
            .font: loraRegular
        ]

        // Configure large title appearance
        let largeTitleAppearance = UINavigationBarAppearance()
        largeTitleAppearance.configureWithDefaultBackground()
        largeTitleAppearance.largeTitleTextAttributes = [
            .font: loraLarge
        ]
        largeTitleAppearance.titleTextAttributes = [
            .font: loraRegular
        ]

        // Apply to all navigation bars
        UINavigationBar.appearance().standardAppearance = standardAppearance
        UINavigationBar.appearance().compactAppearance = standardAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = largeTitleAppearance
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .environmentObject(authState)
                .onOpenURL { url in
                    // Try Google Sign-In first
                    if GIDSignIn.sharedInstance.handle(url) {
                        print("✅ Google Sign-In callback handled: \(url)")
                        return
                    }

                    // Handle OAuth callback from Supabase
                    Task {
                        do {
                            try await PhlockSupabaseClient.shared.client.auth.session(from: url)
                            print("✅ OAuth callback handled: \(url)")
                        } catch {
                            print("❌ Failed to handle OAuth callback: \(error)")
                        }
                    }
                }
        }
    }
}
