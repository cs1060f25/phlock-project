import SwiftUI

struct ColorfulPhlockLogoView: View {
    let size: CGFloat
    var animate: Bool = false
    var sequentialAnimation: Bool = false
    var onAnimationComplete: (() -> Void)? = nil

    @State private var innerRotation: Double = 0
    @State private var outerRotation: Double = 0
    @State private var animationStarted = false

    // For sequential animation
    @State private var showCenter = false
    @State private var visibleInnerDots = 0
    @State private var visibleOuterDots = 0

    var body: some View {
        ZStack {
            let scale = size / 240.0

            // Center node (grey) - never rotates
            if !sequentialAnimation || showCenter {
                Circle()
                    .fill(Color(hex: "#777777"))
                    .frame(width: 24 * scale, height: 24 * scale)
                    .scaleEffect(showCenter ? 1.0 : 0.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showCenter)
            }

            // Inner ring (6 rainbow-colored dots) - rotates as a group
            ZStack {
                ForEach(Array(innerRingDots.enumerated()), id: \.offset) { index, dot in
                    if !sequentialAnimation || index < visibleInnerDots {
                        Circle()
                            .fill(Color(hex: dot.color))
                            .frame(width: 20 * scale, height: 20 * scale)
                            .offset(
                                x: (dot.position.x - 120) * scale,
                                y: (dot.position.y - 120) * scale
                            )
                            .scaleEffect(index < visibleInnerDots || !sequentialAnimation ? 1.0 : 0.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: visibleInnerDots)
                    }
                }
            }
            .rotationEffect(.degrees(innerRotation))

            // Outer ring (12 extended palette dots) - rotates as a group
            ZStack {
                ForEach(Array(outerRingDots.enumerated()), id: \.offset) { index, dot in
                    if !sequentialAnimation || index < visibleOuterDots {
                        Circle()
                            .fill(Color(hex: dot.color))
                            .frame(width: 16 * scale, height: 16 * scale)
                            .offset(
                                x: (dot.position.x - 120) * scale,
                                y: (dot.position.y - 120) * scale
                            )
                            .scaleEffect(index < visibleOuterDots || !sequentialAnimation ? 1.0 : 0.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: visibleOuterDots)
                    }
                }
            }
            .rotationEffect(.degrees(outerRotation))
        }
        .frame(width: size, height: size)
        .onAppear {
            if sequentialAnimation && !animationStarted {
                animationStarted = true
                print("🎨 ColorfulPhlockLogoView: Starting sequential animation")
                startSequentialAnimation()
            } else if animate && !animationStarted {
                animationStarted = true
                print("🎨 ColorfulPhlockLogoView: View appeared, starting continuous rotation")
                // Show all dots immediately for continuous rotation mode
                showCenter = true
                visibleInnerDots = innerRingDots.count
                visibleOuterDots = outerRingDots.count
                // Small delay to ensure view is fully rendered before animation starts
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    startRotationAnimation()
                }
            } else if !animationStarted {
                // Static mode - show all dots immediately
                animationStarted = true
                showCenter = true
                visibleInnerDots = innerRingDots.count
                visibleOuterDots = outerRingDots.count
            }
        }
        .onChange(of: animate) { _, newValue in
            // Start rotation when animate changes to true
            if newValue && innerRotation == 0 && outerRotation == 0 {
                print("🎨 ColorfulPhlockLogoView: animate parameter changed to true, starting rotation")
                startRotationAnimation(duration: 3.0)
            }
        }
    }

    private func startSequentialAnimation() {
        print("🎨 Starting sequential dot animation (fast mode - 1.5s total)")

        // Step 1: Show center dot - faster
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                showCenter = true
            }
            print("🎨 Center dot appeared")
        }

        // Step 2: Show inner ring dots one by one - faster
        let innerDotDelay = 0.05 // Faster between each inner dot
        for i in 0..<innerRingDots.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + Double(i) * innerDotDelay) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    visibleInnerDots = i + 1
                }
                print("🎨 Inner dot \(i + 1)/\(self.innerRingDots.count) appeared")
            }
        }

        // Step 3: Show outer ring dots one by one - faster
        let outerDotDelay = 0.04 // Faster between each outer dot
        let outerStartDelay = 0.25 + Double(innerRingDots.count) * innerDotDelay + 0.05
        for i in 0..<outerRingDots.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + outerStartDelay + Double(i) * outerDotDelay) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    visibleOuterDots = i + 1
                }
                print("🎨 Outer dot \(i + 1)/\(self.outerRingDots.count) appeared")
            }
        }

        // Step 4: Notify completion when all dots appear (don't start rotation yet)
        let allDotsVisibleDelay = outerStartDelay + Double(outerRingDots.count) * outerDotDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + allDotsVisibleDelay) {
            print("🎨 All dots visible at \(allDotsVisibleDelay)s, notifying completion")

            // Notify completion - parent view will decide what to do next
            // (fade to MainView if authenticated, or transition to WelcomeView if not)
            onAnimationComplete?()
        }
    }

    private func startRotationAnimation(duration: Double = 4.0) {
        print("🎨 Starting rotation animation with duration: \(duration)s")

        // Rotation animation
        // Inner ring rotates clockwise (positive), outer ring counter-clockwise (negative)
        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            innerRotation = 360
            outerRotation = -360
        }

        print("🎨 Rotation animation started")
    }

    // Inner ring: 6 dots at 60° intervals
    // Matches phlock_logo_v1_rotated.svg
    // Using direct positions from SVG (will be converted to polar in rendering)
    private let innerRingDots: [(position: CGPoint, color: String)] = [
        (CGPoint(x: 120, y: 60), "#FF453A"),   // Red - top
        (CGPoint(x: 172, y: 90), "#FFD60A"),   // Yellow
        (CGPoint(x: 172, y: 150), "#32D74B"),  // Green
        (CGPoint(x: 120, y: 180), "#64D2FF"),  // Cyan - bottom
        (CGPoint(x: 68, y: 150), "#BF5AF2"),   // Purple
        (CGPoint(x: 68, y: 90), "#FF9F0A"),    // Orange
    ]

    // Outer ring: 12 dots, offset by 15° to sit between inner ring dots
    // Matches phlock_logo_v1_rotated.svg exactly
    private let outerRingDots: [(position: CGPoint, color: String)] = [
        (CGPoint(x: 144.6, y: 28.2), "#FF375F"),   // Pink-Red
        (CGPoint(x: 187.2, y: 52.8), "#FF9500"),   // Orange
        (CGPoint(x: 211.8, y: 95.4), "#FFCC00"),   // Gold
        (CGPoint(x: 211.8, y: 144.6), "#30D158"),  // Bright Green
        (CGPoint(x: 187.2, y: 187.2), "#00C7BE"),  // Teal
        (CGPoint(x: 144.6, y: 211.8), "#5AC8FA"),  // Light Blue
        (CGPoint(x: 95.4, y: 211.8), "#0A84FF"),   // Blue
        (CGPoint(x: 52.8, y: 187.2), "#5E5CE6"),   // Indigo
        (CGPoint(x: 28.2, y: 144.6), "#AF52DE"),   // Purple
        (CGPoint(x: 28.2, y: 95.4), "#FF2D55"),    // Magenta
        (CGPoint(x: 52.8, y: 52.8), "#FF6482"),    // Pink
        (CGPoint(x: 95.4, y: 28.2), "#FF9F0A"),    // Orange-Yellow
    ]
}

// Extension to create Color from hex string
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    VStack(spacing: 40) {
        // Static colorful logo
        ColorfulPhlockLogoView(size: 200)

        // Animated colorful logo
        ColorfulPhlockLogoView(size: 200, animate: true)
    }
    .padding()
}
