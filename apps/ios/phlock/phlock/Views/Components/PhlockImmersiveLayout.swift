import SwiftUI
import AVFoundation
import UIKit

// MARK: - Image Brightness Cache

/// Singleton cache for image brightness analysis results
/// Prevents redundant analysis when scrolling through carousel
final class ImageBrightnessCache: @unchecked Sendable {
    static let shared = ImageBrightnessCache()
    private init() {}

    private var cache: [String: Bool] = [:]  // URL string -> isBright
    private let lock = NSLock()

    func get(_ urlString: String) -> Bool? {
        lock.lock()
        defer { lock.unlock() }
        return cache[urlString]
    }

    func set(_ urlString: String, isBright: Bool) {
        lock.lock()
        defer { lock.unlock() }
        cache[urlString] = isBright
    }
}

// MARK: - Image Brightness Analysis

extension UIImage {
    /// Fast brightness calculation using a tiny sample (8x8 = 64 pixels)
    /// Optimized for speed over precision - sufficient for text color decisions
    /// Thread-safe: performs pure computation on image data
    nonisolated func fastBrightness() -> CGFloat {
        guard let cgImage = self.cgImage else { return 0.5 }

        // Use tiny 8x8 sample for maximum speed
        let sampleSize = 8
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * sampleSize
        var pixelData = [UInt8](repeating: 0, count: sampleSize * sampleSize * bytesPerPixel)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixelData,
            width: sampleSize,
            height: sampleSize,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0.5 }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))

        // Fast sum without per-pixel division
        var totalR: Int = 0, totalG: Int = 0, totalB: Int = 0
        let pixelCount = sampleSize * sampleSize

        for i in 0..<pixelCount {
            let offset = i * bytesPerPixel
            totalR += Int(pixelData[offset])
            totalG += Int(pixelData[offset + 1])
            totalB += Int(pixelData[offset + 2])
        }

        // Luminance formula applied to averages
        let avgR = CGFloat(totalR) / CGFloat(pixelCount * 255)
        let avgG = CGFloat(totalG) / CGFloat(pixelCount * 255)
        let avgB = CGFloat(totalB) / CGFloat(pixelCount * 255)

        return 0.2126 * avgR + 0.7152 * avgG + 0.0722 * avgB
    }

    /// Determines if the image should use dark text for readability
    nonisolated func shouldUseDarkText(threshold: CGFloat = 0.55) -> Bool {
        return fastBrightness() > threshold
    }
}

// MARK: - Progress Scrubber (UIKit-based for reliable gesture handling inside TabView)

/// A UIKit-based progress scrubber that properly handles gestures inside SwiftUI TabView
/// This prevents the TabView's page swipe from intercepting our drag gesture
struct ProgressScrubber: UIViewRepresentable {
    let progress: Double
    let isDragging: Bool
    let trackColor: Color
    let fillColor: Color
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: (CGFloat) -> Void

    init(progress: Double, isDragging: Bool, trackColor: Color = .white.opacity(0.3), fillColor: Color = .white, onDragChanged: @escaping (CGFloat) -> Void, onDragEnded: @escaping (CGFloat) -> Void) {
        self.progress = progress
        self.isDragging = isDragging
        self.trackColor = trackColor
        self.fillColor = fillColor
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
    }

    func makeUIView(context: Context) -> ProgressScrubberView {
        let view = ProgressScrubberView()
        view.onDragChanged = onDragChanged
        view.onDragEnded = onDragEnded
        view.updateColors(trackColor: UIColor(trackColor), fillColor: UIColor(fillColor))
        return view
    }

    func updateUIView(_ uiView: ProgressScrubberView, context: Context) {
        uiView.updateProgress(progress, isDragging: isDragging)
        uiView.updateColors(trackColor: UIColor(trackColor), fillColor: UIColor(fillColor))
    }
}

class ProgressScrubberView: UIView {
    var onDragChanged: ((CGFloat) -> Void)?
    var onDragEnded: ((CGFloat) -> Void)?

    private let trackLayer = CALayer()
    private let progressLayer = CALayer()
    private let thumbLayer = CALayer()

    private var currentProgress: CGFloat = 0
    private var isDragging = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
        setupGesture()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
        setupGesture()
    }

    private func setupLayers() {
        // Background track
        trackLayer.backgroundColor = UIColor.white.withAlphaComponent(0.3).cgColor
        trackLayer.cornerRadius = 2
        layer.addSublayer(trackLayer)

        // Progress fill
        progressLayer.backgroundColor = UIColor.white.cgColor
        progressLayer.cornerRadius = 2
        layer.addSublayer(progressLayer)

        // Thumb
        thumbLayer.backgroundColor = UIColor.white.cgColor
        thumbLayer.shadowColor = UIColor.black.cgColor
        thumbLayer.shadowOpacity = 0.3
        thumbLayer.shadowOffset = CGSize(width: 0, height: 1)
        thumbLayer.shadowRadius = 2
        layer.addSublayer(thumbLayer)
    }

    private func setupGesture() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.delegate = self
        addGestureRecognizer(panGesture)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)
        let progress = max(0, min(1, location.x / bounds.width))

        switch gesture.state {
        case .began, .changed:
            isDragging = true
            currentProgress = progress
            updateLayerPositions(animated: false)
            onDragChanged?(progress)
        case .ended, .cancelled:
            isDragging = false
            onDragEnded?(progress)
            updateLayerPositions(animated: true)
        default:
            break
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        let progress = max(0, min(1, location.x / bounds.width))
        currentProgress = progress
        updateLayerPositions(animated: true)
        onDragChanged?(progress)
        onDragEnded?(progress)
    }

    func updateProgress(_ progress: Double, isDragging: Bool) {
        // Only update from external source if not currently dragging
        if !self.isDragging {
            self.currentProgress = CGFloat(progress)
            self.isDragging = isDragging
            updateLayerPositions(animated: false)
        }
    }

    func updateColors(trackColor: UIColor, fillColor: UIColor) {
        trackLayer.backgroundColor = trackColor.cgColor
        progressLayer.backgroundColor = fillColor.cgColor
        thumbLayer.backgroundColor = fillColor.cgColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayerPositions(animated: false)
    }

    private func updateLayerPositions(animated: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)

        let trackHeight: CGFloat = 4
        let trackY = (bounds.height - trackHeight) / 2

        // Background track
        trackLayer.frame = CGRect(x: 0, y: trackY, width: bounds.width, height: trackHeight)

        // Progress fill
        let progressWidth = max(0, bounds.width * currentProgress)
        progressLayer.frame = CGRect(x: 0, y: trackY, width: progressWidth, height: trackHeight)

        // Thumb
        let thumbSize: CGFloat = isDragging ? 16 : 12
        thumbLayer.cornerRadius = thumbSize / 2
        let thumbX = max(0, min(bounds.width - thumbSize, progressWidth - thumbSize / 2))
        let thumbY = (bounds.height - thumbSize) / 2
        thumbLayer.frame = CGRect(x: thumbX, y: thumbY, width: thumbSize, height: thumbSize)

        CATransaction.commit()
    }
}

extension ProgressScrubberView: UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Don't allow simultaneous recognition - we want exclusive control
        return false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // We should NOT require failure of other gestures - we want to take priority
        return false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Other gestures (like TabView's scroll) should wait for us to fail first
        // This gives our gesture priority
        return true
    }
}

// MARK: - Spotify Image URL Helper

