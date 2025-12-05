import SwiftUI

/// Type of favorite being selected
enum FavoriteType {
    case artist
    case track

    var title: String {
        switch self {
        case .artist: return "Add Artist"
        case .track: return "Add Track"
        }
    }

    var placeholder: String {
        switch self {
        case .artist: return "search for artists..."
        case .track: return "search for tracks..."
        }
    }

    var searchType: SearchType {
        switch self {
        case .artist: return .artists
        case .track: return .tracks
        }
    }
}

/// Sheet for searching and selecting favorite artists or tracks
struct FavoritePickerSheet: View {
    let favoriteType: FavoriteType
    let onSelect: (MusicItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authState: AuthenticationState

    @State private var searchText = ""
    @State private var searchResults: [MusicItem] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)

                    TextField(favoriteType.placeholder, text: $searchText)
                        .font(.lora(size: 14))
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .focused($isSearchFieldFocused)
                        .onChange(of: searchText) { newValue in
                            if newValue.isEmpty {
                                searchResults = []
                                searchTask?.cancel()
                            } else {
                                performDebouncedSearch()
                            }
                        }
                        .onSubmit {
                            isSearchFieldFocused = false
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(12)
                .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Results
                if isSearching {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Text(error)
                            .font(.lora(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Retry") {
                            performSearch()
                        }
                        .font(.lora(size: 14, weight: .medium))
                    }
                    .padding()
                    Spacer()
                } else if searchText.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: favoriteType == .artist ? "person.crop.circle" : "music.note")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Search for \(favoriteType == .artist ? "artists" : "tracks")")
                            .font(.lora(size: 16))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    Spacer()
                    Text("No results found")
                        .font(.lora(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(searchResults, id: \.id) { item in
                                FavoriteResultRow(
                                    item: item,
                                    type: favoriteType
                                ) {
                                    onSelect(item)
                                    dismiss()
                                }

                                if item.id != searchResults.last?.id {
                                    Divider()
                                        .padding(.leading, 72)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle(favoriteType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            isSearchFieldFocused = true
        }
    }

    // MARK: - Search Methods

    private func performDebouncedSearch() {
        searchTask?.cancel()

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

            if !Task.isCancelled {
                await performSearch()
            }
        }
    }

    @MainActor
    private func performSearch() {
        guard !searchText.isEmpty else { return }

        Task {
            isSearching = true
            errorMessage = nil

            do {
                // Always use Spotify for search since it doesn't require OAuth
                let results = try await SearchService.shared.search(
                    query: searchText,
                    type: favoriteType.searchType,
                    platformType: .spotify
                )

                searchResults = favoriteType == .artist ? results.artists : results.tracks
            } catch {
                errorMessage = error.localizedDescription
            }

            isSearching = false
        }
    }
}

// MARK: - Result Row

struct FavoriteResultRow: View {
    let item: MusicItem
    let type: FavoriteType
    let onSelect: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Image
                if let artworkUrl = item.albumArtUrl, let url = URL(string: artworkUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure, .empty:
                            placeholderImage
                        @unknown default:
                            placeholderImage
                        }
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(type == .artist ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 8)))
                } else {
                    placeholderImage
                        .frame(width: 56, height: 56)
                        .clipShape(type == .artist ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 8)))
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.lora(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if type == .track, let artistName = item.artistName {
                        Text(artistName)
                            .font(.lora(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Add indicator
                Image(systemName: "plus.circle")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var placeholderImage: some View {
        ZStack {
            Color.gray.opacity(0.2)
            Image(systemName: type == .artist ? "person.fill" : "music.note")
                .font(.system(size: 20))
                .foregroundColor(.gray.opacity(0.5))
        }
    }
}

// MARK: - AnyShape Helper

struct AnyShape: Shape {
    private let makePath: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        makePath = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        makePath(rect)
    }
}

#Preview {
    FavoritePickerSheet(favoriteType: .artist) { item in
        print("Selected: \(item.name)")
    }
    .environmentObject(AuthenticationState())
}
