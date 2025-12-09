import SwiftUI

/// Vertical stack of action buttons for the Phlock feed
/// Modeled after TikTok/Instagram Reels action buttons
struct VerticalActionBar: View {
    // Counts
    let likeCount: Int
    let commentCount: Int
    let sendCount: Int

    // States
    let isLiked: Bool
    var isSendLoading: Bool = false

    // Actions
    let onLikeTapped: () -> Void
    let onCommentTapped: () -> Void
    let onSendTapped: () -> Void
    let onOpenTapped: () -> Void

    // Optional: separate action for tapping like count (e.g., to show likers list)
    var onLikeCountTapped: (() -> Void)?

    // Platform for "Open" button
    var platformType: PlatformType?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            // Like button - with optional separate count tap
            if let countAction = onLikeCountTapped {
                LikeActionButtonWithCountTap(
                    likeCount: likeCount,
                    isLiked: isLiked,
                    onIconTapped: onLikeTapped,
                    onCountTapped: countAction
                )
            } else {
                ActionButton(
                    icon: isLiked ? "heart.fill" : "heart",
                    count: likeCount,
                    isActive: isLiked,
                    activeColor: .red,
                    action: onLikeTapped
                )
            }

            // Comment button
            ActionButton(
                icon: "bubble.right",
                count: commentCount,
                action: onCommentTapped
            )

            // Send button (paper airplane) - shows spinner when loading
            SendActionButton(
                count: sendCount,
                isLoading: isSendLoading,
                action: onSendTapped
            )

            // Open in Spotify/Apple Music button
            ActionButton(
                icon: platformIcon,
                count: nil,
                action: onOpenTapped
            )
        }
        .padding(.vertical, 12)
    }

    private var platformIcon: String {
        // Use a generic "open" icon since we can't use platform logos as SF Symbols
        "arrow.up.right.square"
    }
}

// MARK: - Send Action Button (with loading state)

private struct SendActionButton: View {
    let count: Int
    let isLoading: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            guard !isLoading else { return }

            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()

            // Scale animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }

            action()
        }) {
            VStack(spacing: 2) {
                // Show spinner when loading, otherwise show paper airplane
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                        .frame(width: 28, height: 28)
                        .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                } else {
                    Image(systemName: "paperplane")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                        .scaleEffect(isPressed ? 1.2 : 1.0)
                }

                // Count label
                Text(formatCount(count))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading)
    }

    private func formatCount(_ count: Int) -> String {
        if count < 1000 {
            return "\(count)"
        } else if count < 10_000 {
            let thousands = Double(count) / 1000.0
            return String(format: "%.1fK", thousands)
        } else if count < 1_000_000 {
            let thousands = count / 1000
            return "\(thousands)K"
        } else {
            let millions = Double(count) / 1_000_000.0
            return String(format: "%.1fM", millions)
        }
    }
}

// MARK: - Individual Action Button

private struct ActionButton: View {
    let icon: String
    let count: Int?
    var isActive: Bool = false
    var activeColor: Color = .white
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()

            // Scale animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }

            action()
        }) {
            VStack(spacing: 2) {
                // Icon only - no circle background, thin weight
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(isActive ? activeColor : .white)
                    .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                    .scaleEffect(isPressed ? 1.2 : 1.0)

                // Count label (if provided)
                if let count = count {
                    Text(formatCount(count))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// Format count for display (e.g., 1.2K, 15K, 1.2M)
    private func formatCount(_ count: Int) -> String {
        if count < 1000 {
            return "\(count)"
        } else if count < 10_000 {
            let thousands = Double(count) / 1000.0
            return String(format: "%.1fK", thousands)
        } else if count < 1_000_000 {
            let thousands = count / 1000
            return "\(thousands)K"
        } else {
            let millions = Double(count) / 1_000_000.0
            return String(format: "%.1fM", millions)
        }
    }
}

// MARK: - Like Button with Animation

struct AnimatedLikeButton: View {
    let isLiked: Bool
    let likeCount: Int
    let action: () -> Void

    @State private var showHeart = false

    var body: some View {
        ActionButton(
            icon: isLiked ? "heart.fill" : "heart",
            count: likeCount,
            isActive: isLiked,
            activeColor: .red,
            action: {
                // Trigger floating heart animation
                if !isLiked {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                        showHeart = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        showHeart = false
                    }
                }
                action()
            }
        )
        .overlay {
            // Floating heart animation
            if showHeart {
                Image(systemName: "heart.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                    .transition(.scale.combined(with: .opacity))
                    .offset(y: -50)
            }
        }
    }
}

// MARK: - Like Action Button with Separate Count Tap

/// Like button with separate tap targets for icon (toggle like) and count (show likers)
private struct LikeActionButtonWithCountTap: View {
    let likeCount: Int
    let isLiked: Bool
    let onIconTapped: () -> Void
    let onCountTapped: () -> Void

    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 2) {
            // Heart icon - tappable to toggle like
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()

                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }

                onIconTapped()
            }) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(isLiked ? .red : .white)
                    .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                    .scaleEffect(isPressed ? 1.2 : 1.0)
            }
            .buttonStyle(PlainButtonStyle())

            // Count label - tappable to show likers list
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                onCountTapped()
            }) {
                Text(formatCount(likeCount))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func formatCount(_ count: Int) -> String {
        if count < 1000 {
            return "\(count)"
        } else if count < 10_000 {
            let thousands = Double(count) / 1000.0
            return String(format: "%.1fK", thousands)
        } else if count < 1_000_000 {
            let thousands = count / 1000
            return "\(thousands)K"
        } else {
            let millions = Double(count) / 1_000_000.0
            return String(format: "%.1fM", millions)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        // Background image simulation
        LinearGradient(
            colors: [.purple, .blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        HStack {
            Spacer()

            VerticalActionBar(
                likeCount: 1234,
                commentCount: 56,
                sendCount: 12,
                isLiked: true,
                onLikeTapped: { print("Like tapped") },
                onCommentTapped: { print("Comment tapped") },
                onSendTapped: { print("Send tapped") },
                onOpenTapped: { print("Open tapped") },
                platformType: .spotify
            )
            .padding(.trailing, 16)
        }
    }
}