/// Upgrades Spotify album art URLs to the highest quality (640x640)
/// Spotify image URLs follow the pattern: https://i.scdn.co/image/ab67616d{size}...
/// Size codes: 0000b273 (640px), 00001e02 (300px), 00004851 (64px)
func highQualityAlbumArtUrl(_ urlString: String?) -> URL? {
    guard let urlString = urlString else { return nil }

    // Spotify image URL pattern
    let spotifyImagePattern = "i.scdn.co/image/ab67616d"

    if urlString.contains(spotifyImagePattern) {
        // Replace any size code with the 640x640 code
        var upgraded = urlString
        upgraded = upgraded.replacingOccurrences(of: "ab67616d00001e02", with: "ab67616d0000b273") // 300 -> 640
        upgraded = upgraded.replacingOccurrences(of: "ab67616d00004851", with: "ab67616d0000b273") // 64 -> 640
        return URL(string: upgraded)
    }

    // For non-Spotify URLs, return as-is
    return URL(string: urlString)
}

// MARK: - Pre-Pick Gate View

struct PrePickGateView: View {
    let onSelectSong: () -> Void
    let firstSongArtworkUrl: String?
    @Environment(\.colorScheme) var colorScheme

    // Track if background image loaded successfully for dynamic text colors
    @State private var backgroundImageLoaded = false

    // Dynamic colors based on whether artwork loaded
    // When artwork loads: use white text (blurred artwork provides colorful background)
    // When artwork fails: adapt to light/dark mode
    private var textColor: Color {
        if backgroundImageLoaded {
            return .white
        }
        return colorScheme == .dark ? .white : .black
    }

