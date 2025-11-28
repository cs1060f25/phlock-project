import SwiftUI

struct OnboardingCarouselView: View {
    @State private var currentPage = 0
    @Environment(\.colorScheme) var colorScheme
    
    let slides = [
        OnboardingSlide(
            title: "discover",
            description: "hand picked songs for you everyday\nfrom people you follow"
        ),
        OnboardingSlide(
            title: "share",
            description: "post your daily song\nand express your taste"
        ),
        OnboardingSlide(
            title: "connect",
            description: "find your community through\nthe music you love"
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Carousel
            TabView(selection: $currentPage) {
                ForEach(0..<slides.count, id: \.self) { index in
                    SlideView(slide: slides[index])
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 200) // Increased height for card styling
            
            // Custom Page Indicator
            HStack(spacing: 8) {
                ForEach(0..<slides.count, id: \.self) { index in
                    Circle()
                        .fill(currentPage == index ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.spring(), value: currentPage)
                }
            }
            .padding(.bottom, 24)
            
            // Action Button - clean implementation without hidden views
            Group {
                if currentPage < slides.count - 1 {
                    Button {
                        withAnimation {
                            currentPage += 1
                        }
                    } label: {
                        Text("next")
                            .font(.lora(size: 17, weight: .semiBold))
                            .foregroundColor(Color.background(for: colorScheme))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.primaryColor(for: colorScheme))
                            .cornerRadius(16)
                    }
                } else {
                    NavigationLink(destination: SignInView()) {
                        Text("get started")
                            .font(.lora(size: 17, weight: .semiBold))
                            .foregroundColor(Color.background(for: colorScheme))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.primaryColor(for: colorScheme))
                            .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
        }
    }
}

struct OnboardingSlide {
    let title: String
    let description: String
}

struct SlideView: View {
    let slide: OnboardingSlide
    
    var body: some View {
        VStack(spacing: 12) {
            Text(slide.title)
                .font(.lora(size: 24, weight: .bold))
                .foregroundColor(.primary)

            Text(slide.description)
                .font(.lora(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(20)
        .padding(.horizontal, 24) // Padding from screen edges
    }
}

#Preview {
    OnboardingCarouselView()
}
