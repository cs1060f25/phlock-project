import SwiftUI

/// A progress bar that uses TimelineView for true 60fps smooth animation.
/// TimelineView redraws every frame when playing, giving perfectly smooth motion.
struct ContinuousProgressBar: View {
    let currentTime: Double
    let duration: Double
    let isPlaying: Bool
    let height: CGFloat
    let trackColor: Color
    let fillColor: Color

    // Track the reference point for smooth interpolation
    @State private var referenceTime: Double = 0
    @State private var referenceDate: Date = Date()

    init(
        currentTime: Double,
        duration: Double,
        isPlaying: Bool,
        height: CGFloat = 3,
        trackColor: Color = .white.opacity(0.2),
        fillColor: Color = .white
    ) {
        self.currentTime = currentTime
        self.duration = duration
        self.isPlaying = isPlaying
        self.height = height
        self.trackColor = trackColor
        self.fillColor = fillColor
    }

    var body: some View {
        TimelineView(.animation(paused: !isPlaying)) { timeline in
            GeometryReader { geometry in
                let progress = calculateProgress(at: timeline.date)

                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(trackColor)
                        .frame(height: height)

                    // Progress fill
                    Rectangle()
                        .fill(fillColor)
                        .frame(width: geometry.size.width * progress, height: height)
                }
            }
        }
        .frame(height: height)
        .onChange(of: currentTime) { newTime in
            // Only update reference if time has jumped significantly (seek)
            // or if we've drifted too far (sync).
            let elapsed = Date().timeIntervalSince(referenceDate)
            let estimatedTime = referenceTime + elapsed
            let diff = abs(newTime - estimatedTime)
            
            if diff > 0.5 || !isPlaying {
                referenceTime = newTime
                referenceDate = Date()
            }
        }
        .onChange(of: isPlaying) { playing in
            // Update reference when play state changes
            referenceTime = currentTime
            referenceDate = Date()
        }
        .onAppear {
            referenceTime = currentTime
            referenceDate = Date()
        }
    }

    private func calculateProgress(at date: Date) -> CGFloat {
        guard duration > 0, !duration.isNaN, !duration.isInfinite else { return 0 }

        let interpolatedTime: Double
        if isPlaying {
            // Calculate time based on elapsed real time since reference
            let elapsed = date.timeIntervalSince(referenceDate)
            interpolatedTime = referenceTime + elapsed
        } else {
            // When paused, just use the current time
            interpolatedTime = currentTime
        }

        // Clamp to valid range
        let clampedTime = max(0, min(interpolatedTime, duration))
        return CGFloat(clampedTime / duration)
    }
}

/// A wrapper for ContinuousProgressBar that observes PlaybackService
struct PlaybackProgressBar: View {
    @ObservedObject var playbackService: PlaybackService
    let height: CGFloat
    let trackColor: Color
    let fillColor: Color

    init(
        playbackService: PlaybackService,
        height: CGFloat = 3,
        trackColor: Color = .white.opacity(0.2),
        fillColor: Color = .white
    ) {
        self.playbackService = playbackService
        self.height = height
        self.trackColor = trackColor
        self.fillColor = fillColor
    }

    var body: some View {
        ContinuousProgressBar(
            currentTime: playbackService.currentTime,
            duration: playbackService.duration,
            isPlaying: playbackService.isPlaying,
            height: height,
            trackColor: trackColor,
            fillColor: fillColor
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        // Simulated playing state
        ContinuousProgressBar(
            currentTime: 10,
            duration: 30,
            isPlaying: true,
            height: 3,
            trackColor: .white.opacity(0.2),
            fillColor: .white
        )
        .padding()
        .background(Color.black)

        // Simulated paused state
        ContinuousProgressBar(
            currentTime: 15,
            duration: 30,
            isPlaying: false,
            height: 4,
            trackColor: .gray.opacity(0.3),
            fillColor: .blue
        )
        .padding()
        .background(Color.white)
    }
}
