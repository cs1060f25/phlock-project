import Foundation
import UserNotifications
import UIKit
import Combine
import Supabase

/// Device token payload for Supabase upsert
private struct DeviceTokenPayload: Encodable, Sendable {
    let user_id: String
    let device_token: String
    let platform: String
    let is_sandbox: Bool
    let updated_at: String
}

/// Service for handling push notifications
/// Manages APNs registration and token storage in Supabase
class PushNotificationService: NSObject, ObservableObject {
    static let shared = PushNotificationService()

    @MainActor @Published var isAuthorized = false
    @MainActor @Published var deviceToken: String?

    private let supabase = PhlockSupabaseClient.shared.client

    private override init() {
        super.init()
    }

    // MARK: - Request Permission

    /// Request permission to send push notifications
    @MainActor
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            self.isAuthorized = granted

            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }

            return granted
        } catch {
            print("❌ Push notification authorization failed: \(error)")
            return false
        }
    }

    /// Check current authorization status
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Remote Notification Registration

    /// Called when APNs registration succeeds
    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 APNs device token: \(tokenString)")

        Task { @MainActor in
            self.deviceToken = tokenString
        }

        // Store the token in Supabase
        Task {
            await storeDeviceToken(tokenString)
        }
    }

    /// Called when APNs registration fails
    func didFailToRegisterForRemoteNotifications(withError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }

    // MARK: - Store Token in Supabase

    /// Store the device token in Supabase for this user
    private func storeDeviceToken(_ token: String) async {
        do {
            // Get current user ID
            guard let user = try await AuthServiceV3.shared.currentUser else {
                print("⚠️ No user logged in, skipping device token registration")
                return
            }

            // Determine if this is a sandbox (development/TestFlight) build
            #if DEBUG
            let isSandbox = true
            #else
            // Check if running in TestFlight
            let isSandbox = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
            #endif

            // Use upsert to insert or update the device token
            let payload = DeviceTokenPayload(
                user_id: user.id.uuidString,
                device_token: token,
                platform: "ios",
                is_sandbox: isSandbox,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )

            try await supabase
                .from("device_tokens")
                .upsert(payload, onConflict: "device_token,platform")
                .execute()

            print("✅ Device token registered successfully")

        } catch {
            print("❌ Failed to store device token: \(error)")
        }
    }

    // MARK: - Handle Notifications

    /// Handle notification received while app is in foreground
    func willPresent(notification: UNNotification) async -> UNNotificationPresentationOptions {
        // Show banner and play sound even when app is in foreground
        return [.banner, .sound, .badge]
    }

    /// Handle notification tap
    func didReceive(response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        print("📱 Notification tapped: \(userInfo)")

        // Handle different notification types
        if let type = userInfo["type"] as? String {
            await handleNotificationAction(type: type, userInfo: userInfo)
        }
    }

    /// Handle notification actions based on type
    @MainActor
    private func handleNotificationAction(type: String, userInfo: [AnyHashable: Any]) async {
        switch type {
        case "friend_request":
            // Navigate to friends tab
            NotificationCenter.default.post(name: .navigateToFriends, object: nil)

        case "daily_song":
            // Navigate to discover tab
            NotificationCenter.default.post(name: .navigateToDiscover, object: nil)

        case "friend_picked":
            // Navigate to phlock tab to see friend's pick
            NotificationCenter.default.post(name: .navigateToPhlock, object: nil)

        default:
            print("Unknown notification type: \(type)")
        }
    }

    // MARK: - Update Badge Count

    /// Update the app badge count
    @MainActor
    func updateBadgeCount(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count) { error in
            if let error = error {
                print("❌ Failed to update badge: \(error)")
            }
        }
    }

    /// Clear badge count
    @MainActor
    func clearBadge() {
        updateBadgeCount(0)
    }

    // MARK: - Unregister

    /// Remove device token when user signs out
    func unregisterDeviceToken() async {
        let token = await MainActor.run { self.deviceToken }
        guard let token = token else { return }

        do {
            try await supabase
                .from("device_tokens")
                .delete()
                .eq("device_token", value: token)
                .execute()

            await MainActor.run {
                self.deviceToken = nil
            }

            print("✅ Device token unregistered")
        } catch {
            print("❌ Failed to unregister device token: \(error)")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let navigateToFriends = Notification.Name("navigateToFriends")
    static let navigateToDiscover = Notification.Name("navigateToDiscover")
    static let navigateToPhlock = Notification.Name("navigateToPhlock")
}