    private var subtextColor: Color {
        if backgroundImageLoaded {
            return .white.opacity(0.7)
        }
        return colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.5)
    }

    private var buttonBackground: Color {
        // Always use accent blue for maximum visibility and tap likelihood
        return .accentColor
    }

    private var buttonTextColor: Color {
        // White text on blue background
        return .white
    }

    private var gradientBackground: some View {
        // Flat solid background - adapts to light/dark mode
        Color(colorScheme == .dark ? .black : .white)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background - Dynamic album art or fallback gradient
                if let urlString = firstSongArtworkUrl,
                   let url = highQualityAlbumArtUrl(urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .blur(radius: 60)
                                .scaleEffect(1.2) // Prevent blur edges from showing
                                .onAppear { backgroundImageLoaded = true }
                        case .failure:
                            gradientBackground
                                .onAppear { backgroundImageLoaded = false }
                        case .empty:
                            gradientBackground
                        @unknown default:
                            gradientBackground
                                .onAppear { backgroundImageLoaded = false }
                        }
                    }
                    .ignoresSafeArea()
                } else {
                    gradientBackground
                        .ignoresSafeArea()
                        .onAppear { backgroundImageLoaded = false }
                }

                // Subtle dark overlay for better text legibility when artwork is showing
                if backgroundImageLoaded {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                }

                // Content - all grouped together, centered on screen
                VStack(spacing: 0) {
                    Spacer()

                    // All content as one cohesive group
                    VStack(spacing: 24) {
                        // Sparkles icon cluster
                        ZStack {
                            Image(systemName: "sparkle")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(subtextColor)
                                .offset(x: -24, y: -20)

                            Image(systemName: "sparkle")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(subtextColor)
                                .offset(x: 20, y: -28)

                            Image(systemName: "sparkle")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(subtextColor)
                        }
                        .frame(height: 60)

                        // Title text
                        Text("see what your phlock picked")
                            .font(.lora(size: 26, weight: .bold))
                            .foregroundColor(textColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        // CTA Button - directly under title
                        Button(action: onSelectSong) {
                            Text("share to find out")
                                .font(.lora(size: 17, weight: .semiBold))
                                .foregroundColor(buttonTextColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(buttonBackground)
                                .cornerRadius(28)
                        }
                        .padding(.horizontal, 32)

                        // Subtext
                        Text("give one to get five")
                            .font(.lora(size: 13))
                            .foregroundColor(subtextColor)
                            .multilineTextAlignment(.center)
                    }

                    Spacer()

                    // Bottom spacing for tab bar
                    Spacer()
                        .frame(height: 80)
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Phlock Carousel View

struct PhlockCarouselView: View {
    let items: [PhlockView.PhlockItem]
    let dailySongs: [Share]
    let myDailySong: Share?
    let savedTrackIds: Set<String>
    let nudgedUserIds: Set<UUID>

    let onPlayTapped: (Share, Bool, Double?) -> Void  // (song, autoPlay, seekToPosition)
    let onSwapTapped: (User) -> Void
    let onAddToLibrary: (Share) -> Void
    let onRemoveFromLibrary: (Share) -> Void
    let onProfileTapped: (User) -> Void
    let onNudgeTapped: (User) -> Void
    let onAddMemberTapped: () -> Void
    let onChangeDailySong: () -> Void
    let onOpenFullPlayer: () -> Void
    let onEditSwapTapped: (User) -> Void  // Edit mode: swap member
    let onEditRemoveTapped: (User) -> Void  // Edit mode: remove member
    let onEditAddTapped: () -> Void  // Edit mode: add member
    let onMenuTapped: () -> Void  // Open phlock manager sheet
    let onShareTapped: () -> Void  // Share phlock card

    @EnvironmentObject var playbackService: PlaybackService
    @EnvironmentObject var authState: AuthenticationState
    @State private var currentIndex: Int = 1 // Start at 1 because index 0 is phantom last page
    @State private var lastQueueIndex: Int? = nil // Track previous queue index for wrap detection
    @State private var isAnimatingWrap: Bool = false // Prevent conflicts during wrap animation
    @State private var hasInitialized: Bool = false // Track if we've done initial setup
    @State private var isUserDrivenChange: Bool = false // Prevent queue index listener from interfering with user-initiated changes
    @State private var isHandlingCardChange: Bool = false // Prevent queue listener from interfering during card change processing
    @State private var wasPlayingBeforeNonSongPage: Bool = false // Track play state when leaving song page for non-song page
    @State private var lastPageHadSong: Bool = true // Track if the last visited page had a song
    @State private var isEditMode: Bool = false  // Edit mode state
    @Environment(\.colorScheme) var colorScheme

    // Persistent storage for carousel position
    @AppStorage("phlockCarouselIndex") private var savedCarouselIndex: Int = 0

    // Base phlock members (always 5 slots)
    private var baseMembers: [PhlockSlot] {
        var slots: [PhlockSlot] = []

        // First: members with songs (sorted by streak count, highest first)
        let membersWithSongs = items
            .filter { $0.type == .song }
            .sorted { ($0.member?.dailySongStreak ?? 0) > ($1.member?.dailySongStreak ?? 0) }
        for item in membersWithSongs {
            if let member = item.member, let song = item.song {
                slots.append(PhlockSlot(member: member, song: song, type: .song))
            }
        }

        // Second: members without songs (sorted by streak count, highest first)
        let membersWaiting = items
            .filter { $0.type == .waiting }
            .sorted { ($0.member?.dailySongStreak ?? 0) > ($1.member?.dailySongStreak ?? 0) }
        for item in membersWaiting {
            if let member = item.member {
                slots.append(PhlockSlot(member: member, song: nil, type: .waiting))
            }
        }

        // Third: empty slots (pad to 5)
        let emptyCount = items.filter { $0.type == .empty }.count
        for i in 0..<emptyCount {
            slots.append(PhlockSlot(member: nil, song: nil, type: .empty, emptySlotIndex: i))
        }

        return slots
    }

    // Extended array for infinite scroll: [last] + [all items] + [first]
    // This allows wrapping: swiping past first goes to last, past last goes to first
    private var extendedMembers: [PhlockSlot] {
        guard baseMembers.count > 1 else { return baseMembers }
        var extended = baseMembers
        // Add last item at the beginning (phantom page for wrapping to end)
        extended.insert(baseMembers.last!, at: 0)
        // Add first item at the end (phantom page for wrapping to start)
        extended.append(baseMembers.first!)
        return extended
    }

    // Convert extended index to real index (for display purposes)
    private var realIndex: Int {
        guard baseMembers.count > 1 else { return currentIndex }
        if currentIndex == 0 {
            return baseMembers.count - 1 // Phantom first -> real last
        } else if currentIndex == extendedMembers.count - 1 {
            return 0 // Phantom last -> real first
        } else {
            return currentIndex - 1 // Offset by 1 due to phantom page at start
        }
    }

    var body: some View {
        ZStack {
            // Horizontal carousel with extended pages for infinite scroll
            TabView(selection: $currentIndex) {
                ForEach(Array(extendedMembers.enumerated()), id: \.offset) { index, slot in
                    PhlockCardView(
                        slot: slot,
                        isPlaying: isPlayingSlot(slot),
                        isSaved: isSavedSlot(slot),
                        isNudged: isNudgedSlot(slot),
                        isEditMode: isEditMode,
                        playbackService: playbackService,
                        onPlayTapped: {
                            if let song = slot.song {
                                // Always look up saved position for resume capability
                                let savedPosition = playbackService.getSavedPosition(for: song.trackId)
                                onPlayTapped(song, true, savedPosition)
                            }
                        },
                        onSwapTapped: { if let member = slot.member { onSwapTapped(member) } },
                        onAddToLibrary: { if let song = slot.song { onAddToLibrary(song) } },
                        onRemoveFromLibrary: { if let song = slot.song { onRemoveFromLibrary(song) } },
                        onProfileTapped: { if let member = slot.member { onProfileTapped(member) } },
                        onNudgeTapped: { if let member = slot.member { onNudgeTapped(member) } },
                        onAddMemberTapped: onAddMemberTapped,
                        onEditSwapTapped: { if let member = slot.member { onEditSwapTapped(member) } },
                        onEditRemoveTapped: { if let member = slot.member { onEditRemoveTapped(member) } },
                        onEditAddTapped: onEditAddTapped
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            // NOTE: Removed .id(itemsContentHash) - it was causing carousel position
            // to reset during user navigation. The TabView updates naturally when
            // items change without needing a forced rebuild.

            // MARK: - Commented out: Your pick bar at top (may re-implement later)
            // VStack {
            //     if let mySong = myDailySong {
            //         YourPickBar(song: mySong, onTap: onOpenFullPlayer)
            //             .padding(.top, 12)
            //     }
            //     Spacer()
            // }

            // Overlay: Action buttons + Profile indicator bar at bottom
            VStack(spacing: 20) {
                Spacer()

                // Waiting card action buttons (nudge/swap)
                if let currentSlot = extendedMembers[safe: currentIndex],
                   currentSlot.type == .waiting,
                   let member = currentSlot.member {
                    WaitingCardActionButtons(
                        member: member,
                        isNudged: nudgedUserIds.contains(member.id),
                        onNudgeTapped: { onNudgeTapped(member) },
                        onSwapTapped: { onSwapTapped(member) }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                // Use baseMembers for indicator (real slots only, not phantom)
                // and realIndex for highlighting correct dot
                ProfileIndicatorBar(
                    slots: baseMembers,
                    currentIndex: realIndex,
                    isEditMode: isEditMode,
                    onTap: { index in
                        // Mark as user-driven to prevent queue index listener from interfering
                        isUserDrivenChange = true
                        isHandlingCardChange = true

                        // Convert real index to extended index (+1 for phantom page at start)
                        let targetIndex = index + 1

                        // Use transaction to ensure atomic index update without interference
                        var transaction = Transaction(animation: .easeInOut(duration: 0.3))
                        withTransaction(transaction) {
                            currentIndex = targetIndex
                        }

                        // Also update saved position immediately
                        savedCarouselIndex = index

                        // Reset flags after animation + playback settle (longer window)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            isUserDrivenChange = false
                            isHandlingCardChange = false
                        }
                    },
                    onProfileTapped: onProfileTapped,
                    onEditTapped: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isEditMode.toggle()
                        }
                    },
                    onMenuTapped: onMenuTapped,
                    onShareTapped: onShareTapped
                )
                .padding(.bottom, 16) // Just above tab bar
            }
            .animation(.easeInOut(duration: 0.25), value: currentIndex)
        }
        .onChange(of: currentIndex) { newIndex in
            // DEBUG: Track all currentIndex changes
            print("📍 currentIndex changed to \(newIndex) (isUserDrivenChange=\(isUserDrivenChange), isAnimatingWrap=\(isAnimatingWrap))")

            // Skip handleCardChange during wrap animation to avoid interfering with playback
            if !isAnimatingWrap {
                handleCardChange(newIndex)
            }

            // Infinite scroll: jump to real page when landing on phantom page
            let memberCount = baseMembers.count
            guard memberCount > 1 else { return }

            // Landed on phantom first page (index 0) -> jump to real last
            // Don't update previousIndex here - these are visual corrections, not user navigation
            if newIndex == 0 {
                // Use CATransaction to truly disable all animations including implicit ones
                DispatchQueue.main.async {
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    CATransaction.setAnimationDuration(0)
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        currentIndex = memberCount // Real last is at index memberCount (since index 1 is first real)
                    }
                    CATransaction.commit()
                }
            }
            // Landed on phantom last page -> jump to real first
            else if newIndex == extendedMembers.count - 1 {
                // Use longer delay during wrap animation to let animation complete
                let delay = isAnimatingWrap ? 0.35 : 0.0
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    CATransaction.setAnimationDuration(0)
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        currentIndex = 1 // Real first is at index 1
                    }
                    CATransaction.commit()
                    isAnimatingWrap = false
                }
            }
        }
        .onChange(of: playbackService.currentQueueIndex) { newQueueIndex in
            // Sync carousel position when PlaybackService advances (e.g., autoplay)
            guard let queueIndex = newQueueIndex else {
                lastQueueIndex = nil
                return
            }

            // Skip if user is actively changing the carousel position or if we're
            // in the middle of handling a card change (which triggers its own queue update)
            // This prevents interfering with user-initiated navigation
            if isUserDrivenChange || isHandlingCardChange {
                print("🔇 Queue change ignored (isUserDrivenChange=\(isUserDrivenChange), isHandlingCardChange=\(isHandlingCardChange))")
                lastQueueIndex = queueIndex
                return
            }

            // IMPORTANT: Only sync carousel if the current track is from OUR phlock
            // This prevents responding to queue changes from ProfileView or other views
            let phlockTrackIds = baseMembers.compactMap { $0.song?.trackId }
            guard let currentTrackId = playbackService.currentTrack?.id,
                  phlockTrackIds.contains(currentTrackId) else {
                // Not playing a phlock track - ignore queue changes from other views
                lastQueueIndex = queueIndex
                return
            }

            // The queue in PlaybackService corresponds to dailySongs (songs only)
            // We need to find which carousel index maps to this queue index
            // Queue index maps directly to song slots in baseMembers
            let songSlots = baseMembers.enumerated().filter { $0.element.type == .song }
            guard queueIndex < songSlots.count else {
                lastQueueIndex = queueIndex
                return
            }

            // CRITICAL FIX: When handleCardChange loads a single track via onPlayTapped,
            // the queue becomes a single-item queue with index 0. This would incorrectly
            // map to songSlots[0] even if we loaded a different song.
            // To prevent this, verify the current track matches the target slot.
            let targetSlot = songSlots[queueIndex]
            guard targetSlot.element.song?.trackId == currentTrackId else {
                // The queue index doesn't match the actual track being played.
                // This happens when handleCardChange loads a single song into a new queue.
                // The carousel is already at the correct position from user interaction,
                // so we should NOT override it here.
                lastQueueIndex = queueIndex
                return
            }

            let targetRealIndex = targetSlot.offset
            let targetExtendedIndex = targetRealIndex + 1 // +1 for phantom page at start

            // Detect wrap-around: going from last song to first song
            // Check both lastQueueIndex AND current carousel position for reliable detection
            let songCount = songSlots.count
            let lastSongExtendedIndex = songCount // Last song is at index songCount in extended array
            let isCurrentlyOnLastSong = currentIndex == lastSongExtendedIndex || currentIndex == extendedMembers.count - 1
            let isWrappingToFirst = queueIndex == 0 && (lastQueueIndex == songCount - 1 || isCurrentlyOnLastSong)

            // Update last queue index for next change detection
            lastQueueIndex = queueIndex

            // Only update if different (avoid loops)
            if currentIndex != targetExtendedIndex {
                if isWrappingToFirst && baseMembers.count > 1 {
                    // For wrap-around: use instant jump (no animation) to avoid phantom page glitches
                    // The audio already switched, so instant visual switch is expected
                    isAnimatingWrap = true
                    currentIndex = 1 // Jump directly to first real page
                    // Reset flag after a brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isAnimatingWrap = false
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentIndex = targetExtendedIndex
                    }
                }
            }
        }
        .onAppear {
            // DEBUG: Track when onAppear is called
            print("🔄 PhlockCarouselView.onAppear called - hasInitialized=\(hasInitialized) currentIndex=\(currentIndex) isUserDrivenChange=\(isUserDrivenChange)")

            // CRITICAL: Skip restoration if user is actively navigating
            // This prevents the view recreation from overriding user's tap navigation
            if isUserDrivenChange || isHandlingCardChange {
                print("🔄 Skipping onAppear logic - user navigation in progress")
                return
            }

            // Initialize lastQueueIndex to current queue position for reliable wrap detection
            lastQueueIndex = playbackService.currentQueueIndex

            // Check if any phlock song is already loaded (user returning to tab)
            let phlockTrackIds = baseMembers.compactMap { $0.song?.trackId }
            let isAlreadyPlayingPhlock = playbackService.currentTrack != nil &&
                phlockTrackIds.contains(playbackService.currentTrack?.id ?? "")

            if !hasInitialized && !isAlreadyPlayingPhlock {
                // Fresh start - initialize and auto-play
                hasInitialized = true

                // Restore saved carousel position (with bounds checking)
                let restoredIndex = min(savedCarouselIndex, max(0, baseMembers.count - 1))
                if baseMembers.count > 1 {
                    currentIndex = restoredIndex + 1 // +1 for phantom page offset
                } else {
                    currentIndex = max(0, restoredIndex)
                }
                print("🔄 Fresh start - restored to index \(currentIndex)")
                // Initialize lastPageHadSong based on restored position
                lastPageHadSong = extendedMembers[safe: currentIndex]?.song != nil

                // Only auto-play if no track is loaded at all (fresh app launch)
                if playbackService.currentTrack == nil {
                    let currentSlot = extendedMembers[safe: currentIndex]
                    if let song = currentSlot?.song {
                        onPlayTapped(song, true, nil)  // Fresh launch = autoPlay, no seek
                    }
                }
            } else if isAlreadyPlayingPhlock {
                // Returning to tab with a phlock song loaded - sync carousel to current track
                hasInitialized = true
                if let currentTrackId = playbackService.currentTrack?.id,
                   let matchingIndex = baseMembers.firstIndex(where: { $0.song?.trackId == currentTrackId }) {
                    if baseMembers.count > 1 {
                        currentIndex = matchingIndex + 1 // +1 for phantom page offset
                    } else {
                        currentIndex = matchingIndex
                    }
                    savedCarouselIndex = matchingIndex
                    lastPageHadSong = true // We're on a song page
                    print("🔄 Returning to phlock tab - synced to playing track at index \(currentIndex)")
                }
            } else if hasInitialized && playbackService.currentTrack != nil && !isAlreadyPlayingPhlock {
                // Returning to phlock tab with a non-phlock track playing
                // Override with the phlock track at the current carousel position
                let currentSlot = extendedMembers[safe: currentIndex]
                if let song = currentSlot?.song {
                    // Get saved position for this phlock track (may be nil if never played)
                    let savedPosition = playbackService.getSavedPosition(for: song.trackId)
                    // Resume the phlock track, starting playback immediately
                    onPlayTapped(song, true, savedPosition)
                    print("🔄 Returning from other view - resuming phlock track")
                }
            } else {
                print("🔄 Already initialized, preserving current state at index \(currentIndex)")
            }
            // If already initialized and no track playing, preserve current state

        }
    }

    // MARK: - Helpers

    private func isPlayingSlot(_ slot: PhlockSlot) -> Bool {
        guard let song = slot.song else { return false }
        return playbackService.currentTrack?.id == song.trackId && playbackService.isPlaying
    }

    private func isSavedSlot(_ slot: PhlockSlot) -> Bool {
        guard let song = slot.song else { return false }
        return savedTrackIds.contains(song.trackId)
    }

    private func isNudgedSlot(_ slot: PhlockSlot) -> Bool {
        guard let member = slot.member else { return false }
        return nudgedUserIds.contains(member.id)
    }

    private func handleCardChange(_ newIndex: Int) {
        // Skip haptic/playback for phantom pages (will jump immediately anyway)
        let memberCount = baseMembers.count
        if memberCount > 1 && (newIndex == 0 || newIndex == extendedMembers.count - 1) {
            return
        }

        // Save the real index for persistence (convert extended index to real index)
        let realIdx: Int
        if memberCount > 1 {
            if newIndex == 0 {
                realIdx = memberCount - 1
            } else if newIndex == extendedMembers.count - 1 {
                realIdx = 0
            } else {
                realIdx = newIndex - 1
            }
        } else {
            realIdx = newIndex
        }
        savedCarouselIndex = realIdx

        // Get the new slot
        let newSlot = extendedMembers[safe: newIndex]
        let newSong = newSlot?.song
        let newPageHasSong = newSong != nil

        // Debug: Log transition details
        print("🎵 Transition: newIdx=\(newIndex) lastPageHadSong=\(lastPageHadSong) newPageHasSong=\(newPageHasSong)")

        // Capture current play state BEFORE any changes
        let wasPlaying = playbackService.isPlaying

        // Track play state when transitioning from song to non-song page
        if lastPageHadSong && !newPageHasSong {
            wasPlayingBeforeNonSongPage = wasPlaying
            print("🎵 Saved play state before non-song page: \(wasPlaying)")
        }

        // Remember if this page has a song for the next transition
        let previousPageHadSong = lastPageHadSong
        lastPageHadSong = newPageHasSong

        // IMPORTANT: Don't auto-start playback if another view owns the current playback
        // This prevents interfering with ProfileView or other views' playback
        let phlockTrackIds = baseMembers.compactMap { $0.song?.trackId }
        let isPhlockOwningPlayback = playbackService.currentTrack == nil ||
            phlockTrackIds.contains(playbackService.currentTrack?.id ?? "")

        guard isPhlockOwningPlayback else {
            // Another view (e.g., ProfileView) owns playback - don't interfere
            return
        }

        // Prepare haptic generator (must be done on main thread before impactOccurred)
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.prepare()

        // Save current track position before switching
        playbackService.saveCurrentPosition()

        // Determine if we should auto-play when arriving at a song page
        let shouldAutoPlay: Bool
        if !previousPageHadSong && newPageHasSong {
            // Coming from a non-song page to a song page - restore previous state
            shouldAutoPlay = wasPlayingBeforeNonSongPage
            print("🎵 Restoring play state from non-song page: \(wasPlayingBeforeNonSongPage)")
        } else if previousPageHadSong && newPageHasSong {
            // Song to song transition - use current play state
            shouldAutoPlay = wasPlaying
        } else {
            // Non-song to non-song or song to non-song - no auto-play needed
            shouldAutoPlay = false
        }

        // Check if we're switching to the same track that's already playing
        if let song = newSong, playbackService.currentTrack?.id == song.trackId {
            // Same track - don't restart, just provide haptic
            impact.impactOccurred()
            return
        }

        // Signal that we're switching tracks - this prevents the old time observer
        // from updating currentTime and causing visual jitter
        playbackService.beginTrackSwitch()

        // Pre-set currentTime to the saved position for the NEW track BEFORE loading
        // This prevents the progress bar from jumping to 0 and then back to the saved position
        if let song = newSong {
            if let savedPosition = playbackService.getSavedPosition(for: song.trackId) {
                playbackService.currentTime = savedPosition
            } else {
                playbackService.currentTime = 0
            }
        }

        // Mark that we're handling a card change to prevent queue listener from interfering
        // Only set if not already set (user-driven change sets it with longer timeout)
        let wasAlreadyHandling = isHandlingCardChange
        if !wasAlreadyHandling {
            isHandlingCardChange = true
            print("🔒 isHandlingCardChange = true (from handleCardChange)")
        }

        // Perform non-blocking operations asynchronously
        Task { @MainActor in
            // Pause current playback (position already saved above)
            playbackService.pause()

            // Load new track if this card has a song
            if let song = newSong {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms delay

                // Get saved position for this track
                let savedPosition = playbackService.getSavedPosition(for: song.trackId)

                // Pass shouldAutoPlay (based on state before leaving song page) and savedPosition
                onPlayTapped(song, shouldAutoPlay, savedPosition)
            }

            // Haptic feedback
            impact.impactOccurred()

            // Only reset flag if we were the ones who set it (not user-driven change)
            if !wasAlreadyHandling {
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                isHandlingCardChange = false
                print("🔓 isHandlingCardChange = false (from handleCardChange)")
            }
        }
    }
}

// MARK: - Phlock Slot Model

struct PhlockSlot: Identifiable {
    let member: User?
    let song: Share?
    let type: SlotType
    let emptySlotIndex: Int?

    init(member: User?, song: Share?, type: SlotType, emptySlotIndex: Int? = nil) {
        self.member = member
        self.song = song
        self.type = type
        self.emptySlotIndex = emptySlotIndex
    }

    // Stable ID based on content, not random UUID
    // This prevents SwiftUI from recreating views when the data hasn't changed
    var id: String {
        switch type {
        case .song:
            return "song-\(member?.id.uuidString ?? "unknown")-\(song?.trackId ?? "unknown")"
        case .waiting:
            return "waiting-\(member?.id.uuidString ?? "unknown")"
        case .empty:
            return "empty-\(emptySlotIndex ?? 0)"
        }
    }

    enum SlotType {
        case song
        case waiting
        case empty
    }
}

// MARK: - Your Pick Bar

struct YourPickBar: View {
    let song: Share
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var subtextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.5)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Album artwork
                if let urlString = song.albumArtUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.2))
                    }
                    .frame(width: 44, height: 44)
                    .cornerRadius(6)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 16))
                                .foregroundColor(subtextColor)
                        )
                }

                // Song info
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.trackName)
                        .font(.lora(size: 15, weight: .semiBold))
                        .foregroundColor(textColor)
                        .lineLimit(1)

                    Text(song.artistName)
                        .font(.lora(size: 13))
                        .foregroundColor(subtextColor)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 20)
            .padding(.vertical, 12)
            .background {
                if #available(iOS 26.0, *) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.clear)
                        .glassEffect(.regular.interactive())
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.15), radius: 10, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Profile Indicator Bar

