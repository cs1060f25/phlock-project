import SwiftUI
import AVFoundation

struct SongRecognitionFab: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var manager = SongRecognitionManager()
    @State private var isSheetPresented = false

    var bottomInset: CGFloat
    var onTrackReady: (MusicItem) -> Void

    private var fabBackgroundColor: Color {
        colorScheme == .dark ? Color(.systemGray3) : Color.black
    }

    private var fabShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.25)
    }

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    isSheetPresented = true
                } label: {
                    Circle()
                        .fill(fabBackgroundColor)
                        .frame(width: 64, height: 64)
                        .shadow(color: fabShadowColor, radius: 10, x: 0, y: 8)
                        .overlay(
                            Image(systemName: "ear")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Identify song")
                .padding(.trailing, 20)
                .padding(.bottom, max(bottomInset, 0) + 60)
            }
        }
        .sheet(isPresented: $isSheetPresented, onDismiss: {
            manager.cancelAndReset()
        }) {
            if #available(iOS 16.0, *) {
                SongRecognitionSheet(manager: manager) { track in
                    onTrackReady(track)
                    isSheetPresented = false
                } onClose: {
                    isSheetPresented = false
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            } else {
                SongRecognitionSheet(manager: manager) { track in
                    onTrackReady(track)
                    isSheetPresented = false
                } onClose: {
                    isSheetPresented = false
                }
            }
        }
    }
}

private struct SongRecognitionSheet: View {
    @ObservedObject var manager: SongRecognitionManager
    var onSend: (MusicItem) -> Void
    var onClose: () -> Void
    @State private var previewPlayer: AVPlayer?
    @State private var previewTimeObserver: Any?
    @State private var isPlayingPreview = false
    @State private var previewProgress: Double = 0
    @State private var previewDuration: Double = 30
    @State private var previewEndObserver: NSObjectProtocol?

    private var hasPreviewLoaded: Bool {
        previewPlayer != nil
    }

    private var previewButtonLabel: String {
        if isPlayingPreview {
            return "Pause Preview"
        } else if hasPreviewLoaded {
            return "Resume Preview"
        } else {
            return "Preview"
        }
    }

    private var statusText: String {
        switch manager.state {
        case .idle:
            return "Start listening to identify the song you hear right now."
        case .requestingPermission:
            return "Requesting microphone permission..."
        case .listening:
            return "Listening... hold your phone near the music."
        case .processing:
            return "Finding a match..."
        case .matched:
            return "Send it to someone on Phlock."
        case .failed:
            return manager.lastErrorMessage ?? "Couldn't identify that track."
        }
    }

    private var shouldShowListenButton: Bool {
        switch manager.state {
        case .listening, .processing, .requestingPermission:
            return false
        default:
            return true
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ListeningIndicatorView(
                            state: manager.state,
                            allowsTapToListen: shouldShowListenButton,
                            onTap: shouldShowListenButton ? {
                                manager.startListening()
                            } : nil
                        )
                        .id("top")

                        Text(statusText)
                            .font(.system(.footnote))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .offset(y: manager.state == .matched ? -8 : 0)

                        if let track = manager.matchedTrack {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 12) {
                                    RemoteArtworkView(urlString: track.albumArtUrl)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(track.name)
                                            .font(.system(.headline))
                                        if let artist = track.artistName {
                                            Text(artist)
                                                .font(.system(.subheadline))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                }

                                if let preview = track.previewUrl,
                                   SongRecognitionManager.isValidPreviewURL(preview),
                                   let previewURL = URL(string: preview) {
                                    PreviewPlaybackButton(
                                        isPlaying: isPlayingPreview,
                                        progress: previewProgress,
                                        label: previewButtonLabel,
                                        action: {
                                            if isPlayingPreview {
                                                pausePreview()
                                            } else if hasPreviewLoaded {
                                                resumePreview()
                                            } else {
                                                startPreview(with: previewURL)
                                            }
                                        }
                                    )
                                }

                                Button {
                                    stopPreview()
                                    onSend(track)
                                    manager.cancelAndReset()
                                } label: {
                                    HStack {
                                        Image(systemName: "paperplane.fill")
                                        Text("Send in Phlock")
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.accentColor))
                                }
                        }
                        .padding(.vertical, 18)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .offset(y: -18)  // Changed from -13 to -18 (moved up 5 more pixels)
                        }

