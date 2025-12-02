import SwiftUI

/// An animated playing indicator that shows three bars like Spotify/Apple Music
struct AnimatedPlayingIndicator: View {
    let isPlaying: Bool
    let size: CGFloat

    @State private var animationPhase: [Double] = [0, 0, 0]

    private let barCount = 3
    private let barSpacing: CGFloat = 2

    private var safeSize: CGFloat {
        size > 0 ? size : 16 // Default fallback size
    }

    var body: some View {
        let barWidth = max((safeSize - CGFloat(barCount - 1) * barSpacing) / CGFloat(barCount), 1)

        HStack(alignment: .bottom, spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: safeSize * 0.1)
                    .fill(Color.primary)
                    .frame(width: barWidth,
                           height: calculateBarHeight(for: index))
                    .animation(
                        isPlaying
                            ? Animation
                                .easeInOut(duration: Double.random(in: 0.4...0.7))
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.1)
                            : .default,
                        value: animationPhase[index]
                    )
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            if isPlaying {
                startAnimation()
            }
        }
        .onChange(of: isPlaying) { newValue in
            if newValue {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
    }

    private func calculateBarHeight(for index: Int) -> CGFloat {
        if !isPlaying {
            return safeSize * 0.3  // Static short bars when not playing
        }

        let baseHeight = safeSize * 0.3
        let maxHeight = safeSize * 0.9
        let amplitude = maxHeight - baseHeight

        return baseHeight + amplitude * CGFloat(animationPhase[index])
    }

    private func startAnimation() {
        withAnimation {
            for i in 0..<barCount {
                animationPhase[i] = Double.random(in: 0.6...1.0)
            }
        }
    }

    private func stopAnimation() {
        withAnimation {
            animationPhase = [0, 0, 0]
        }
    }
}

/// Alternative: Simple waveform indicator using SF Symbols
struct WaveformPlayingIndicator: View {
    let isPlaying: Bool
    let size: CGFloat

    @State private var animationScale: CGFloat = 1.0

    var body: some View {
        Image(systemName: "waveform")
            .font(.system(size: size * 0.6))
            .foregroundColor(isPlaying ? .primary : .secondary)
            .scaleEffect(animationScale)
            .animation(
                isPlaying
                    ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                    : .default,
                value: animationScale
            )
            .onAppear {
                if isPlaying {
                    animationScale = 1.1
                }
            }
            .onChange(of: isPlaying) { newValue in
                animationScale = newValue ? 1.1 : 1.0
            }
    }
}

/// Dot-based playing indicator
struct PulsingDotsIndicator: View {
    let isPlaying: Bool
    let size: CGFloat

    @State private var dotScales: [CGFloat] = [1, 1, 1]

    var body: some View {
        HStack(spacing: size * 0.15) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.primary)
                    .frame(width: size * 0.2, height: size * 0.2)
                    .scaleEffect(dotScales[index])
                    .animation(
                        isPlaying
                            ? Animation.easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2)
                            : .default,
                        value: dotScales[index]
                    )
            }
        }
        .onAppear {
            if isPlaying {
                startAnimation()
            }
        }
        .onChange(of: isPlaying) { newValue in
            if newValue {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
    }

    private func startAnimation() {
        for i in 0..<3 {
            withAnimation {
                dotScales[i] = 1.4
            }
        }
    }

    private func stopAnimation() {
        withAnimation {
            dotScales = [1, 1, 1]
        }
    }
}