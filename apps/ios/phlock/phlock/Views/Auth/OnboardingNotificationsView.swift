import SwiftUI
import UserNotifications

struct OnboardingNotificationsView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme

    @State private var isLoading = false
    @State private var isButtonPressed = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with logo centered and skip button
            ZStack {
                // Centered logo
                HStack(spacing: 8) {
                    Image("PhlockLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)

                    Text("phlock")
                        .font(.lora(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                }

                // Skip button on the right
                HStack {
                    Spacer()
                    Button("skip") {
                        skipNotifications()
                    }
                    .font(.lora(size: 15))
                    .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)

            // Mock phone with iOS notification
            ZStack {
                // Phone body (black bezel)
                RoundedRectangle(cornerRadius: 44)
                    .fill(Color.black)
                    .frame(width: 260, height: 420)

                // Phone screen
                RoundedRectangle(cornerRadius: 38)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .frame(width: 248, height: 408)

                // Side buttons - Volume
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 3, height: 28)
                    .offset(x: -131, y: -80)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 3, height: 28)
                    .offset(x: -131, y: -40)

                // Side button - Power
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 3, height: 40)
                    .offset(x: 131, y: -60)

                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 40)

                    // Mock notification banner
                    HStack(spacing: 10) {
                        // App icon
                        Image("PhlockLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 34, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("phlock")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("now")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Text("someone just added a song to your phlock!")
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                        }
                    }
                    .padding(10)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(14)
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                    .padding(.horizontal, 10)

                    Spacer()

                    // Mock dialog card
                    VStack(spacing: 8) {
                        // Bell icon
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.blue)
                            .padding(.top, 12)

                        Text("\"phlock\" Would Like to\nSend You Notifications")
                            .font(.system(size: 13, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)

                        HStack(spacing: 6) {
                            // Don't Allow button (greyed out)
                            Text("Don't Allow")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)

                            // Allow button (highlighted)
                            Text("Allow")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.primaryColor(for: colorScheme))
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(Color.primaryColor(for: colorScheme).opacity(0.1))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.primaryColor(for: colorScheme).opacity(0.4), lineWidth: 1.5)
                                )
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(14)
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                    .padding(.horizontal, 10)

                    Spacer()
                        .frame(height: 12)

                    // Home indicator
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.3))
                        .frame(width: 90, height: 4)
                        .padding(.bottom, 6)
                }
                .frame(width: 248, height: 408)

                // Pointing hand emoji - positioned at "Allow" button
                Text("👆")
                    .font(.system(size: 28))
                    .offset(x: 50, y: 178)
            }
            .padding(.top, 8)

            Spacer()

            // Title and description
            VStack(spacing: 12) {
                Text("never miss a pick")
                    .font(.lora(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text("get notified when friends share\ntheir daily songs")
                    .font(.lora(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)

            Spacer(minLength: 16)

            // Continue button - using gesture for press feedback
            Group {
                if isLoading {
                    ProgressView()
                        .tint(Color.background(for: colorScheme))
                } else {
                    Text("continue")
                        .font(.lora(size: 17, weight: .semiBold))
                }
            }
            .foregroundColor(Color.background(for: colorScheme))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.primaryColor(for: colorScheme))
            .cornerRadius(16)
            .scaleEffect(isButtonPressed ? 0.97 : 1.0)
            .opacity(isButtonPressed ? 0.8 : 1.0)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isLoading else { return }
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isButtonPressed = true
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isButtonPressed = false
                        }
                        guard !isLoading else { return }
                        Task {
                            await requestNotificationPermission()
                        }
                    }
            )
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .background(Color.appBackground)
    }

    // MARK: - Actions

    private func requestNotificationPermission() async {
        isLoading = true

        // Request notification permission
        let granted = await PushNotificationService.shared.requestAuthorization()

        await MainActor.run {
            isLoading = false
            // Move to music platform regardless of result
            authState.needsNotificationPermission = false
            authState.needsMusicPlatform = true
            print(granted ? "✅ Notifications enabled - moving to music platform" : "⏭️ Notifications declined - moving to music platform")
        }
    }

    private func skipNotifications() {
        authState.needsNotificationPermission = false
        authState.needsMusicPlatform = true
        print("⏭️ Notifications skipped - moving to music platform")
    }
}

#Preview {
    OnboardingNotificationsView()
        .environmentObject(AuthenticationState())
}