                    if manager.state == .failed {
                        VStack(alignment: .center, spacing: 8) {
                            Button(action: {
                                manager.startListening()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Try again")
                                        .font(.system(.headline))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(.systemGray))
                                )
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .scrollDisabled(manager.state == .matched && manager.matchedTrack != nil)
                .onAppear {
                    withAnimation(.spring()) {
                        proxy.scrollTo("top", anchor: .top)
                    }
                }
                .onChange(of: manager.state) { _ in
                    withAnimation(.easeInOut) {
                        proxy.scrollTo("top", anchor: .top)
                    }
                }
            }
            .background(Color(.systemBackground))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        stopPreview()
                        manager.cancelAndReset()
                        onClose()
                    }
                }
            }
            .onDisappear {
                stopPreview(resetProgress: true)
            }
        }
    }

    private func startPreview(with url: URL) {
        stopPreview(resetProgress: true)

        previewDuration = 30
        previewProgress = 0
        isPlayingPreview = false

        activatePreviewAudioSession()

        let playerItem = AVPlayerItem(url: url)
        previewPlayer = AVPlayer(playerItem: playerItem)
        previewPlayer?.automaticallyWaitsToMinimizeStalling = false
        previewPlayer?.volume = 1
        previewPlayer?.play()
        isPlayingPreview = true

        previewEndObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { _ in
            stopPreview(resetProgress: true)
        }

        if #available(iOS 16.0, *) {
            Task {
                if let duration = try? await playerItem.asset.load(.duration) {
                    let seconds = CMTimeGetSeconds(duration)
                    if seconds.isFinite && seconds > 0 {
                        await MainActor.run {
                            previewDuration = min(30, seconds)
                        }
                    }
                }
            }
        } else {
            let seconds = CMTimeGetSeconds(playerItem.asset.duration)
            if seconds.isFinite && seconds > 0 {
                previewDuration = min(30, seconds)
            }
        }

        let interval = CMTime(seconds: 0.2, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        previewTimeObserver = previewPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            let seconds = CMTimeGetSeconds(time)
            if previewDuration > 0 {
                previewProgress = min(seconds / previewDuration, 1)
            }

            if previewProgress >= 0.999 {
                stopPreview(resetProgress: true)
            }
        }
    }

    private func pausePreview() {
        previewPlayer?.pause()
        isPlayingPreview = false
        deactivatePreviewAudioSession()
    }

    private func resumePreview() {
        guard let player = previewPlayer else { return }
        activatePreviewAudioSession()
        player.play()
        isPlayingPreview = true
    }

    private func stopPreview(resetProgress: Bool = false) {
        if let observer = previewTimeObserver {
            previewPlayer?.removeTimeObserver(observer)
            previewTimeObserver = nil
        }
        if let endObserver = previewEndObserver {
            NotificationCenter.default.removeObserver(endObserver)
            previewEndObserver = nil
        }
        previewPlayer?.pause()
        previewPlayer = nil
        isPlayingPreview = false
        deactivatePreviewAudioSession()

        if resetProgress {
            previewProgress = 0
        }
    }

    private func activatePreviewAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true, options: [])
    }

    private func deactivatePreviewAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

private struct ListeningIndicatorView: View {
    let state: SongRecognitionManager.RecognitionState
    var allowsTapToListen: Bool = false
    var onTap: (() -> Void)?
    @State private var animateOuterPulse = false
    @State private var animateInnerPulse = false
    @State private var ringRotation = 0.0

    var body: some View {
        VStack(spacing: 12) {
            Group {
                if allowsTapToListen, let onTap {
                    Button(action: onTap) {
                        indicatorCore
                            .padding(.top, state == .matched ? 10 : 0)
                    }
                    .buttonStyle(.plain)
                } else {
                    indicatorCore
                        .padding(.top, state == .matched ? 10 : 0)
                }
            }

            Text(label(for: state))
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(color(for: state))
                .padding(.top, state == .matched ? 4 : 0)
        }
        .frame(maxWidth: .infinity)
        .onAppear { updateAnimationState(for: state) }
        .onChange(of: state) { newValue in
            updateAnimationState(for: newValue)
        }
    }

