import SwiftUI

struct ViralArtifactCarousel: View {
    @Binding var selectedStyle: ViralShareStyle
    let data: ViralShareData
    
    var body: some View {
        TabView(selection: $selectedStyle) {
            ForEach(ViralShareStyle.allCases) { style in
                artifactView(for: style, data: data)
                    .tag(style)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
    
    @ViewBuilder
    private func artifactView(for style: ViralShareStyle, data: ViralShareData) -> some View {
        Group {
            switch style {
            case .magazine: MagazineCoverArtifactView(data: data)
            case .festival: FestivalPosterArtifactView(data: data)
            case .mixtape: DailyMixtapeArtifactView(data: data)
            case .notifications: NotificationStackArtifactView(data: data)
            case .palette: ColorPaletteArtifactView(data: data)
            case .ticket: ConcertTicketArtifactView(data: data)
            }
        }
        .scaleEffect(0.28) // Scale down 1080x1920 to ~300x533
        .frame(width: 300, height: 533)
        .cornerRadius(12)
        .shadow(radius: 10)
        .padding()
    }
}

struct ViralStylePicker: View {
    @Binding var selectedStyle: ViralShareStyle
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(ViralShareStyle.allCases) { style in
                        Button {
                            withAnimation {
                                selectedStyle = style
                            }
                        } label: {
                            Text(style.title.uppercased())
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(selectedStyle == style ? .white : .gray)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(
                                    Capsule()
                                        .fill(selectedStyle == style ? Color.black : Color.clear)
                                )
                        }
                        .id(style)
                    }
                }
                .padding(.horizontal)
            }
            .onChange(of: selectedStyle) { newValue in
                withAnimation {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
}
