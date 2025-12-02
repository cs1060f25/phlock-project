import SwiftUI

struct MarqueeText: View {
    let text: String
    let font: Font
    var leftFade: CGFloat = 16
    var rightFade: CGFloat = 16
    var startDelay: Double = 2.0
    var alignment: Alignment = .leading

    @State private var animate = false
    @State private var textSize: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    // Unique ID to force view recreation and cancel ongoing animations
    @State private var animationId = UUID()

    // Computed property for current scroll progress (0 = start, 1 = end)
    private var scrollProgress: CGFloat {
        guard textSize > containerWidth, textSize > 0 else { return 0 }
        let maxOffset = textSize - containerWidth
        guard maxOffset > 0 else { return 0 }
        // When animate is true, we're at the end; when false, we're at the start
        return animate ? 1 : 0
    }

    var body: some View {
        GeometryReader { geometry in
            let containerWidth = geometry.size.width

            ZStack(alignment: alignment) {
                // 1. Hidden Text for Measurement
                Text(text)
                    .font(font)
                    .fixedSize() // Forces it to be its ideal size
                    .lineLimit(1)
                    .opacity(0)
                    .background(GeometryReader { textGeo in
                        Color.clear
                            .onAppear {
                                textSize = textGeo.size.width
                                self.containerWidth = containerWidth
                            }
                            .onChange(of: text) { _ in
                                textSize = textGeo.size.width
                                self.containerWidth = containerWidth
                            }
                    })

                // 2. Visible Content
                if textSize > containerWidth {
                    // Scrolling Text - use ID to force recreation and reset animation
                    Text(text)
                        .font(font)
                        .fixedSize()
                        .offset(x: animate ? -textSize + containerWidth : 0)
                        .id(animationId) // Forces view recreation when ID changes
                        .onAppear {
                            startAnimation()
                        }
                        .onChange(of: text) { _ in
                            resetAndRestartAnimation()
                        }
                        .onChange(of: textSize) { _ in
                            resetAndRestartAnimation()
                        }
                        // Dynamic gradient mask based on scroll position
                        .mask(
                            HStack(spacing: 0) {
                                // Left fade - visible when scrolled (animate = true)
                                LinearGradient(
                                    colors: [.clear, .white],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: animate ? leftFade : 0)

                                Rectangle()

                                // Right fade - visible when at start (animate = false)
                                LinearGradient(
                                    colors: [.white, .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: animate ? 0 : rightFade)
                            }
                        )
                } else {
                    // Static Text
                    Text(text)
                        .font(font)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: alignment)
                }
            }
        }
        .frame(height: 40)
        .onChange(of: text) { _ in
            // Reset animation state immediately when text changes
            // This is the key fix - cancel ongoing animation by changing ID
            resetAndRestartAnimation()
        }
    }

    private func resetAndRestartAnimation() {
        // Cancel any ongoing animation by resetting state
        animate = false
        // Generate new ID to force SwiftUI to recreate the animated view
        // This properly cancels the repeatForever animation
        animationId = UUID()

        // Start fresh animation after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            startAnimation()
        }
    }

    private func startAnimation() {
        guard textSize > 0 else { return }
        // Ensure we start from position 0
        animate = false

        // Calculate duration based on text width for consistent scroll speed
        // Using 75.0 pixels per second
        let duration = Double(textSize) / 75.0

        // Small delay before starting animation to ensure view is stable
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(Animation.linear(duration: duration).delay(startDelay).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}
