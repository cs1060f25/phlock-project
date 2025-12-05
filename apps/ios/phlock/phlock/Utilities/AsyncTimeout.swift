import Foundation

/// Timeout error for async operations
enum TimeoutError: Error, LocalizedError {
    case timedOut(duration: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .timedOut(let duration):
            return "Operation timed out after \(Int(duration)) seconds"
        }
    }
}

/// Executes an async operation with a timeout
/// - Parameters:
///   - seconds: Maximum time to wait before throwing TimeoutError
///   - operation: The async operation to execute
/// - Returns: The result of the operation
/// - Throws: TimeoutError.timedOut if the operation exceeds the timeout, or any error from the operation
func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Add the main operation
        group.addTask {
            try await operation()
        }

        // Add the timeout task
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError.timedOut(duration: seconds)
        }

        // Wait for the first task to complete
        guard let result = try await group.next() else {
            throw TimeoutError.timedOut(duration: seconds)
        }

        // Cancel remaining tasks
        group.cancelAll()

        return result
    }
}

/// Executes an async operation with a timeout, returning nil on timeout instead of throwing
/// - Parameters:
///   - seconds: Maximum time to wait before returning nil
///   - operation: The async operation to execute
/// - Returns: The result of the operation, or nil if timed out
func withTimeoutOrNil<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async -> T? {
    do {
        return try await withTimeout(seconds: seconds, operation: operation)
    } catch is TimeoutError {
        return nil
    } catch {
        return nil
    }
}

// MARK: - Retry with Exponential Backoff

/// Retry configuration
struct RetryConfiguration {
    let maxAttempts: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    let shouldRetry: (Error) -> Bool

    static let `default` = RetryConfiguration(
        maxAttempts: 3,
        baseDelay: 1.0,
        maxDelay: 10.0,
        shouldRetry: { error in
            // Retry on network errors and timeouts, but not on auth errors
            if error is TimeoutError { return true }
            if let appError = error as? AppError {
                return appError.isRetryable
            }
            // Default: retry on unknown errors (could be transient)
            let nsError = error as NSError
            return nsError.domain == NSURLErrorDomain
        }
    )
}

/// Executes an async operation with retry logic and exponential backoff
/// - Parameters:
///   - config: Retry configuration
///   - operation: The async operation to execute
/// - Returns: The result of the operation
/// - Throws: The last error if all retries fail
func withRetry<T: Sendable>(
    config: RetryConfiguration = .default,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    var lastError: Error?

    for attempt in 1...config.maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            print("⚠️ Attempt \(attempt)/\(config.maxAttempts) failed: \(error.localizedDescription)")

            // Check if we should retry this error
            guard config.shouldRetry(error) else {
                throw error
            }

            // Don't wait after the last attempt
            guard attempt < config.maxAttempts else {
                break
            }

            // Exponential backoff with jitter
            let delay = min(
                config.baseDelay * pow(2.0, Double(attempt - 1)),
                config.maxDelay
            )
            let jitter = Double.random(in: 0.8...1.2)
            let actualDelay = delay * jitter

            print("⏳ Retrying in \(String(format: "%.1f", actualDelay))s...")
            try? await Task.sleep(nanoseconds: UInt64(actualDelay * 1_000_000_000))
        }
    }

    throw lastError ?? TimeoutError.timedOut(duration: 0)
}

/// Combines timeout and retry for robust async operations
/// - Parameters:
///   - timeoutSeconds: Maximum time for each attempt
///   - retryConfig: Retry configuration
///   - operation: The async operation to execute
/// - Returns: The result of the operation
func withTimeoutAndRetry<T: Sendable>(
    timeoutSeconds: TimeInterval,
    retryConfig: RetryConfiguration = .default,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withRetry(config: retryConfig) {
        try await withTimeout(seconds: timeoutSeconds, operation: operation)
    }
}
