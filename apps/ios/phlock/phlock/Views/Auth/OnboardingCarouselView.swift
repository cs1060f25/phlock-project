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
            .frame(height: 150) // Reduced height further
            
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
            
            // Action Button
            NavigationLink(destination: PlatformSelectionView()) {
                Text(currentPage == slides.count - 1 ? "get started" : "next")
                    .font(.dmSans(size: 17, weight: .semiBold))
                    .foregroundColor(colorScheme == .dark ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(colorScheme == .dark ? Color.white : Color.black)
                    .cornerRadius(16)
            }
            .simultaneousGesture(TapGesture().onEnded {
                if currentPage < slides.count - 1 {
                    withAnimation {
                        currentPage += 1
                    }
                }
            })
            // Only navigate if on the last page
            .disabled(currentPage < slides.count - 1 && false) // Actually we want the button to just scroll if not last page, but NavigationLink triggers nav. 
            // Better approach: Use a Button that changes page, and only show NavLink on last page or use a ZStack.
            .hidden() // Hiding this one to replace with logic below
            .overlay {
                if currentPage < slides.count - 1 {
                    Button {
                        withAnimation {
                            currentPage += 1
                        }
                    } label: {
                        Text("next")
                            .font(.dmSans(size: 17, weight: .semiBold))
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(colorScheme == .dark ? Color.white : Color.black)
                            .cornerRadius(16)
                    }
                } else {
                    NavigationLink(destination: PlatformSelectionView()) {
                        Text("get started")
                            .font(.dmSans(size: 17, weight: .semiBold))
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(colorScheme == .dark ? Color.white : Color.black)
                            .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
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
                .font(.dmSans(size: 24, weight: .bold))
                .foregroundColor(.primary)

            Text(slide.description)
                .font(.dmSans(size: 18))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

#Preview {
    OnboardingCarouselView()
}
