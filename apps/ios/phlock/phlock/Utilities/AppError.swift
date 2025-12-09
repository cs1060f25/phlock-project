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
            return "can't connect. check your internet?"
        case .timeout:
            return "that took too long. try again?"
        case .sessionExpired:
            return "your session expired. sign in again to continue"
        case .sessionCorrupted:
            return "something went wrong. sign in again to continue"
        case .unauthorized:
            return "you don't have permission to do this"
        case .serverError(let message):
            return message ?? "something went wrong. try again?"
        case .notFound(let item):
            return "couldn't find \(item.lowercased())"
        case .dataCorrupted:
            return "couldn't load. pull to refresh?"
        case .unknown:
            return "something went wrong. try again?"
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

        // URL/Network errors - be SPECIFIC about which codes indicate connectivity issues
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            // Timeout errors
            case NSURLErrorTimedOut:
                return .timeout

            // Actual connectivity/network errors - device has no internet or lost connection
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorDataNotAllowed,           // Cellular data is off
                 NSURLErrorInternationalRoamingOff:  // Roaming is off
                return .network(underlying: error)

            // DNS/Host resolution failures - likely network issue
            case NSURLErrorCannotFindHost,
                 NSURLErrorDNSLookupFailed:
                return .network(underlying: error)

            // Server unreachable - could be server down OR network issue
            // Since we can't easily distinguish here, classify as server error
            // The user's device is clearly trying to connect, so internet is likely working
            // If truly offline, NWPathMonitor will show the OfflineBanner
            case NSURLErrorCannotConnectToHost:
                return .serverError(message: "Server is temporarily unavailable")

            // SSL/TLS errors - these are NOT network connectivity issues
            case NSURLErrorSecureConnectionFailed,
                 NSURLErrorServerCertificateHasBadDate,
                 NSURLErrorServerCertificateUntrusted,
                 NSURLErrorServerCertificateHasUnknownRoot,
                 NSURLErrorServerCertificateNotYetValid,
                 NSURLErrorClientCertificateRejected,
                 NSURLErrorClientCertificateRequired:
                return .serverError(message: "Secure connection failed")

            // HTTP errors embedded in URL errors
            case NSURLErrorBadServerResponse:
                return .serverError(message: nil)

            // User cancelled - not an error to display
            case NSURLErrorCancelled:
                return .unknown(underlying: error)

            // Resource errors - server-side issues
            case NSURLErrorResourceUnavailable,
                 NSURLErrorRedirectToNonExistentLocation,
                 NSURLErrorZeroByteResource:
                return .serverError(message: nil)

            // All other URL errors - don't assume network issue
            default:
                return .unknown(underlying: error)
            }
        }

        // Check error message for common patterns
        let message = error.localizedDescription.lowercased()

        // Auth errors
        if message.contains("unauthorized") || message.contains("401") {
            return .unauthorized
        }

        // Not found errors
        if message.contains("not found") || message.contains("404") {
            return .notFound(item: "Resource")
        }

        // Timeout patterns
        if message.contains("timed out") || message.contains("timeout") {
            return .timeout
        }

        // Server errors (5xx) - check BEFORE network patterns
        if message.contains("500") || message.contains("502") ||
           message.contains("503") || message.contains("504") ||
           message.contains("internal server error") ||
           message.contains("bad gateway") ||
           message.contains("service unavailable") {
            return .serverError(message: nil)
        }

        // Network errors - be VERY specific to avoid false positives
        // Only match patterns that clearly indicate the device has no internet
        if message.contains("no internet") ||
           message.contains("not connected to the internet") ||
           message.contains("network connection was lost") ||
           message.contains("offline") {
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