struct ProfileIndicatorBar: View {
    let slots: [PhlockSlot]
    let currentIndex: Int
    let isEditMode: Bool
    let onTap: (Int) -> Void
    let onProfileTapped: (User) -> Void
    let onEditTapped: () -> Void
    let onMenuTapped: () -> Void
    let onShareTapped: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        // Use overlay to position menu button without affecting pill centering
        HStack(spacing: 8) {
            ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                ProfileIndicatorCircle(
                    slot: slot,
                    isActive: index == currentIndex
                )
                .onTapGesture {
                    if index == currentIndex, let member = slot.member {
                        // Already on this user - navigate to their profile
                        onProfileTapped(member)
                    } else {
                        // Switch to this user's card
                        onTap(index)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            if #available(iOS 26.0, *) {
                Capsule()
                    .fill(.clear)
                    .glassEffect(.regular.interactive())
            } else {
                Group {
                    if colorScheme == .dark {
                        Capsule()
                            .fill(Color.black.opacity(0.3))
                            .shadow(color: Color.black.opacity(0.25), radius: 10, y: 4)
                    } else {
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.15), radius: 10, y: 4)
                    }
                }
            }
        }
        .overlay(alignment: .leading) {
            // Three-dot menu button positioned to the left of the pill
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                onMenuTapped()
            }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .rotationEffect(.degrees(90))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .frame(width: 40, height: 40)
                    .background {
                        if #available(iOS 26.0, *) {
                            Circle()
                                .fill(.clear)
                                .glassEffect(.regular.interactive())
                        } else {
                            Group {
                                if colorScheme == .dark {
                                    Circle()
                                        .fill(Color.black.opacity(0.3))
                                        .shadow(color: Color.black.opacity(0.25), radius: 10, y: 4)
                                } else {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .shadow(color: Color.black.opacity(0.15), radius: 10, y: 4)
                                }
                            }
                        }
                    }
            }
            .offset(x: -52) // Position to the left of the pill with 12pt gap
        }
        .overlay(alignment: .trailing) {
            // Share button positioned to the right of the pill
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                onShareTapped()
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .frame(width: 40, height: 40)
                    .background {
                        if #available(iOS 26.0, *) {
                            Circle()
                                .fill(.clear)
                                .glassEffect(.regular.interactive())
                        } else {
                            Group {
                                if colorScheme == .dark {
                                    Circle()
                                        .fill(Color.black.opacity(0.3))
                                        .shadow(color: Color.black.opacity(0.25), radius: 10, y: 4)
                                } else {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .shadow(color: Color.black.opacity(0.15), radius: 10, y: 4)
                                }
                            }
                        }
                    }
            }
            .offset(x: 52) // Position to the right of the pill with 12pt gap
        }
    }
}

