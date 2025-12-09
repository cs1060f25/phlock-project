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

        // Store the token in Supabase with retry
        Task {
            await storeDeviceTokenWithRetry(tokenString)
        }
    }

    /// Pending token to store when user becomes authenticated
    private var pendingDeviceToken: String?

    /// Called when APNs registration fails
    func didFailToRegisterForRemoteNotifications(withError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }

    // MARK: - Store Token in Supabase

    /// Store the device token with retry logic for when user is not yet authenticated
    private func storeDeviceTokenWithRetry(_ token: String) async {
        // Try immediately first
        let success = await storeDeviceToken(token)

        if !success {
            // Store as pending and retry a few times with delays
            pendingDeviceToken = token
            print("⏳ Device token pending, will retry...")

            // Retry up to 5 times with increasing delays (1s, 2s, 3s, 4s, 5s)
            for attempt in 1...5 {
                try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)

                if await storeDeviceToken(token) {
                    pendingDeviceToken = nil
                    return
                }
                print("⏳ Device token retry \(attempt)/5 failed, will try again...")
            }

            print("⚠️ Could not store device token after 5 retries. Call storePendingTokenIfNeeded() after auth.")
        }
    }

    /// Store the device token in Supabase for this user
    /// Returns true if successful, false otherwise
    @discardableResult
    private func storeDeviceToken(_ token: String) async -> Bool {
        do {
            // Get current user ID
            guard let user = try await AuthServiceV3.shared.currentUser else {
                print("⚠️ No user logged in, cannot store device token")
                return false
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

            print("✅ Device token registered successfully for user: \(user.id)")
            return true

        } catch {
            print("❌ Failed to store device token: \(error)")
            return false
        }
    }

    /// Call this after user authentication to store any pending device token
    func storePendingTokenIfNeeded() async {
        guard let token = pendingDeviceToken else { return }

        print("📱 Attempting to store pending device token...")
        if await storeDeviceToken(token) {
            pendingDeviceToken = nil
        }
    }

    /// Ensures device token is registered for push notifications
    /// Call this after user authentication to handle the case where notifications
    /// were already authorized but token wasn't stored (e.g., user updated app)
    func ensureDeviceTokenRegistered() async {
        // Check if we already have a token in memory
        let existingToken = await MainActor.run { self.deviceToken }
        if let token = existingToken {
            // Try to store it (will succeed if not already in DB)
            let success = await storeDeviceToken(token)
            if success {
                print("✅ Existing device token registered")
            }
            return
        }

        // Check notification authorization and re-register if authorized
        let status = await checkAuthorizationStatus()
        if status == .authorized {
            print("📱 Notifications authorized, re-registering for remote notifications...")
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } else if status == .notDetermined {
            print("📱 Notification permission not determined, skipping re-registration")
        } else {
            print("📱 Notifications not authorized (status: \(status.rawValue)), skipping re-registration")
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
        // Extract deep link data
        let actorId = (userInfo["actor_id"] as? String).flatMap { UUID(uuidString: $0) }
        let shareId = (userInfo["share_id"] as? String).flatMap { UUID(uuidString: $0) }

        switch type {
        // Social/follow notifications - navigate to notifications tab
        case "new_follower", "follow_request_received", "follow_request_accepted", "friend_joined":
            NotificationCenter.default.post(name: .navigateToNotifications, object: nil)

        // Daily nudge - navigate to song picker
        case "daily_nudge":
            NotificationCenter.default.post(name: .navigateToSongPicker, object: nil)

        // Phlock song ready - navigate to phlock feed
        case "phlock_song_ready":
            NotificationCenter.default.post(name: .navigateToPhlock, object: nil)

        // Streak milestone - navigate to profile
        case "streak_milestone":
            NotificationCenter.default.post(name: .navigateToProfile, object: nil)

        // Engagement notifications - navigate to specific share
        case "share_liked", "share_commented", "comment_liked":
            if let shareId = shareId {
                let sheetType: String
                switch type {
                case "share_commented": sheetType = "comments"
                case "share_liked", "comment_liked": sheetType = "likers"
                default: sheetType = "none"
                }
                NotificationCenter.default.post(
                    name: .navigateToShare,
                    object: nil,
                    userInfo: ["shareId": shareId, "sheetType": sheetType]
                )
            } else {
                // Fallback to phlock feed
                NotificationCenter.default.post(name: .navigateToPhlock, object: nil)
            }

        default:
            print("Unknown notification type: \(type)")
            // Default to phlock tab
            NotificationCenter.default.post(name: .navigateToPhlock, object: nil)
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
    // Tab navigation
    static let navigateToPhlock = Notification.Name("navigateToPhlock")
    static let navigateToFriends = Notification.Name("navigateToFriends")
    static let navigateToNotifications = Notification.Name("navigateToNotifications")
    static let navigateToProfile = Notification.Name("navigateToProfile")

    // Deep link navigation
    static let navigateToShare = Notification.Name("navigateToShare")
    static let navigateToSongPicker = Notification.Name("navigateToSongPicker")
}
