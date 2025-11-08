import SwiftUI

// Navigation destination types for Phlocks
enum PhlocksDestination: Hashable {
    case profile
    case phlockDetail(String) // Navigate to detailed phlock view by trackId
    case conversation(User)
}

struct MyPhlocksView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme
    @Binding var navigationPath: NavigationPath

    @State private var phlocks: [GroupedPhlock] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    ErrorStateView(message: error) {
                        Task { await loadPhlocks() }
                    }
                } else if phlocks.isEmpty {
                    EmptyPhlocksView()
                } else {
                    PhlockGalleryView(phlocks: phlocks, navigationPath: $navigationPath)
                }
            }
            .navigationTitle("phlocks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        navigationPath.append(PhlocksDestination.profile)
                    } label: {
                        ProfileIconView(user: authState.currentUser)
                    }
                }
            }
            .navigationDestination(for: PhlocksDestination.self) { destination in
                switch destination {
                case .profile:
                    ProfileView()
                case .phlockDetail(let trackId):
                    PhlockDetailView(trackId: trackId)
                        .environmentObject(authState)
                case .conversation(let user):
                    ConversationView(otherUser: user)
                        .environmentObject(authState)
                }
            }
            .task {
                await loadPhlocks()
            }
            .refreshable {
                await loadPhlocks()
            }
        }
    }

    private func loadPhlocks() async {
        guard let userId = authState.currentUser?.id else {
            errorMessage = "Not authenticated"
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        print("🔍 DEBUG: Loading phlocks for user ID: \(userId)")
        print("🔍 DEBUG: User display name: \(authState.currentUser?.displayName ?? "unknown")")

        do {
            phlocks = try await PhlockService.shared.getPhlocksGroupedByTrack(userId: userId)
            print("✅ DEBUG: Successfully loaded \(phlocks.count) grouped phlocks")
        } catch {
            errorMessage = "Failed to load phlocks: \(error.localizedDescription)"
            print("❌ Error loading phlocks: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Gallery View

struct PhlockGalleryView: View {
    let phlocks: [GroupedPhlock]
    @Binding var navigationPath: NavigationPath
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Header info
                VStack(spacing: 8) {
                    Text("Songs you've shared, organized by track")
                        .font(.nunitoSans(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }

                // Phlock cards
                ForEach(phlocks) { phlock in
                    PhlockCardView(phlock: phlock)
                        .onTapGesture {
                            navigationPath.append(PhlocksDestination.phlockDetail(phlock.trackId))
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100) // Space for mini player
        }
    }
}

// MARK: - Phlock Card

struct PhlockCardView: View {
    let phlock: GroupedPhlock
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Album Art Section
            if let albumArtUrl = phlock.albumArtUrl, let url = URL(string: albumArtUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(height: 200)
                .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                    )
            }

            // Info Section
            VStack(alignment: .leading, spacing: 12) {
                // Track & Artist
                VStack(alignment: .leading, spacing: 4) {
                    Text(phlock.trackName)
                        .font(.nunitoSans(size: 18, weight: .bold))
                        .lineLimit(1)

                    Text(phlock.artistName)
                        .font(.nunitoSans(size: 15))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                // Metrics Row
                HStack(spacing: 16) {
                    MetricBadge(
                        icon: "paperplane.fill",
                        value: "\(phlock.recipientCount)",
                        label: phlock.recipientCount == 1 ? "recipient" : "recipients"
                    )

                    MetricBadge(
                        icon: "play.circle.fill",
                        value: "\(Int(phlock.listenRate * 100))%",
                        label: "listened"
                    )

                    MetricBadge(
                        icon: "heart.fill",
                        value: "\(Int(phlock.saveRate * 100))%",
                        label: "saved"
                    )
                }

                // Timestamp
                Text("Last sent \(phlock.lastSentAt.shortRelativeTimeString())")
                    .font(.nunitoSans(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Metric Badge

struct MetricBadge: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.nunitoSans(size: 14, weight: .semiBold))

                Text(label)
                    .font(.nunitoSans(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Empty State

struct EmptyPhlocksView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Text("📤")
                    .font(.system(size: 64))

                Text("No songs shared yet")
                    .font(.nunitoSans(size: 28, weight: .bold))

                Text("see all the songs you've sent to friends,\ngrouped by track with engagement metrics")
                    .font(.nunitoSans(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Text("discover music and start sharing\nto see your phlocks here!")
                    .font(.nunitoSans(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
                    .padding(.horizontal, 24)
            }
            .padding(32)
            .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.05))
            .cornerRadius(20)
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}

// MARK: - Error State

struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Error Loading Phlocks")
                .font(.nunitoSans(size: 20, weight: .semiBold))

            Text(message)
                .font(.nunitoSans(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Try Again") {
                retry()
            }
            .font(.nunitoSans(size: 16, weight: .semiBold))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
}

#Preview {
    MyPhlocksView(navigationPath: .constant(NavigationPath()))
        .environmentObject(AuthenticationState())
}
