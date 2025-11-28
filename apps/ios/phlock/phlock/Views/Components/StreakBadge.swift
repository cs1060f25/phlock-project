//
//  StreakBadge.swift
//  phlock
//
//  A BeReal-style streak badge that displays under profile photos
//

import SwiftUI

/// A pill-shaped badge showing the user's daily song streak
/// Displays fire emoji + streak count in a semi-transparent pill
struct StreakBadge: View {
    let streak: Int
    var size: BadgeSize = .medium

    enum BadgeSize {
        case small   // For list rows (Friends, Followers)
        case medium  // For profile headers
        case large   // For featured/expanded views

        var fontSize: CGFloat {
            switch self {
            case .small: return 11
            case .medium: return 13
            case .large: return 15
            }
        }

        var emojiSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 12
            case .large: return 14
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 6
            case .medium: return 8
            case .large: return 10
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small: return 3
            case .medium: return 4
            case .large: return 5
            }
        }
    }

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if streak > 0 {
            HStack(spacing: 2) {
                Text("🔥")
                    .font(.system(size: size.emojiSize))
                Text("\(streak)")
                    .font(.lora(size: size.fontSize, weight: .semiBold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(
                Capsule()
                    .fill(Color.black.opacity(colorScheme == .dark ? 0.7 : 0.75))
            )
        }
    }
}

/// A profile photo with an optional streak badge overlay
/// Use this for consistent streak badge positioning across the app
struct ProfilePhotoWithStreak: View {
    let photoUrl: String?
    let displayName: String
    let streak: Int
    var size: CGFloat = 50
    var badgeSize: StreakBadge.BadgeSize = .small

    var body: some View {
        VStack(spacing: 0) {
            // Profile photo
            if let photoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ProfilePhotoPlaceholder(displayName: displayName)
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                ProfilePhotoPlaceholder(displayName: displayName)
                    .frame(width: size, height: size)
            }

            // Streak badge (positioned to overlap slightly)
            if streak > 0 {
                StreakBadge(streak: streak, size: badgeSize)
                    .offset(y: -10)
            }
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        // Different streak levels
        HStack(spacing: 20) {
            VStack {
                StreakBadge(streak: 3, size: .small)
                Text("Small").font(.caption)
            }
            VStack {
                StreakBadge(streak: 25, size: .medium)
                Text("Medium").font(.caption)
            }
            VStack {
                StreakBadge(streak: 685, size: .large)
                Text("Large").font(.caption)
            }
        }

        // Profile photo with streak
        HStack(spacing: 30) {
            ProfilePhotoWithStreak(
                photoUrl: nil,
                displayName: "Test User",
                streak: 15,
                size: 50,
                badgeSize: .small
            )

            ProfilePhotoWithStreak(
                photoUrl: nil,
                displayName: "Another User",
                streak: 100,
                size: 80,
                badgeSize: .medium
            )
        }

        // Zero streak (should be hidden)
        StreakBadge(streak: 0)
    }
    .padding()
}