struct ProfileIndicatorCircle: View {
    let slot: PhlockSlot
    let isActive: Bool
    @Environment(\.colorScheme) var colorScheme

    private var size: CGFloat { isActive ? 44 : 36 }

    private var borderColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var textColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var subtextColor: Color {
        colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.3)
    }

    var body: some View {
        ZStack {
            switch slot.type {
            case .song, .waiting:
                if let member = slot.member {
                    // Profile photo
                    if let avatarUrl = member.profilePhotoUrl, let url = URL(string: avatarUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle().fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: size, height: size)
                            .overlay(
                                Text(String(member.displayName.prefix(1)).uppercased())
                                    .font(.lora(size: isActive ? 18 : 14, weight: .medium))
                                    .foregroundColor(textColor)
                            )
                    }
                }

            case .empty:
                Circle()
                    .stroke(subtextColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: isActive ? 16 : 12))
                            .foregroundColor(subtextColor)
                    )
            }
        }
        .overlay(
            Circle()
                .stroke(borderColor, lineWidth: isActive ? 3 : 0)
                .frame(width: size + 4, height: size + 4)
        )
        .overlay(alignment: .bottom) {
            // Fire streak badge with number (only show if member has a streak)
            if let member = slot.member, member.dailySongStreak > 0 {
                HStack(spacing: 1) {
                    Text("🔥")
                        .font(.system(size: isActive ? 9 : 7))
                    Text("\(member.dailySongStreak)")
                        .font(.system(size: isActive ? 9 : 7, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.6))
                )
                .offset(y: isActive ? 8 : 6)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isActive)
    }
}

// MARK: - Waiting Card Action Buttons

struct WaitingCardActionButtons: View {
    let member: User
    let isNudged: Bool
    let onNudgeTapped: () -> Void
    let onSwapTapped: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var buttonTextColor: Color {
        colorScheme == .dark ? .black : .black
    }

