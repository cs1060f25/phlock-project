import Foundation
import AVFAudio
import ShazamKit
import Combine
import MusicKit

/// Handles the microphone capture + ShazamKit session lifecycle and exposes the latest match to SwiftUI.
final class SongRecognitionManager: NSObject, ObservableObject {
    enum RecognitionState: Equatable {
        case idle
        case requestingPermission
        case listening
        case processing
        case matched
        case failed
    }

    @Published private(set) var state: RecognitionState = .idle
    @Published private(set) var matchedTrack: MusicItem?
    @Published private(set) var lastErrorMessage: String?

    private let session = SHSession()
    private let audioEngine = AVAudioEngine()
    private var captureTimer: Timer?
    private let maxCaptureDuration: TimeInterval = 8

    override init() {
        super.init()
        session.delegate = self
    }

    private enum InternalRecordPermission {
        case granted
        case denied
        case undetermined
    }

    func startListening() {
        guard state != .listening else {
            stopListening()
            return
        }

        matchedTrack = nil
        lastErrorMessage = nil

        // Check permission status
        let permissionStatus: InternalRecordPermission
        if #available(iOS 17.0, *) {
            let status = AVAudioApplication.shared.recordPermission
            switch status {
            case .granted: permissionStatus = .granted
            case .denied: permissionStatus = .denied
            case .undetermined: permissionStatus = .undetermined
            @unknown default: permissionStatus = .undetermined
            }
        } else {
            let status = AVAudioSession.sharedInstance().recordPermission
            switch status {
            case .granted: permissionStatus = .granted
            case .denied: permissionStatus = .denied
            case .undetermined: permissionStatus = .undetermined
            @unknown default: permissionStatus = .undetermined
            }
        }
        handlePermissionStatus(permissionStatus)
    }

    private func handlePermissionStatus(_ status: InternalRecordPermission) {
        switch status {
        case .granted:
            beginCapture()
        case .denied:
            state = .failed
            lastErrorMessage = "Microphone access is required to identify songs. Enable it in Settings."
        case .undetermined:
            state = .requestingPermission
            requestMicrophonePermission { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    guard granted else {
                        self.state = .failed
                        self.lastErrorMessage = "Microphone access is required to identify songs."
                        return
                    }
                    self.beginCapture()
                }
            }
        }
    }

    func stopListening() {
        tearDownAudioEngine()
        if state == .listening {
            state = .processing
        }
    }

    func cancelAndReset() {
        tearDownAudioEngine()
        captureTimer?.invalidate()
        captureTimer = nil
        matchedTrack = nil
        lastErrorMessage = nil
        state = .idle
    }

    // MARK: - Private helpers

    private func beginCapture() {
        do {
            try configureAudioSession()

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.session.matchStreamingBuffer(buffer, at: nil)
            }

            audioEngine.prepare()
            try audioEngine.start()
            state = .listening

            captureTimer?.invalidate()
            captureTimer = Timer.scheduledTimer(withTimeInterval: maxCaptureDuration, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.stopListening()
                    if self.state != .matched {
                        self.handleFailure(nil)
                    }
                }
            }
        } catch {
            state = .failed
            lastErrorMessage = "Unable to start listening: \(error.localizedDescription)"
            tearDownAudioEngine()
        }
    }

    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .mixWithOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func tearDownAudioEngine() {
        captureTimer?.invalidate()
        captureTimer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func handle(match: SHMatch) {
        guard let item = match.mediaItems.first else {
            state = .failed
            lastErrorMessage = "We couldn't find that song. Try again in a quieter space."
            return
        }

        let track = MusicItem(
            id: item.appleMusicID ?? item.shazamID ?? UUID().uuidString,
            name: item.title ?? "Unknown Track",
            artistName: item.artist,
            previewUrl: item.appleMusicURL?.absoluteString ?? item.webURL?.absoluteString,
            albumArtUrl: item.artworkURL?.absoluteString,
            isrc: item.isrc,
            playedAt: nil,
            spotifyId: nil,
            appleMusicId: item.appleMusicID,
            popularity: nil,
            followerCount: nil
        )

        Task {
            var enrichedTrack = track
            if !Self.isValidPreviewURL(enrichedTrack.previewUrl),
               let artist = enrichedTrack.artistName,
               let appleTrack = (try? await AppleMusicService.shared.searchTrack(name: enrichedTrack.name, artist: artist, isrc: enrichedTrack.isrc)) ?? nil {
                enrichedTrack.previewUrl = appleTrack.previewURL ?? enrichedTrack.previewUrl
                if enrichedTrack.albumArtUrl == nil {
                    enrichedTrack.albumArtUrl = appleTrack.artworkURL
                }
                enrichedTrack.appleMusicId = appleTrack.id
            }

            let finalTrack = enrichedTrack
            await MainActor.run {
                self.matchedTrack = finalTrack
                self.state = .matched
                self.lastErrorMessage = nil
            }
        }
    }

    private func handleFailure(_ error: Error?) {
        state = .failed
        if let error {
            lastErrorMessage = error.localizedDescription
        } else {
            lastErrorMessage = "Couldn't identify that track. Try again."
        }
    }
    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                completion(granted)
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                completion(granted)
            }
        }
    }

    static func isValidPreviewURL(_ urlString: String?) -> Bool {
        guard let urlString = urlString?.lowercased() else { return false }
        return urlString.contains(".m4a") || urlString.contains(".mp3") || urlString.contains(".aac")
    }
}

extension SongRecognitionManager: SHSessionDelegate {
    func session(_ session: SHSession, didFind match: SHMatch) {
        DispatchQueue.main.async {
            self.stopListening()
            self.handle(match: match)
        }
    }

    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        DispatchQueue.main.async {
            self.stopListening()
            self.handleFailure(error)
        }
    }
}
