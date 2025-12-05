import SwiftUI

/// A recovery view shown when the app encounters a critical error state
/// Provides options for the user to attempt recovery or sign out
struct RecoveryView: View {
    @EnvironmentObject var authState: AuthenticationState

    let error: AppError
    var onRetry: (() -> Void)?
    var onForceReset: (() -> Void)?

    @State private var isRecovering = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Error icon
            Image(systemName: iconName)
                .font(.system(size: 60))
                .foregroundColor(iconColor)
                .padding(.bottom, 8)

            // Title
            Text(title)
                .font(.lora(size: 24, weight: .bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            // Description
            Text(description)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // Action buttons
            VStack(spacing: 16) {
                if isRecovering {
                    ProgressView()
                        .scaleEffect(1.2)
                        .padding(.vertical, 20)
                } else {
                    // Primary action - Retry
                    Button {
                        handleRetry()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Try Again")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .cornerRadius(12)
                    }

                    // Secondary action - Sign Out
                    if error.requiresReauth {
                        Button {
                            handleSignOut()
                        } label: {
                            Text("Sign Out & Start Fresh")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.red)
                        }
                    }

                    // Tertiary action - Force Reset (for corrupted sessions)
                    if error == .sessionCorrupted {
                        Button {
                            handleForceReset()
                        } label: {
                            Text("Reset Everything")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .background(Color(.systemBackground))
    }

    private var iconName: String {
        switch error {
        case .sessionCorrupted:
            return "exclamationmark.lock"
        case .sessionExpired:
            return "clock.badge.exclamationmark"
        case .network, .timeout:
            return "wifi.exclamationmark"
        default:
            return "exclamationmark.triangle"
        }
    }

    private var iconColor: Color {
        switch error {
        case .sessionCorrupted, .sessionExpired:
            return .red
        case .network, .timeout:
            return .orange
        default:
            return .yellow
        }
    }

    private var title: String {
        switch error {
        case .sessionCorrupted:
            return "Session Problem"
        case .sessionExpired:
            return "Session Expired"
        case .network:
            return "Connection Issue"
        case .timeout:
            return "Taking Too Long"
        default:
            return "Something Went Wrong"
        }
    }

    private var description: String {
        switch error {
        case .sessionCorrupted:
            return "There's an issue with your login session. We'll need to sign you out so you can start fresh."
        case .sessionExpired:
            return "Your session has expired. Please sign in again to continue."
        case .network:
            return "We couldn't connect to our servers. Check your internet connection and try again."
        case .timeout:
            return "The request is taking longer than expected. Please try again."
        default:
            return error.recoverySuggestion ?? "Please try again. If the problem continues, try signing out and back in."
        }
    }

    private func handleRetry() {
        isRecovering = true
        onRetry?()

        // If no custom retry handler, use default auth check
        if onRetry == nil {
            Task {
                await authState.checkAuthStatus()
                isRecovering = false
            }
        }
    }

    private func handleSignOut() {
        isRecovering = true
        Task {
            await authState.signOut()
            isRecovering = false
        }
    }

    private func handleForceReset() {
        isRecovering = true
        onForceReset?()

        // If no custom handler, use default force reset
        if onForceReset == nil {
            Task {
                await authState.forceReset()
                isRecovering = false
            }
        }
    }
}

#Preview {
    RecoveryView(error: .sessionCorrupted)
        .environmentObject(AuthenticationState())
}
