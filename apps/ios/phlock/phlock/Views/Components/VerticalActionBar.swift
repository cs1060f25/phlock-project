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

    // Actions
    let onLikeTapped: () -> Void
    let onCommentTapped: () -> Void
    let onSendTapped: () -> Void
    let onOpenTapped: () -> Void

    // Platform for "Open" button
    var platformType: PlatformType?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            // Like button
            ActionButton(
                icon: isLiked ? "heart.fill" : "heart",
                count: likeCount,
                isActive: isLiked,
                activeColor: .red,
                action: onLikeTapped
            )

            // Comment button
            ActionButton(
                icon: "bubble.right",
                count: commentCount,
                action: onCommentTapped
            )

            // Send button (paper airplane)
            ActionButton(
                icon: "paperplane",
                count: sendCount,
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
            VStack(spacing: 4) {
                // Icon with glass background
                ZStack {
                    // Glass/translucent background
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(isActive ? activeColor : .white)
                }
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
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
