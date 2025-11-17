import SwiftUI

/// Animated audio waveform loading indicator with pull-responsive animation
struct WaveformLoadingView: View {
    let barCount: Int
    let color: Color
    let progress: CGFloat // 0.0 to 1.0 - controls reveal during pull
    let isRefreshing: Bool // When true, plays wave animation

    init(barCount: Int = 5, color: Color = .blue, progress: CGFloat = 1.0, isRefreshing: Bool = false) {
        self.barCount = barCount
        self.color = color
        self.progress = progress
        self.isRefreshing = isRefreshing
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveformBar(
                    index: index,
                    barCount: barCount,
                    color: color,
                    revealAmount: barReveal(for: index),
                    isRefreshing: isRefreshing,
                    barPhase: barPhase(for: index)
                )
            }
        }
        .frame(height: 30)
        .opacity(isRefreshing ? 1 : Double(max(0.12, easedProgress)))
        .scaleEffect(y: 0.65 + 0.35 * easedProgress, anchor: .bottom)
        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.85), value: progress)
    }

    private var clampedProgress: CGFloat {
        max(0, min(1, progress))
    }

    private var easedProgress: CGFloat {
        let t = clampedProgress
        return t * t * (3 - 2 * t) // Smoothstep easing for softer reveal
    }

    private func barReveal(for index: Int) -> CGFloat {
        guard barCount > 0 else { return 0 }
        let total = easedProgress * CGFloat(barCount)
        let amount = total - CGFloat(index)
        return max(0, min(1, amount))
    }

    private func barPhase(for index: Int) -> Double {
        guard barCount > 1 else { return 0 }
        return Double(index) / Double(barCount - 1)
    }
}

struct WaveformBar: View {
    let index: Int
    let barCount: Int
    let color: Color
    let revealAmount: CGFloat
    let isRefreshing: Bool
    let barPhase: Double

    @State private var animationPhase: Bool = false
    @State private var isAnimating: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 4)
            .frame(height: barHeight)
            .opacity(isRefreshing ? 1 : Double(max(0.08, revealAmount)))
            .onAppear {
                startAnimationIfNeeded()
            }
            .onChange(of: isRefreshing) { _, newValue in
                if newValue {
                    startAnimationIfNeeded()
                } else {
                    stopAnimation()
                }
            }
    }

    // Bar height with continuous animation
    private var barHeight: CGFloat {
        let minHeight: CGFloat = 4
        let maxHeight: CGFloat = 32
        let heightRange = maxHeight - minHeight
        let interactiveHeight = minHeight + heightRange * pow(revealAmount, 0.85)

        guard isAnimating else {
            return interactiveHeight
        }

        let prominence = 1 - abs(0.5 - CGFloat(barPhase)) * 2 // center bars go tallest
        let waveStrength = 0.7 + 0.3 * prominence
        let troughHeight = minHeight + heightRange * 0.25
        let peakHeight = minHeight + heightRange * waveStrength
        return animationPhase ? peakHeight : troughHeight
    }

    private func startAnimationIfNeeded() {
        guard isRefreshing, !isAnimating else { return }
        isAnimating = true

        // Stagger the animation for each bar to create wave effect
        let delay = Double(index) * 0.1

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(
                Animation
                    .easeInOut(duration: 0.5)
                    .repeatForever(autoreverses: true)
            ) {
                animationPhase = true
            }
        }
    }

    private func stopAnimation() {
        isAnimating = false
        animationPhase = false
    }
}

#Preview {
    VStack(spacing: 30) {
        WaveformLoadingView()
        WaveformLoadingView(barCount: 7, color: .green)
        WaveformLoadingView(barCount: 4, color: .purple)
    }
    .padding()
}
