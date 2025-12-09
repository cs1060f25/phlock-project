import SwiftUI

/// Bottom sheet showing users who liked a share
struct LikersListSheet: View {
    let shareId: UUID
    @Binding var isPresented: Bool

    @State private var likers: [LikerInfo] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await loadLikers() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if likers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "heart")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No likes yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Be the first to like this song!")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(likers) { liker in
                        LikerRow(liker: liker)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("likes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            await loadLikers()
        }
    }

    private func loadLikers() async {
        isLoading = true
        errorMessage = nil

        do {
            likers = try await SocialEngagementService.shared.fetchLikersForShare(shareId: shareId)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - Liker Row

private struct LikerRow: View {
    let liker: LikerInfo

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            AsyncImage(url: URL(string: liker.profilePhotoUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure, .empty:
                    avatarPlaceholder
                @unknown default:
                    avatarPlaceholder
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            // User info
            VStack(alignment: .leading, spacing: 2) {
                if let username = liker.username {
                    Text("@\(username)")
                        .font(.system(size: 15, weight: .semibold))
                } else {
                    Text(liker.displayName)
                        .font(.system(size: 15, weight: .semibold))
                }

                Text(timeAgo(from: liker.likedAt))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Like icon
            Image(systemName: "heart.fill")
                .font(.system(size: 14))
                .foregroundColor(.red)
        }
        .padding(.vertical, 4)
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .overlay {
                Text(String((liker.username ?? liker.displayName).prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
            }
    }

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    LikersListSheet(
        shareId: UUID(),
        isPresented: .constant(true)
    )
}
