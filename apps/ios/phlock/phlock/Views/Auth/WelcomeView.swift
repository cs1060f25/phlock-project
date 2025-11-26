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
                        .frame(minHeight: 100)
                    Spacer()
                    
                    // Welcome Title
                    Text("phlock: heard together")
                        .font(.dmSans(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.bottom, 36)
                    
                    // Logo (Original size)
                    ColorfulPhlockLogoView(size: 240, animate: true)
                    
                    Spacer()
                        .frame(height: 36)
                    
                    // Carousel
                    OnboardingCarouselView()
                }
            }
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AuthenticationState())
}
