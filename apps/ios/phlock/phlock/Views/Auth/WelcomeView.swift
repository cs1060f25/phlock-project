import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme
    @State private var showPlatformSelection = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background color
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 120)

                    // Colorful Phlock Logo with rotation animation
                    ColorfulPhlockLogoView(size: 240, animate: true)

                    Spacer()
                        .frame(height: 60)

                    // Wordmark
                    Text("phlock")
                        .font(.lora(size: 48, weight: .semiBold))
                        .foregroundColor(.primary)
                        .kerning(-1)

                    Spacer()
                        .frame(height: 16)

                    // Tagline
                    Text("discover music through your friends")
                        .font(.lora(size: 18, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Spacer()

                    // Get Started Button
                    NavigationLink(destination: PlatformSelectionView()) {
                        Text("get started")
                            .font(.lora(size: 17, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(colorScheme == .dark ? Color.white : Color.black)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                }
            }
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AuthenticationState())
}