    var body: some View {
        HStack(spacing: 16) {
            // Nudge button (primary)
            Button(action: onNudgeTapped) {
                HStack(spacing: 8) {
                    Text(isNudged ? "✓" : "👋")
                    Text(isNudged ? "nudged" : "nudge")
                }
                .font(.lora(size: 16, weight: .semiBold))
                .foregroundColor(buttonTextColor)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background {
                    if #available(iOS 26.0, *) {
                        Capsule()
                            .fill(.clear)
                            .glassEffect(.regular.interactive())
                    } else {
                        Group {
                            if colorScheme == .dark {
                                Capsule()
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.2), radius: 10, y: 4)
                            } else {
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: Color.black.opacity(0.15), radius: 10, y: 4)
                            }
                        }
                    }
                }
            }
            .disabled(isNudged)
            .opacity(isNudged ? 0.7 : 1)

            // Swap button (secondary, same style)
            Button(action: onSwapTapped) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.swap")
                    Text("swap")
                }
                .font(.lora(size: 16, weight: .semiBold))
                .foregroundColor(buttonTextColor)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background {
                    if #available(iOS 26.0, *) {
                        Capsule()
                            .fill(.clear)
                            .glassEffect(.regular.interactive())
                    } else {
                        Group {
                            if colorScheme == .dark {
                                Capsule()
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.2), radius: 10, y: 4)
                            } else {
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: Color.black.opacity(0.15), radius: 10, y: 4)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Phlock Card View

struct PhlockCardView: View {
    let slot: PhlockSlot
    let isPlaying: Bool
    let isSaved: Bool
    let isNudged: Bool
    let isEditMode: Bool
    @ObservedObject var playbackService: PlaybackService
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme

    let onPlayTapped: () -> Void
    let onSwapTapped: () -> Void
    let onAddToLibrary: () -> Void
    let onRemoveFromLibrary: () -> Void
    let onProfileTapped: () -> Void
    let onNudgeTapped: () -> Void
    let onAddMemberTapped: () -> Void
    let onEditSwapTapped: () -> Void
    let onEditRemoveTapped: () -> Void
    let onEditAddTapped: () -> Void

    @State private var showPlayPauseIndicator = false
    @State private var isDraggingSlider = false
    @State private var sliderValue: Double = 0
    @State private var isSeeking = false
    @State private var backgroundImageLoaded = false
    @State private var backgroundImageIsBright = false  // Track if the loaded image is bright (needs dark text)

    // Dynamic colors based on background image brightness
    // When image loads: analyze brightness to determine if dark text is needed
    // Bright images (like white album covers) need dark text for legibility
    // When image fails: adapt to light/dark mode
    private var useDarkText: Bool {
        if backgroundImageLoaded {
            // Image loaded - use brightness analysis result
            return backgroundImageIsBright
        }
        // No image loaded - fall back to color scheme
        return colorScheme == .light
    }

    private var primaryTextColor: Color {
        useDarkText ? .black : .white
    }

    private var secondaryTextColor: Color {
        useDarkText ? .black.opacity(0.7) : .white.opacity(0.75)
    }

    private var tertiaryTextColor: Color {
        useDarkText ? .black.opacity(0.5) : .white.opacity(0.6)
    }

    private var iconColor: Color {
        useDarkText ? .black.opacity(0.7) : .white.opacity(0.7)
    }

    private var progressTrackColor: Color {
        useDarkText ? .black.opacity(0.2) : .white.opacity(0.3)
    }

    private var progressFillColor: Color {
        useDarkText ? .black : .white
    }

    // Color scheme adaptive colors (for waiting/empty cards)
    private var overlayOpacity: Double {
        colorScheme == .dark ? 0.4 : 0.0
    }

