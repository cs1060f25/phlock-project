import Foundation

/// Centralized error types for the Phlock app
/// Provides user-friendly error messages and recovery options
enum AppError: Error, LocalizedError, Identifiable {
    case network(underlying: Error?)
    case timeout
    case sessionExpired
    case sessionCorrupted
    case unauthorized
    case serverError(message: String?)
    case notFound(item: String)
    case dataCorrupted
    case unknown(underlying: Error?)

    var id: String {
        switch self {
        case .network: return "network"
        case .timeout: return "timeout"
        case .sessionExpired: return "sessionExpired"
        case .sessionCorrupted: return "sessionCorrupted"
        case .unauthorized: return "unauthorized"
        case .serverError: return "serverError"
        case .notFound: return "notFound"
        case .dataCorrupted: return "dataCorrupted"
        case .unknown: return "unknown"
        }
    }

    var errorDescription: String? {
        switch self {
        case .network:
            return "Unable to connect. Please check your internet connection."
        case .timeout:
            return "Request timed out. Please try again."
        case .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .sessionCorrupted:
            return "There was a problem with your login. Please sign in again."
        case .unauthorized:
            return "You don't have permission to do this."
        case .serverError(let message):
            return message ?? "Something went wrong on our end. Please try again."
        case .notFound(let item):
            return "\(item) could not be found."
        case .dataCorrupted:
            return "Some data couldn't be loaded. Try refreshing."
        case .unknown:
            return "Something unexpected happened. Please try again."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .network:
            return "Check your Wi-Fi or cellular connection and try again."
        case .timeout:
            return "The server is taking too long. Try again in a moment."
        case .sessionExpired, .sessionCorrupted:
            return "Tap 'Sign Out' and sign back in to continue."
        case .unauthorized:
            return "Contact support if you think this is a mistake."
        case .serverError:
            return "If this keeps happening, try again later."
        case .notFound:
            return "It may have been removed or is temporarily unavailable."
        case .dataCorrupted:
            return "Pull down to refresh, or restart the app."
        case .unknown:
            return "If this keeps happening, try restarting the app."
        }
    }

    /// Whether this error can be retried
    var isRetryable: Bool {
        switch self {
        case .network, .timeout, .serverError, .dataCorrupted, .unknown:
            return true
        case .sessionExpired, .sessionCorrupted, .unauthorized, .notFound:
            return false
        }
    }

    /// Whether this error requires re-authentication
    var requiresReauth: Bool {
        switch self {
        case .sessionExpired, .sessionCorrupted, .unauthorized:
            return true
        default:
            return false
        }
    }

    /// Create an AppError from any Error
    static func from(_ error: Error) -> AppError {
        // Check if it's already an AppError
        if let appError = error as? AppError {
            return appError
        }

        // Check for common error patterns
        let nsError = error as NSError

        // Network errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut:
                return .timeout
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorCannotConnectToHost:
                return .network(underlying: error)
            default:
                return .network(underlying: error)
            }
        }

        // Check error message for common patterns
        let message = error.localizedDescription.lowercased()
        if message.contains("unauthorized") || message.contains("401") {
            return .unauthorized
        }
        if message.contains("not found") || message.contains("404") {
            return .notFound(item: "Resource")
        }
        if message.contains("timeout") {
            return .timeout
        }
        if message.contains("network") || message.contains("connection") {
            return .network(underlying: error)
        }

        return .unknown(underlying: error)
    }
}

// MARK: - Equatable for testing
extension AppError: Equatable {
    static func == (lhs: AppError, rhs: AppError) -> Bool {
        lhs.id == rhs.id
    }
}
