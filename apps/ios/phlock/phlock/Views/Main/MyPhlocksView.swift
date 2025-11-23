import SwiftUI

// Navigation destination types for Phlocks
enum PhlocksDestination: Hashable {
    case profile
    case phlockDetail(GroupedPhlock) // Navigate to detailed phlock view
    case conversation(User)
}

struct MyPhlocksView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme
    @Binding var navigationPath: NavigationPath
    @Binding var refreshTrigger: Int
    @Binding var scrollToTopTrigger: Int

    @State private var phlocks: [GroupedPhlock] = []
    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var pullProgress: CGFloat = 0
    @State private var errorMessage: String?
    @State private var hasLoadedOnce = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading phlocks...")
                            .font(.lora(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    ErrorStateView(message: error) {
                        Task { await loadPhlocks() }
                    }
                } else if phlocks.isEmpty {
                    EmptyPhlocksView()
                } else {
                    PhlockGalleryView(
                        phlocks: phlocks,
                        navigationPath: $navigationPath,
                        scrollToTopTrigger: $scrollToTopTrigger,
                        onRefresh: {
                            await loadPhlocks(forceRefresh: true)
                        }
                    )
                }
            }
            .navigationTitle("phlocks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(value: PhlocksDestination.profile) {
                        ProfileIconView(user: authState.currentUser)
                    }
                }
            }
            .navigationDestination(for: PhlocksDestination.self) { destination in
                switch destination {
                case .profile:
                    ProfileView()
                case .phlockDetail(let phlock):
                    PhlockDetailView(phlock: phlock, navigationPath: $navigationPath)
                        .environmentObject(authState)
                case .conversation(let user):
                    ConversationView(otherUser: user)
                        .environmentObject(authState)
                }
            }
            .task {
                await loadPhlocks()
            }
            .onChange(of: refreshTrigger) { _ in
                Task {
                    // Scroll to top and reload data
                    withAnimation {
                        scrollToTopTrigger += 1
                    }
                    isRefreshing = true
                    await loadPhlocks(forceRefresh: true)
                    await MainActor.run {
                        isRefreshing = false
                    }
                }
            }
        }
    }

    private func loadPhlocks(forceRefresh: Bool = false) async {
        guard let userId = authState.currentUser?.id else {
            await MainActor.run {
                errorMessage = "Not authenticated"
                isLoading = false
            }
            return
        }

        await MainActor.run {
            if !hasLoadedOnce {
                isLoading = true
            }
            errorMessage = nil
        }

        print("🔍 DEBUG: Loading phlocks for user ID: \(userId) (forceRefresh: \(forceRefresh))")
        print("🔍 DEBUG: User display name: \(authState.currentUser?.displayName ?? "unknown")")

        do {
            let result = try await PhlockService.shared.getPhlocksGroupedByTrack(userId: userId, forceRefresh: forceRefresh)
            print("✅ DEBUG: Successfully loaded \(result.count) grouped phlocks")
            await MainActor.run {
                phlocks = result
                isLoading = false
                errorMessage = nil
                hasLoadedOnce = true
            }
        } catch {
            print("❌ Error loading phlocks: \(error)")
            await MainActor.run {
                errorMessage = "Failed to load phlocks: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

// MARK: - Gallery View

struct PhlockGalleryView: View {
    let phlocks: [GroupedPhlock]
    @Binding var navigationPath: NavigationPath
    @Binding var scrollToTopTrigger: Int
    var onRefresh: () async -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var isRefreshing = false
    @State private var pullProgress: CGFloat = 0

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    Color.clear
                        .frame(height: 1)
                        .id("phlocksTop")

                    VStack(spacing: 8) {
                        Text("Songs you've shared, organized by track")
                            .font(.lora(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    }

                    ForEach(phlocks) { phlock in
                        NavigationLink(value: PhlocksDestination.phlockDetail(phlock)) {
                            PhlockCardView(phlock: phlock)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.visible)
            .pullToRefreshWithSpinner(
                isRefreshing: $isRefreshing,
                pullProgress: $pullProgress,
                colorScheme: colorScheme
            ) {
                isRefreshing = true
                await onRefresh()
                await MainActor.run {
                    isRefreshing = false
                }
            }
            .onChange(of: scrollToTopTrigger) { _ in
                withAnimation {
                    scrollProxy.scrollTo("phlocksTop", anchor: .top)
                }
            }
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
                        .font(.lora(size: 18, weight: .bold))
                        .lineLimit(1)

                    Text(phlock.artistName)
                        .font(.lora(size: 15))
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
                    .font(.lora(size: 13))
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
                    .font(.lora(size: 14, weight: .semiBold))

                Text(label)
                    .font(.lora(size: 10))
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
                    .font(.lora(size: 28, weight: .bold))

                Text("see all the songs you've sent to friends,\ngrouped by track with engagement metrics")
                    .font(.lora(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Text("discover music and start sharing\nto see your phlocks here!")
                    .font(.lora(size: 13))
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
                .font(.lora(size: 20, weight: .semiBold))

            Text(message)
                .font(.lora(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Try Again") {
                retry()
            }
            .font(.lora(size: 16, weight: .semiBold))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
}

#Preview {
    MyPhlocksView(navigationPath: .constant(NavigationPath()), refreshTrigger: .constant(0), scrollToTopTrigger: .constant(0))
        .environmentObject(AuthenticationState())
}