    private var textColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var subtextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.5)
    }

    private var buttonBackground: some View {
        colorScheme == .dark
            ? AnyView(Color.white)
            : AnyView(Capsule().fill(.ultraThinMaterial))
    }

    private var buttonTextColor: Color {
        colorScheme == .dark ? .black : .black
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background layer
                backgroundLayer(size: geometry.size)

                // Overlay for legibility
                Color.black.opacity(overlayOpacity)

                // Content based on slot type
                switch slot.type {
                case .song:
                    if let song = slot.song, let member = slot.member {
                        songCardContent(song: song, member: member, size: geometry.size)
                    }

                case .waiting:
                    if let member = slot.member {
                        waitingCardContent(member: member)
                    }

                case .empty:
                    emptyCardContent()
                }

                // Edit mode overlay
                if isEditMode {
                    editModeOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .animation(.easeInOut(duration: 0.25), value: isEditMode)
        }
        .ignoresSafeArea()
    }

    // MARK: - Edit Mode Overlay

    @ViewBuilder
    private var editModeOverlay: some View {
        VStack {
            Spacer()

            switch slot.type {
            case .song:
                // Song card: swap button (effective tomorrow since they've picked)
                Button(action: onEditSwapTapped) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.swap")
                        Text("swap (effective tomorrow)")
                    }
                    .font(.lora(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                }

            case .waiting:
                // Waiting card: swap button (immediate) + remove button (subtle)
                HStack(spacing: 16) {
                    Button(action: onEditSwapTapped) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.swap")
                            Text("swap")
                        }
                        .font(.lora(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                    }

                    Button(action: onEditRemoveTapped) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

            case .empty:
                // Empty slot: add member button
                Button(action: onEditAddTapped) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("add member")
                    }
                    .font(.lora(size: 16, weight: .semiBold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .cornerRadius(24)
                }
            }

            Spacer().frame(height: 180) // Above profile bar + tab bar
        }
    }

    // MARK: - Background

    @ViewBuilder
    private func backgroundLayer(size: CGSize) -> some View {
        switch slot.type {
        case .song:
            if let song = slot.song, let url = highQualityAlbumArtUrl(song.albumArtUrl) {
                // Use standard AsyncImage for fast cached loading
                AsyncImage(url: url, transaction: Transaction(animation: nil)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size.width, height: size.height)
                            .blur(radius: 50)
                            .onAppear {
                                backgroundImageLoaded = true
                                // Check cache first for instant result
                                if let cached = ImageBrightnessCache.shared.get(url.absoluteString) {
                                    backgroundImageIsBright = cached
                                } else {
                                    // Analyze in background using thumbnail URL for speed
                                    analyzeBrightness(for: song.albumArtUrl)
                                }
                            }
                    case .failure:
                        gradientBackground
                            .onAppear {
                                backgroundImageLoaded = false
                                backgroundImageIsBright = false
                            }
                    case .empty:
                        // Check cache immediately - if we have a result, apply it
                        Color(white: 0.1)
                            .onAppear {
                                if let cached = ImageBrightnessCache.shared.get(url.absoluteString) {
                                    backgroundImageIsBright = cached
                                }
                            }
                    @unknown default:
                        gradientBackground
                            .onAppear {
                                backgroundImageLoaded = false
                                backgroundImageIsBright = false
                            }
                    }
                }
            } else {
                gradientBackground
                    .onAppear {
                        backgroundImageLoaded = false
                        backgroundImageIsBright = false
                    }
            }

        case .waiting:
            if let member = slot.member, let urlString = member.profilePhotoUrl, let url = URL(string: urlString) {
                AsyncImage(url: url, transaction: Transaction(animation: nil)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size.width, height: size.height)
                            .blur(radius: 40)
                    case .failure:
                        gradientBackground
                    case .empty:
                        // Use a dark color during loading to prevent flash
                        Color(white: 0.1)
                    @unknown default:
                        gradientBackground
                    }
                }
            } else {
                gradientBackground
            }

        case .empty:
            gradientBackground
        }
    }

    private var gradientBackground: some View {
        // Light background in light mode, dark in dark mode
        // Text colors will adapt dynamically based on backgroundImageLoaded state
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(white: 0.15), Color(white: 0.05)]
                : [Color(white: 0.95), Color(white: 0.85)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Analyzes image brightness using a small thumbnail for speed
    /// Downloads the smallest available image size (64px for Spotify) for fast analysis
    private func analyzeBrightness(for albumArtUrl: String?) {
        guard let urlString = albumArtUrl else { return }

        // Get both high-quality URL (for cache key) and thumbnail URL (for fast download)
        guard let highQualityUrl = highQualityAlbumArtUrl(urlString) else { return }
        let cacheKey = highQualityUrl.absoluteString

        // Already cached? Skip
        if ImageBrightnessCache.shared.get(cacheKey) != nil { return }

        // Use smallest Spotify thumbnail (64px) for fastest download
        let thumbnailUrlString: String
        if urlString.contains("i.scdn.co/image/ab67616d") {
            // Spotify: use 64px version
            thumbnailUrlString = urlString
                .replacingOccurrences(of: "ab67616d0000b273", with: "ab67616d00004851")
                .replacingOccurrences(of: "ab67616d00001e02", with: "ab67616d00004851")
        } else {
            thumbnailUrlString = urlString
        }

        guard let thumbnailUrl = URL(string: thumbnailUrlString) else { return }

        Task.detached(priority: .utility) {
            do {
                let (data, _) = try await URLSession.shared.data(from: thumbnailUrl)
                guard let image = UIImage(data: data) else { return }

                // Brightness calculation is thread-safe (pure computation on image data)
                let brightness = image.fastBrightness()
                let isBright = brightness > 0.55

                // Cache the result
                ImageBrightnessCache.shared.set(cacheKey, isBright: isBright)

                // Update UI on main actor
                await MainActor.run { [isBright] in
                    self.backgroundImageIsBright = isBright
                }
            } catch {
                // Silently fail - we'll just use default white text
            }
        }
    }

    // MARK: - Song Card Content

    @ViewBuilder
    private func songCardContent(song: Share, member: User, size: CGSize) -> some View {
        let artSize = min(size.width - 80, 320)

        ZStack {
            // Full-screen tap area for play/pause (behind everything)
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    togglePlayPause()
                }

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 100) // Space for top area

                // Centered album art with play/pause indicator
                ZStack {
                    if let url = highQualityAlbumArtUrl(song.albumArtUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure:
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .font(.system(size: 60))
                                            .foregroundColor(.white.opacity(0.5))
                                    )
                            case .empty:
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(
                                        ProgressView()
                                            .tint(.white)
                                    )
                            @unknown default:
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.3))
                            }
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white.opacity(0.5))
                            )
                    }

                    // Play/pause indicator centered on album art
                    if showPlayPauseIndicator {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.5), radius: 20)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: artSize, height: artSize)
                .cornerRadius(12)
                .clipped()
                .shadow(color: .black.opacity(0.5), radius: 30, y: 15)
                .allowsHitTesting(false) // Let tap pass through to background

                Spacer()
                    .frame(height: 28)

                // Song info
                VStack(spacing: 6) {
                    Text(song.trackName)
                        .font(.lora(size: 24, weight: .bold))
                        .foregroundColor(primaryTextColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Text(song.artistName)
                        .font(.lora(size: 17))
                        .foregroundColor(secondaryTextColor)
                        .lineLimit(1)
                }
                .padding(.horizontal, 30)
                .allowsHitTesting(false) // Let tap pass through to background

                Spacer()
                    .frame(height: 20)

                // Progress bar (keeps hit testing for scrubbing)
                progressBar
                    .padding(.horizontal, 40)

                // Username attribution (always shown) with optional message
                let username = member.username ?? member.displayName
                if let message = song.message, !message.isEmpty {
                    Text("@\(username): \"\(message)\"")
                        .font(.lora(size: 14))
                        .italic()
                        .foregroundColor(tertiaryTextColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                } else {
                    Text("@\(username)")
                        .font(.lora(size: 14))
                        .italic()
                        .foregroundColor(tertiaryTextColor)
                        .padding(.horizontal, 40)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }

                Spacer()
                    .frame(height: 20)

                // Action buttons (keep hit testing for button taps)
                HStack(spacing: 40) {
                    // Open in Spotify
                    Button(action: { openInStreamingApp(song: song) }) {
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 24))
                            Text("Open")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(iconColor)
                    }

                    // Save to library
                    Button(action: { isSaved ? onRemoveFromLibrary() : onAddToLibrary() }) {
                        VStack(spacing: 6) {
                            Image(systemName: isSaved ? "heart.fill" : "heart")
                                .font(.system(size: 24))
                                .foregroundColor(isSaved ? .red : iconColor)
                            Text(isSaved ? "Saved" : "Save")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(iconColor)
                    }
                }

                Spacer()
                    .frame(height: 160) // Room for profile indicator + tab bar
            }
        }
    }

    // MARK: - Progress Bar

    /// Safe duration that guards against NaN and invalid values
    private var durationSafe: Double {
        let duration = playbackService.duration
        if duration.isNaN || duration.isInfinite || duration <= 0 {
            return 30 // Fallback duration for preview tracks
        }
        return duration
    }

    /// Safe current time that guards against NaN and invalid values
    private var currentTimeSafe: Double {
        let time = playbackService.currentTime
        if time.isNaN || time.isInfinite || time < 0 {
            return 0
        }
        return min(time, durationSafe)
    }

    private var progressBar: some View {
        let currentTime = currentTimeSafe
        let duration = durationSafe
        let rawProgress = (isDraggingSlider || isSeeking) ? sliderValue / duration : currentTime / duration
        // Guard against NaN in progress calculation
        let progress = rawProgress.isNaN || rawProgress.isInfinite ? 0 : max(0, min(1, rawProgress))

        return VStack(spacing: 8) {
            // Custom scrubbable progress bar - matching FullScreenPlayerView implementation
            ProgressScrubber(
                progress: progress,
                isDragging: isDraggingSlider,
                trackColor: progressTrackColor,
                fillColor: progressFillColor,
                onDragChanged: { prog in
                    if !isDraggingSlider {
                        isDraggingSlider = true
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    }
                    sliderValue = Double(prog) * duration
                },
                onDragEnded: { prog in
                    let seekTime = Double(prog) * duration

                    // Set seeking state to prevent jump back
                    isSeeking = true
                    playbackService.seek(to: seekTime)
                    isDraggingSlider = false

                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()

                    // Reset seeking state after a delay to allow playback service to catch up
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        isSeeking = false
                    }
                }
            )
            .frame(height: 20)

            // Time labels
            HStack {
                Text(formatTime(isDraggingSlider ? sliderValue : currentTime))
                    .font(.lora(size: 10))
                    .foregroundColor(tertiaryTextColor)

                Spacer()

                Text(formatTime(duration))
                    .font(.lora(size: 10))
                    .foregroundColor(tertiaryTextColor)
            }
        }
    }

    private func formatTime(_ time: Double) -> String {
        // Guard against NaN and invalid values
        let safeTime = time.isNaN || time.isInfinite || time < 0 ? 0 : time
        let minutes = Int(safeTime) / 60
        let seconds = Int(safeTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Waiting Card Content

    @ViewBuilder
    private func waitingCardContent(member: User) -> some View {
        // Centered content only - buttons are now in the overlay
        VStack(spacing: 24) {
            Spacer()
            Spacer()
                .frame(height: 60) // Balance bottom spacing for visual centering

            // Profile photo with fire streak badge - tappable to navigate to profile
            Button(action: onProfileTapped) {
                Group {
                    if let avatarUrl = member.profilePhotoUrl, let url = URL(string: avatarUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle().fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Text(String(member.displayName.prefix(1)).uppercased())
                                    .font(.lora(size: 40, weight: .medium))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .overlay(alignment: .bottom) {
                    // Fire streak badge with number (centered at bottom)
                    if member.dailySongStreak > 0 {
                        HStack(spacing: 2) {
                            Text("🔥")
                                .font(.system(size: 14))
                            Text("\(member.dailySongStreak)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                        )
                        .offset(y: 12)
                    }
                }
            }
            .buttonStyle(.plain)

            // Text
            VStack(spacing: 8) {
                Text("@\(member.username ?? member.displayName)")
                    .font(.lora(size: 20, weight: .semiBold))
                    .foregroundColor(textColor)

                Text("hasn't picked yet")
                    .font(.lora(size: 16))
                    .foregroundColor(subtextColor)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Empty Card Content

    @ViewBuilder
    private func emptyCardContent() -> some View {
        VStack(spacing: 32) {
            Spacer()
            Spacer()
                .frame(height: 60) // Balance bottom spacing for visual centering

            Button(action: onAddMemberTapped) {
                VStack(spacing: 24) {
                    // Dashed circle with plus
                    Circle()
                        .stroke(subtextColor.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [12, 8]))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(subtextColor)
                        )

                    VStack(spacing: 8) {
                        Text("add to your phlock")
                            .font(.lora(size: 22, weight: .medium))
                            .foregroundColor(textColor)

                        Text("invite a friend to share music")
                            .font(.lora(size: 15))
                            .foregroundColor(subtextColor)
                    }
                }
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Helpers

    private func togglePlayPause() {
        withAnimation(.easeOut(duration: 0.15)) {
            showPlayPauseIndicator = true
        }

        guard let song = slot.song else { return }

        // Check if this track is already loaded (same track ID)
        let isThisTrackLoaded = playbackService.currentTrack?.id == song.trackId

        if isThisTrackLoaded {
            // Same track is already loaded - just toggle pause/resume
            // This preserves the current playback position
            if playbackService.isPlaying {
                playbackService.pause()
            } else {
                playbackService.resume()
            }
        } else {
            // Different track - load it (onPlayTapped will include saved position)
            onPlayTapped()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                showPlayPauseIndicator = false
            }
        }
    }

    private func openInStreamingApp(song: Share) {
        print("🔗 openInStreamingApp called:")
        print("   song.trackName: \(song.trackName)")
        print("   song.trackId: \(song.trackId)")

        // Convert Share to MusicItem for DeepLinkService
        let musicItem = MusicItem(
            id: song.trackId,
            name: song.trackName,
            artistName: song.artistName,
            previewUrl: song.previewUrl,
            albumArtUrl: song.albumArtUrl,
            isrc: nil,
            playedAt: nil,
            spotifyId: song.trackId,
            appleMusicId: nil,
            popularity: nil,
            followerCount: nil
        )

        // Use DeepLinkService which handles both Spotify and Apple Music
        guard let platformType = authState.currentUser?.resolvedPlatformType else {
            print("   ⚠️ No platform type, defaulting to Spotify")
            // Fallback to Spotify if no platform set
            if let webUrl = URL(string: "https://open.spotify.com/track/\(song.trackId)") {
                UIApplication.shared.open(webUrl)
            }
            return
        }

        print("   Platform: \(platformType)")
        DeepLinkService.shared.openInNativeApp(track: musicItem, platform: platformType)
    }
}

// MARK: - Array Safe Subscript

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Legacy Support (PhlockImmersiveLayout wrapper)

struct PhlockImmersiveLayout: View {
    let items: [PhlockView.PhlockItem]
    let dailySongs: [Share]
    let myDailySong: Share?
    let savedTrackIds: Set<String>
    let nudgedUserIds: Set<UUID>
    let currentlyPlayingId: String?
    let isPlaying: Bool

    let onPlayTapped: (Share, Bool, Double?) -> Void  // (song, autoPlay, seekToPosition)
    let onSwapTapped: (User) -> Void
    let onAddToLibrary: (Share) -> Void
    let onRemoveFromLibrary: (Share) -> Void
    let onProfileTapped: (User) -> Void
    let onNudgeTapped: (User) -> Void
    let onAddMemberTapped: () -> Void
    let onSelectDailySong: () -> Void
    let onPlayMyPick: () -> Void
    let onOpenFullPlayer: () -> Void
    let onEditSwapTapped: (User) -> Void
    let onEditRemoveTapped: (User) -> Void
    let onEditAddTapped: () -> Void
    let onMenuTapped: () -> Void
    let onShareTapped: () -> Void

    var body: some View {
        // Check if user has picked their daily song
        if myDailySong == nil {
            PrePickGateView(
                onSelectSong: onSelectDailySong,
                firstSongArtworkUrl: dailySongs.first?.albumArtUrl
            )
        } else {
            PhlockCarouselView(
                items: items,
                dailySongs: dailySongs,
                myDailySong: myDailySong,
                savedTrackIds: savedTrackIds,
                nudgedUserIds: nudgedUserIds,
                onPlayTapped: onPlayTapped,
                onSwapTapped: onSwapTapped,
                onAddToLibrary: onAddToLibrary,
                onRemoveFromLibrary: onRemoveFromLibrary,
                onProfileTapped: onProfileTapped,
                onNudgeTapped: onNudgeTapped,
                onAddMemberTapped: onAddMemberTapped,
                onChangeDailySong: onSelectDailySong,
                onOpenFullPlayer: onOpenFullPlayer,
                onEditSwapTapped: onEditSwapTapped,
                onEditRemoveTapped: onEditRemoveTapped,
                onEditAddTapped: onEditAddTapped,
                onMenuTapped: onMenuTapped,
                onShareTapped: onShareTapped
            )
        }
    }
}

// MARK: - Friend Picker Panel

struct FriendPickerPanel: View {
    let availableFriends: [User]
    let isSwapMode: Bool
    let memberBeingReplaced: User?
    let onFriendSelected: (User) -> Void
    let onDismiss: () -> Void

    @State private var searchText = ""
    @Environment(\.colorScheme) var colorScheme

    private var filteredFriends: [User] {
        if searchText.isEmpty { return availableFriends }
        return availableFriends.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            ($0.username?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Drag handle
            Capsule()
                .fill(Color.white.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 12)

            // Header (shows who you're replacing when swapping)
            if isSwapMode, let member = memberBeingReplaced {
                Text("replace @\(member.username ?? member.displayName)")
                    .font(.lora(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            } else {
                Text("add to your phlock")
                    .font(.lora(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.6))
                TextField("search", text: $searchText)
                    .font(.lora(size: 16))
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .padding(.horizontal, 16)

            // Horizontal scrollable friends
            if filteredFriends.isEmpty {
                VStack(spacing: 8) {
                    if availableFriends.isEmpty {
                        Text("no friends available")
                            .font(.lora(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Text("follow more people to add them")
                            .font(.lora(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    } else {
                        Text("no matches found")
                            .font(.lora(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .frame(height: 100)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(filteredFriends) { friend in
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                                onFriendSelected(friend)
                            }) {
                                VStack(spacing: 8) {
                                    // Profile photo
                                    if let urlString = friend.profilePhotoUrl,
                                       let url = URL(string: urlString) {
                                        AsyncImage(url: url) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Circle()
                                                .fill(Color.gray.opacity(0.3))
                                                .overlay(
                                                    Text(String(friend.displayName.prefix(1)).uppercased())
                                                        .font(.lora(size: 24, weight: .medium))
                                                        .foregroundColor(.white)
                                                )
                                        }
                                        .frame(width: 64, height: 64)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 2))
                                    } else {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 64, height: 64)
                                            .overlay(
                                                Text(String(friend.displayName.prefix(1)).uppercased())
                                                    .font(.lora(size: 24, weight: .medium))
                                                    .foregroundColor(.white)
                                            )
                                            .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 2))
                                    }

                                    // Name
                                    Text(friend.displayName)
                                        .font(.lora(size: 12))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .frame(width: 70)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 100)
            }

            Spacer()
        }
        .frame(height: UIScreen.main.bounds.height * 0.32)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 20, y: 0)
        )
        .padding(.horizontal, 16)
    }
}