    private var indicatorCore: some View {
        Group {
            if state == .failed || state == .matched {
                Circle()
                    .fill(color(for: state))
                    .frame(width: 100, height: 100)
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
                    .overlay(indicatorIcon)
            } else {
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.05), lineWidth: 12)
                        .frame(width: 200, height: 200)

                    if state == .listening {
                        Circle()
                            .stroke(Color.blue.opacity(0.25), lineWidth: 8)
                            .frame(width: 200, height: 200)
                            .scaleEffect(animateOuterPulse ? 1.08 : 0.88)
                            .opacity(animateOuterPulse ? 0.05 : 0.28)
                            .animation(
                                .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                                value: animateOuterPulse
                            )

                        Circle()
                            .stroke(Color.blue.opacity(0.12), lineWidth: 6)
                            .frame(width: 165, height: 165)
                            .scaleEffect(animateInnerPulse ? 1.04 : 0.9)
                            .opacity(animateInnerPulse ? 0.08 : 0.3)
                            .animation(
                                .easeInOut(duration: 1.1).repeatForever(autoreverses: true).delay(0.2),
                                value: animateInnerPulse
                            )

                        Circle()
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [.clear, Color.blue.opacity(0.45), .clear]),
                                    center: .center
                                ),
                                lineWidth: 4
                            )
                            .frame(width: 135, height: 135)
                            .rotationEffect(.degrees(ringRotation))
                            .animation(.linear(duration: 4).repeatForever(autoreverses: false), value: ringRotation)
                    }

                    Circle()
                        .fill(Color.white)
                        .frame(width: 95, height: 95)
                        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.15), lineWidth: 6)
                        )
                        .overlay(
                            Circle()
                                .fill(color(for: state))
                                .frame(width: 64, height: 64)
                                .overlay(indicatorIcon)
                        )
                }
            }
        }
    }

    private func color(for state: SongRecognitionManager.RecognitionState) -> Color {
        switch state {
        case .listening:
            return .blue
        case .processing:
            return .orange
        case .matched:
            return .green
        case .failed:
            return .red
        default:
            return .blue
        }
    }

    private func label(for state: SongRecognitionManager.RecognitionState) -> String {
        switch state {
        case .listening:
            return "Listening now..."
        case .processing:
            return "Identifying track..."
        case .matched:
            return "Match found!"
        case .failed:
            return "No match found"
        default:
            return "Tap to listen"
        }
    }

    private func icon(for state: SongRecognitionManager.RecognitionState) -> String {
        switch state {
        case .processing:
            return "wave.3.forward.circle.fill"
        case .matched:
            return "checkmark"
        case .failed:
            return "exclamationmark"
        default:
            return "ear"
        }
    }

    @ViewBuilder
    private var indicatorIcon: some View {
        if state == .processing {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
        } else {
            Image(systemName: icon(for: state))
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private func updateAnimationState(for state: SongRecognitionManager.RecognitionState) {
        let shouldAnimate = state == .listening
        animateOuterPulse = shouldAnimate
        animateInnerPulse = shouldAnimate
        ringRotation = shouldAnimate ? 360 : 0
    }
}

private struct PreviewPlaybackButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let isPlaying: Bool
    let progress: Double
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .frame(height: 44)

                // Progress bar - properly masked to button shape
                GeometryReader { geometry in
                    let clamped = max(0, min(progress, 1))

                    Rectangle()
                        .fill(Color(.label).opacity(colorScheme == .dark ? 0.4 : 0.25))
                        .frame(width: geometry.size.width * clamped, height: 44)
                        .animation(.easeInOut(duration: 0.25), value: clamped)
                }
                .frame(height: 44)
                .mask(RoundedRectangle(cornerRadius: 16))  // Using mask instead of clipShape for better clipping
                .allowsHitTesting(false)

                // Content overlay
                HStack(spacing: 8) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(label)
                        .font(.system(.subheadline, weight: .semibold))
                    Spacer()
                }
                .foregroundColor(progress > 0.55 || isPlaying ? .white : .primary)
                .padding(.horizontal, 16)
            }
            .frame(height: 44)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct RemoteArtworkView: View {
    var urlString: String?

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var placeholder: some View {
        ZStack {
            Color.gray.opacity(0.2)
            Image(systemName: "music.quarternote.3")
                .foregroundColor(.gray)
        }
    }
}
