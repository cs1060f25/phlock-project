import SwiftUI

/// Type of favorite being selected
enum FavoriteType {
    case artist
    case track

    var title: String {
        switch self {
        case .artist: return "add artists"
        case .track: return "add tracks"
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

    var emptyStateText: String {
        switch self {
        case .artist: return "search for artists"
        case .track: return "search for tracks"
        }
    }
}

/// Sheet for searching and selecting favorite artists or tracks
/// Supports multi-selection up to 6 items with a bottom confirmation bar
struct FavoritePickerSheet: View {
    let favoriteType: FavoriteType
    let existingItems: [MusicItem]
    let onConfirm: ([MusicItem]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authState: AuthenticationState

    @State private var searchText = ""
    @State private var searchResults: [MusicItem] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isSearchFieldFocused: Bool

    // Multi-selection state
    @State private var selectedItems: [MusicItem] = []
    private let maxSelections = 6

    // Genre browsing state (artists only)
    @State private var selectedGenre: String?
    @State private var genreArtists: [MusicItem] = []
    @State private var isLoadingGenre = false

    // Available genres for browsing
    private let availableGenres = ["pop", "hip-hop", "r&b", "rock", "indie", "electronic", "jazz", "soul", "k-pop", "latin"]

    init(
        favoriteType: FavoriteType,
        existingItems: [MusicItem] = [],
        onConfirm: @escaping ([MusicItem]) -> Void
    ) {
        self.favoriteType = favoriteType
        self.existingItems = existingItems
        self.onConfirm = onConfirm
        // Initialize selected items with existing items, limited to maxSelections
        // This prevents crash when user has more items than the max allowed
        let limitedItems = Array(existingItems.prefix(6))
        _selectedItems = State(initialValue: limitedItems)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
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

                            Button("retry") {
                                performSearch()
                            }
                            .font(.lora(size: 14, weight: .medium))
                        }
                        .padding()
                        Spacer()
                    } else if searchText.isEmpty {
                        if favoriteType == .artist {
                            // Genre browsing for artists
                            genreBrowsingView
                        } else {
                            // Empty state for tracks
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary.opacity(0.5))
                                Text(favoriteType.emptyStateText)
                                    .font(.lora(size: 16))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    } else if searchResults.isEmpty && !searchText.isEmpty {
                        Spacer()
                        Text("no results found")
                            .font(.lora(size: 14))
                            .foregroundColor(.secondary)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(searchResults, id: \.id) { item in
                                    FavoriteSelectableRow(
                                        item: item,
                                        type: favoriteType,
                                        isSelected: isItemSelected(item),
                                        canSelect: canSelectMore || isItemSelected(item)
                                    ) {
                                        toggleSelection(item)
                                    }

                                    if item.id != searchResults.last?.id {
                                        Divider()
                                            .padding(.leading, 72)
                                    }
                                }
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 100) // Space for always-visible bottom bar
                        }
                    }
                }

                // Bottom Selection Bar - always visible to show slots
                SelectionBar(
                    items: selectedItems,
                    type: favoriteType,
                    maxItems: maxSelections,
                    onRemove: { item in
                        removeSelection(item)
                    },
                    onConfirm: {
                        onConfirm(selectedItems)
                        dismiss()
                    }
                )
            }
            .animation(.spring(response: 0.3), value: selectedItems.count)
            .navigationTitle(favoriteType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        dismiss()
                    }
                    .font(.lora(size: 16))
                }
            }
        }
        .onAppear {
            isSearchFieldFocused = true
        }
    }

    // MARK: - Selection Logic

    private var canSelectMore: Bool {
        selectedItems.count < maxSelections
    }

    private func isItemSelected(_ item: MusicItem) -> Bool {
        selectedItems.contains { $0.id == item.id }
    }

    private func toggleSelection(_ item: MusicItem) {
        if let index = selectedItems.firstIndex(where: { $0.id == item.id }) {
            selectedItems.remove(at: index)
        } else if canSelectMore {
            selectedItems.append(item)
        }
    }

    private func removeSelection(_ item: MusicItem) {
        selectedItems.removeAll { $0.id == item.id }
    }

    // MARK: - Search Methods

    private func performDebouncedSearch() {
        searchTask?.cancel()

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

            if !Task.isCancelled {
                performSearch()
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

    // MARK: - Genre Browsing

    private var genreBrowsingView: some View {
        VStack(spacing: 0) {
            // Genre chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(availableGenres, id: \.self) { genre in
                        GenreChip(
                            genre: genre,
                            isSelected: selectedGenre == genre,
                            onTap: {
                                if selectedGenre == genre {
                                    // Deselect
                                    selectedGenre = nil
                                    genreArtists = []
                                } else {
                                    selectedGenre = genre
                                    loadArtistsByGenre(genre)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            Divider()

            // Genre results or empty state
            if isLoadingGenre {
                Spacer()
                ProgressView()
                Spacer()
            } else if selectedGenre != nil, !genreArtists.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(genreArtists, id: \.id) { item in
                            FavoriteSelectableRow(
                                item: item,
                                type: .artist,
                                isSelected: isItemSelected(item),
                                canSelect: canSelectMore || isItemSelected(item)
                            ) {
                                toggleSelection(item)
                            }

                            if item.id != genreArtists.last?.id {
                                Divider()
                                    .padding(.leading, 72)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 100) // Space for always-visible bottom bar
                }
            } else {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("select a genre or search")
                        .font(.lora(size: 16))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
    }

    private func loadArtistsByGenre(_ genre: String) {
        Task {
            await MainActor.run {
                isLoadingGenre = true
                genreArtists = []
            }

            print("🎵 Loading artists for genre: \(genre)")

            do {
                let artists = try await SearchService.shared.browseArtistsByGenre(genre: genre, limit: 30)
                print("✅ Got \(artists.count) artists for genre \(genre)")
                if let first = artists.first {
                    print("   First artist: \(first.name), image: \(first.albumArtUrl ?? "none")")
                }
                await MainActor.run {
                    genreArtists = artists
                    isLoadingGenre = false
                }
            } catch {
                print("❌ Failed to load artists for genre \(genre): \(error)")
                await MainActor.run {
                    isLoadingGenre = false
                    errorMessage = "Failed to load \(genre) artists"
                }
            }
        }
    }
}

// MARK: - Genre Chip

struct GenreChip: View {
    let genre: String
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            Text(genre)
                .font(.lora(size: 14, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.15))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Selectable Row

struct FavoriteSelectableRow: View {
    let item: MusicItem
    let type: FavoriteType
    let isSelected: Bool
    let canSelect: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
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

                // Selection indicator (checkmark circle like browse sheet)
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.white.opacity(0.65))
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Color.accentColor : Color.secondary, lineWidth: 2)
                        )
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .opacity(canSelect || isSelected ? 1 : 0.3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canSelect && !isSelected)
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

// MARK: - Bottom Selection Bar

struct SelectionBar: View {
    let items: [MusicItem]
    let type: FavoriteType
    let maxItems: Int
    let onRemove: (MusicItem) -> Void
    let onConfirm: () -> Void

    @Environment(\.colorScheme) var colorScheme

    private var hasSelections: Bool {
        !items.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                // Selected items thumbnails (or empty slots)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(items, id: \.id) { item in
                            SelectionThumbnail(
                                item: item,
                                type: type,
                                onRemove: { onRemove(item) }
                            )
                        }

                        // Empty slots (guard against negative range)
                        ForEach(0..<max(0, maxItems - items.count), id: \.self) { _ in
                            EmptySlotThumbnail(type: type)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Confirm button - disabled when no selections
                Button(action: onConfirm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(hasSelections ? .accentColor : .gray.opacity(0.4))
                }
                .disabled(!hasSelections)
                .padding(.trailing, 16)
            }
            .padding(.vertical, 12)
            .background(
                colorScheme == .dark
                    ? Color.black.opacity(0.95)
                    : Color.white.opacity(0.95)
            )
        }
    }
}

// MARK: - Selection Thumbnail

struct SelectionThumbnail: View {
    let item: MusicItem
    let type: FavoriteType
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let artworkUrl = item.albumArtUrl, let url = URL(string: artworkUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure, .empty:
                        thumbnailPlaceholder
                    @unknown default:
                        thumbnailPlaceholder
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(type == .artist ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 6)))
            } else {
                thumbnailPlaceholder
                    .frame(width: 48, height: 48)
                    .clipShape(type == .artist ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 6)))
            }

            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white, Color.black.opacity(0.7))
            }
            .offset(x: 4, y: -4)
        }
        .padding(.top, 6)
        .padding(.trailing, 6)
    }

    private var thumbnailPlaceholder: some View {
        ZStack {
            Color.gray.opacity(0.3)
            Text(item.name.prefix(1).uppercased())
                .font(.lora(size: 16, weight: .medium))
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Empty Slot Thumbnail

struct EmptySlotThumbnail: View {
    let type: FavoriteType

    var body: some View {
        ZStack {
            if type == .artist {
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundColor(.gray.opacity(0.4))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundColor(.gray.opacity(0.4))
            }
        }
        .frame(width: 48, height: 48)
    }
}

// MARK: - AnyShape Helper

struct AnyShape: Shape {
    private let makePath: @Sendable (CGRect) -> Path

    init<S: Shape & Sendable>(_ shape: S) {
        makePath = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        makePath(rect)
    }
}

#Preview {
    FavoritePickerSheet(favoriteType: .artist, existingItems: []) { items in
        print("Selected: \(items.map { $0.name })")
    }
    .environmentObject(AuthenticationState())
}
