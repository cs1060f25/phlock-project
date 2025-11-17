import Foundation
import OSLog

/// Centralized logging utility for Phlock app
/// Replaces print statements with proper OS logging for better performance and privacy
@available(iOS 14.0, *)
struct PhlockLogger {
    // MARK: - Log Categories

    /// Logger for authentication-related operations
    static let auth = Logger(subsystem: "com.phlock.app", category: "Authentication")

    /// Logger for music playback operations
    static let playback = Logger(subsystem: "com.phlock.app", category: "Playback")

    /// Logger for network/API operations
    static let network = Logger(subsystem: "com.phlock.app", category: "Network")

    /// Logger for database operations
    static let database = Logger(subsystem: "com.phlock.app", category: "Database")

    /// Logger for UI/View operations
    static let ui = Logger(subsystem: "com.phlock.app", category: "UI")

    /// Logger for music service integrations (Spotify, Apple Music)
    static let music = Logger(subsystem: "com.phlock.app", category: "MusicService")

    /// Logger for social features (shares, friends, etc.)
    static let social = Logger(subsystem: "com.phlock.app", category: "Social")

    /// General logger for uncategorized logs
    static let general = Logger(subsystem: "com.phlock.app", category: "General")

    // MARK: - Debug Mode Flag

    /// Set to false in production to disable verbose logging
    #if DEBUG
    static let isDebugMode = true
    #else
    static let isDebugMode = false
    #endif
}

// MARK: - Convenience Extensions

extension Logger {
    /// Log debug information (only in debug mode)
    func debugLog(_ message: String) {
        #if DEBUG
        self.debug("\(message)")
        #endif
    }

    /// Log an error with optional underlying error
    func errorLog(_ message: String, error: Error? = nil) {
        if let error = error {
            self.error("\(message): \(error.localizedDescription)")
        } else {
            self.error("\(message)")
        }
    }

    /// Log a warning
    func warningLog(_ message: String) {
        self.warning("\(message)")
    }

    /// Log general information
    func infoLog(_ message: String) {
        self.info("\(message)")
    }
}

// MARK: - Legacy Print Replacement

/// Replace print statements in development
/// In production, these do nothing for better performance
func debugPrint(_ items: Any...) {
    #if DEBUG
    let message = items.map { String(describing: $0) }.joined(separator: " ")
    print(message)
    #endif
}