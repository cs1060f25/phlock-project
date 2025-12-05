import SwiftUI
// import Lottie  // Commented out - using ColorfulPhlockLogoView instead

struct SplashScreenView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authState: AuthenticationState
    @State private var hasAppeared = false
    @State private var fadeOut = false // For fade transition when logged in
    @State private var moveToWelcomePosition = false // For moving logo to top
    @State private var isRotating = false
    @State private var minimumDisplayTimePassed = false // Ensure logo displays for minimum time
    @State private var hasTransitioned = false // Prevent double transitions
    @State private var timeoutTask: Task<Void, Never>? // Track timeout task for cleanup

    var onComplete: (() -> Void)? = nil

    // MARK: - Transition Logic

    /// Safely trigger transition to next screen (prevents double-firing)
    private func triggerTransition() {
        guard !hasTransitioned else { return }
        hasTransitioned = true

        // Cancel timeout task since we're transitioning
        timeoutTask?.cancel()

        if authState.isAuthenticated {
            print("🎨 User authenticated - fading to MainView")
        } else {
            print("🎨 User not authenticated - fading to WelcomeView")
        }

        withAnimation(.easeOut(duration: 0.5)) {
            fadeOut = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onComplete?()
        }
    }

    /// Check if we're ready to transition (auth done AND minimum display time passed)
    private func checkReadyToTransition() {
        guard minimumDisplayTimePassed && !authState.isLoading && !hasTransitioned else { return }
        triggerTransition()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Adaptive background
                Color.white
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top spacer - expands when transitioning to welcome
                    if moveToWelcomePosition {
                        Spacer()
                            .frame(height: 120)
                    } else {
                        Spacer()
                    }

                    // Static Phlock logo
                    Image("PhlockLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 234, height: 234)
                        .rotationEffect(.degrees(isRotating ? 360 : 0))
                        .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: isRotating)
                        .id("animated-logo")
                        .onAppear {
                            isRotating = true

                            // Minimum display time for splash (1.75s)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.75) {
                                print("🎨 Minimum display time passed")
                                minimumDisplayTimePassed = true
                                checkReadyToTransition()
                            }
                        }
                    
                    // Brand Name & Tagline
                    VStack(spacing: 8) {
                        Text("phlock")
                            .font(.lora(size: 42, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text("heard together")
                            .font(.lora(size: 20, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)
                    .opacity(moveToWelcomePosition ? 0 : 1) // Fade out when moving to welcome view

                    // Bottom spacer - shrinks when transitioning to welcome
                    Spacer()
                }
            }
            .opacity(fadeOut ? 0 : 1)
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                print("🎬 SplashScreenView appeared - starting splash animation")

                // If auth is already complete when we appear, we just wait for minimum display time
                if !authState.isLoading {
                    print("🎬 Auth already complete on appear")
                }

                // Start timeout task - force transition after 5 seconds no matter what
                timeoutTask = Task {
                    do {
                        try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                        await MainActor.run {
                            if !hasTransitioned {
                                print("⚠️ Splash screen timeout - forcing transition")
                                triggerTransition()
                            }
                        }
                    } catch {
                        // Task was cancelled - this is expected when we transition normally
                    }
                }
            }
            .onChange(of: authState.isLoading) { isLoading in
                if !isLoading {
                    print("🎬 Auth loading finished")
                    checkReadyToTransition()
                }
            }
            .onDisappear {
                // Clean up timeout task when view disappears
                timeoutTask?.cancel()
            }
        }
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
