import SwiftUI

/// A thin progress bar designed to sit at the top edge of the tab bar
/// Similar to TikTok/Instagram Reels progress indicator
struct TabBarProgressView: View {
    let progress: Double  // 0.0 to 1.0
    let isVisible: Bool

    @Environment(\.colorScheme) private var colorScheme

    private let height: CGFloat = 3

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: height)

                // Progress fill
                Rectangle()
                    .fill(Color.white)
                    .frame(width: geometry.size.width * CGFloat(min(max(progress, 0), 1)), height: height)
                    .animation(.linear(duration: 0.1), value: progress)
            }
        }
        .frame(height: height)
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: isVisible)
    }
}

/// A wrapper that positions the progress bar at the top of the tab bar area
struct TabBarProgressOverlay: View {
    @ObservedObject var playbackService: PlaybackService
    let isOnPhlockTab: Bool

    private var progress: Double {
        guard playbackService.duration > 0 else { return 0 }
        return playbackService.currentTime / playbackService.duration
    }

    private var shouldShow: Bool {
        isOnPhlockTab && playbackService.isPlaying && playbackService.currentTrack != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            TabBarProgressView(
                progress: progress,
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
                TabBarProgressView(progress: 0.4, isVisible: true)

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
