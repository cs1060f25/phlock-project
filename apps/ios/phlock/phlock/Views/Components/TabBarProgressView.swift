import SwiftUI

/// A thin progress bar designed to sit at the top edge of the tab bar
/// Similar to TikTok/Instagram Reels progress indicator
/// Uses TimelineView for true 60fps smooth animation
struct TabBarProgressView: View {
    let currentTime: Double
    let duration: Double
    let isPlaying: Bool
    let isVisible: Bool

    // Track the reference point for smooth interpolation
    @State private var referenceTime: Double = 0
    @State private var referenceDate: Date = Date()

    private let height: CGFloat = 3

    var body: some View {
        TimelineView(.animation(paused: !isPlaying)) { timeline in
            GeometryReader { geometry in
                let progress = calculateProgress(at: timeline.date)

                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: height)

                    // Progress fill
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: geometry.size.width * progress, height: height)
                }
            }
        }
        .frame(height: height)
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: isVisible)
        .onChange(of: currentTime) { newTime in
            // Only update reference if time has jumped significantly (seek)
            // or if we've drifted too far (sync).
            // Threshold of 0.5s allows for minor drift/latency without visual jumps,
            // but catches seeks and track changes.
            let elapsed = Date().timeIntervalSince(referenceDate)
            let estimatedTime = referenceTime + elapsed
            let diff = abs(newTime - estimatedTime)
            
            if diff > 0.5 || !isPlaying {
                referenceTime = newTime
                referenceDate = Date()
            }
        }
        .onChange(of: isPlaying) { _ in
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
            let elapsed = date.timeIntervalSince(referenceDate)
            interpolatedTime = referenceTime + elapsed
        } else {
            interpolatedTime = currentTime
        }

        let clampedTime = max(0, min(interpolatedTime, duration))
        return CGFloat(clampedTime / duration)
    }
}

/// A wrapper that positions the progress bar at the top of the tab bar area
struct TabBarProgressOverlay: View {
    @ObservedObject var playbackService: PlaybackService
    let isOnPhlockTab: Bool

    private var shouldShow: Bool {
        isOnPhlockTab && playbackService.isPlaying && playbackService.currentTrack != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            TabBarProgressView(
                currentTime: playbackService.currentTime,
                duration: playbackService.duration,
                isPlaying: playbackService.isPlaying,
                isVisible: shouldShow
            )
            // Position just above the tab bar
            // Tab bar height is typically 49pt + safe area
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()

            // Simulated tab bar area
            VStack(spacing: 0) {
                TabBarProgressView(
                    currentTime: 12,
                    duration: 30,
                    isPlaying: true,
                    isVisible: true
                )

                HStack {
                    ForEach(0..<4) { _ in
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 30, height: 30)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.2))
            }
        }
    }
}
