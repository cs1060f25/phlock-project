import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme
    @State private var showPlatformSelection = false
    @State private var isRotating = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                    Spacer()
                        .frame(minHeight: 100)
                    Spacer()
                    
                    // Brand Name & Tagline
                    VStack(spacing: 8) {
                        Text("phlock")
                            .font(.lora(size: 42, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text("heard together")
                            .font(.lora(size: 20, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 40)

                    // Logo (Original size)
                    Image("PhlockLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 234, height: 234)
                        .rotationEffect(.degrees(isRotating ? 360 : 0))
                        .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: isRotating)
                        .onAppear {
                            isRotating = true
                        }
                    
                    Spacer()
                        .frame(height: 10) // Reduced to pull bottom elements up further
                    
                // Carousel
                OnboardingCarouselView()
            }
            .background(Color.white)
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AuthenticationState())
}
