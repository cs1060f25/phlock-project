import SwiftUI

/// A dismissible error banner that appears at the top of the screen
/// Provides retry and dismiss actions for recoverable errors
struct ErrorBanner: View {
    let error: AppError
    var onRetry: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onSignOut: (() -> Void)?

    @State private var isVisible = false

    var body: some View {
        VStack(spacing: 0) {
            if isVisible {
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        // Error icon
                        Image(systemName: iconName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(iconColor)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(error.localizedDescription)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)

                            if let recovery = error.recoverySuggestion {
                                Text(recovery)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }

                        Spacer()

                        // Dismiss button
                        if onDismiss != nil {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Action buttons
                    HStack(spacing: 12) {
                        if error.requiresReauth, let onSignOut = onSignOut {
                            Button {
                                onSignOut()
                                dismiss()
                            } label: {
                                Text("Sign Out")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.red)
                                    .cornerRadius(8)
                            }
                        }

                        if error.isRetryable, let onRetry = onRetry {
                            Button {
                                onRetry()
                                dismiss()
                            } label: {
                                Text("Try Again")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.black)
                                    .cornerRadius(8)
                            }
                        }

                        Spacer()
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isVisible)
        .onAppear {
            withAnimation {
                isVisible = true
            }
            // Auto-dismiss after 10 seconds for non-critical errors
            if !error.requiresReauth {
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    if isVisible {
                        dismiss()
                    }
                }
            }
        }
    }

    private var iconName: String {
        switch error {
        case .network, .timeout:
            return "wifi.slash"
        case .sessionExpired, .sessionCorrupted, .unauthorized:
            return "person.crop.circle.badge.exclamationmark"
        case .serverError:
            return "server.rack"
        case .notFound:
            return "magnifyingglass"
        case .dataCorrupted, .unknown:
            return "exclamationmark.triangle"
        }
    }

    private var iconColor: Color {
        switch error {
        case .sessionExpired, .sessionCorrupted, .unauthorized:
            return .red
        case .network, .timeout:
            return .orange
        default:
            return .yellow
        }
    }

    private func dismiss() {
        withAnimation {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss?()
        }
    }
}

// MARK: - Inline Error View (for embedding in content)
struct InlineErrorView: View {
    let message: String
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let onRetry = onRetry {
                Button {
                    onRetry()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.black)
                    .cornerRadius(20)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Preview
#Preview {
    VStack {
        ErrorBanner(
            error: .network(underlying: nil),
            onRetry: { print("Retry") },
            onDismiss: { print("Dismiss") }
        )

        Spacer()

        InlineErrorView(
            message: "Failed to load your daily songs",
            onRetry: { print("Retry") }
        )

        Spacer()
    }
}
