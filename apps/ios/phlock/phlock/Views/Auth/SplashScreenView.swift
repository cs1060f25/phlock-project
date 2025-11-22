import SwiftUI
// import Lottie  // Commented out - using ColorfulPhlockLogoView instead

struct SplashScreenView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authState: AuthenticationState
    @State private var hasAppeared = false
    @State private var fadeOut = false // For fade transition when logged in
    @State private var moveToWelcomePosition = false // For moving logo to top

    var onComplete: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                // Adaptive background
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top spacer - expands when transitioning to welcome
                    if moveToWelcomePosition {
                        Spacer()
                            .frame(height: 120)
                    } else {
                        Spacer()
                    }

                    // Animated Phlock logo (sequential dot animation)
                    ColorfulPhlockLogoView(
                        size: 240,
                        sequentialAnimation: true,
                        onAnimationComplete: {
                            print("🎨 Logo animation complete")

                            // Check if user is authenticated
                            if authState.isAuthenticated {
                                // Logged in: fade out to MainView (no rotation)
                                print("🎨 User authenticated - fading to MainView")
                                withAnimation(.easeOut(duration: 0.5)) {
                                    fadeOut = true
                                }

                                // Notify parent to transition to MainView
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    onComplete?()
                                }
                            } else {
                                // Not logged in: move logo to welcome position (no rotation yet)
                                print("🎨 User not authenticated - moving logo to WelcomeView position")

                                // Animate logo to top position
                                withAnimation(.easeInOut(duration: 0.8)) {
                                    moveToWelcomePosition = true
                                }

                                // Notify parent to show WelcomeView after animation
                                // WelcomeView will start rotation when it appears
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    onComplete?()
                                }
                            }
                        }
                    )
                    .id("animated-logo")

                    // Bottom spacer - shrinks when transitioning to welcome
                    Spacer()
                }
            }
            .opacity(fadeOut ? 0 : 1)
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                print("🎬 SplashScreenView appeared - starting fast 1.5s animation")
            }
        }
        .fullScreenSwipeBack()
    }
}

// MARK: - OLD Lottie Animation (Commented Out)
/*
struct LottieAnimationView: UIViewRepresentable {
    let colorScheme: ColorScheme
    let onComplete: () -> Void

    func makeUIView(context: Context) -> Lottie.LottieAnimationView {
        let animationView = Lottie.LottieAnimationView()

        // Try to load animation from bundle by reading JSON data
        if let path = Bundle.main.path(forResource: "phlock_splash_animation", ofType: "json") {
            print("✅ Found animation file at: \(path)")

            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                let animation = try JSONDecoder().decode(LottieAnimation.self, from: data)

                print("✅ Successfully loaded Lottie animation")
                animationView.animation = animation
                animationView.contentMode = .scaleAspectFit
                animationView.loopMode = .playOnce
                animationView.animationSpeed = 1.0
                animationView.backgroundBehavior = .pauseAndRestore

                // Apply color based on color scheme
                applyColors(to: animationView, colorScheme: colorScheme)

                // Play animation with completion callback
                animationView.play { finished in
                    print("🎬 Animation finished: \(finished)")
                    if finished {
                        DispatchQueue.main.async {
                            self.onComplete()
                        }
                    }
                }
            } catch {
                print("❌ Failed to load animation: \(error)")
                // Animation failed to load, skip to completion
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.onComplete()
                }
            }
        } else {
            print("❌ Animation file not found in bundle")
            // File not found, skip to completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.onComplete()
            }
        }

        return animationView
    }

    func updateUIView(_ uiView: Lottie.LottieAnimationView, context: Context) {
        // Update colors if color scheme changes
        applyColors(to: uiView, colorScheme: colorScheme)
    }

    private func applyColors(to animationView: Lottie.LottieAnimationView, colorScheme: ColorScheme) {
        // Determine color based on scheme
        // Dark mode: white circles (1, 1, 1)
        // Light mode: black circles (0, 0, 0)
        let color: LottieColor = colorScheme == .dark ?
            LottieColor(r: 1, g: 1, b: 1, a: 1) :
            LottieColor(r: 0, g: 0, b: 0, a: 1)

        let colorProvider = ColorValueProvider(color)

        // Try multiple keypath patterns to cover different Lottie animation structures
        let keypaths = [
            // Standard fill keypaths
            AnimationKeypath(keys: ["**", "Fill", "**", "Color"]),
            AnimationKeypath(keys: ["**", "Fill 1", "Color"]),
            AnimationKeypath(keys: ["**", "**.Fill 1", "Color"]),
            AnimationKeypath(keys: ["**", "Shape", "**", "Color"]),

            // Stroke keypaths in case circles use strokes
            AnimationKeypath(keys: ["**", "Stroke", "**", "Color"]),
            AnimationKeypath(keys: ["**", "Stroke 1", "Color"]),
            AnimationKeypath(keys: ["**", "**.Stroke 1", "Color"]),

            // More generic paths
            AnimationKeypath(keys: ["**", "Color"]),
        ]

        // Apply color provider to all possible keypaths
        for keypath in keypaths {
            animationView.setValueProvider(colorProvider, keypath: keypath)
        }

        print("✅ Applied \(colorScheme == .dark ? "white" : "black") colors to animation")
    }

    typealias UIViewType = Lottie.LottieAnimationView
}
*/

#Preview {
    SplashScreenView()
}
