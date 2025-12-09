import SwiftUI

struct ViralSharePreviewView: View {
    let userId: UUID
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedStyle: ViralShareStyle = .magazine
    @State private var shareData: ViralShareData?
    @State private var isLoading = true
    @State private var error: Error?
    
    // For sharing
    @State private var renderedImage: UIImage?
    @State private var isSharing = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let data = shareData {
                    VStack(spacing: 20) {
                        // Carousel
                        TabView(selection: $selectedStyle) {
                            ForEach(ViralShareStyle.allCases) { style in
                                artifactView(for: style, data: data)
                                    .tag(style)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .frame(height: 500) // Aspect ratio container
                        
                        // Style Picker (Text)
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
                                                    .fill(selectedStyle == style ? Color.white.opacity(0.2) : Color.clear)
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer()
                        
                        // Share Button
                        Button {
                            shareArtifact(data: data)
                        } label: {
                            HStack {
                                Text("Share to Instagram")
                                    .font(.system(size: 16, weight: .bold))
                                Image(systemName: "arrow.up.right")
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(30)
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                } else if let error = error {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text("Could not load recap")
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("daily recap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $isSharing) {
                if let image = renderedImage {
                    ShareSheet(activityItems: [image])
                }
            }
        }
        .task {
            await loadData()
        }
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
        .cornerRadius(12)
        .shadow(radius: 10)
        .padding()
    }
    
    private func loadData() async {
        do {
            shareData = try await ShareService.shared.getViralShareData(for: userId)
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
    
    @MainActor
    private func shareArtifact(data: ViralShareData) {
        // Render the current view
        let viewToRender = artifactView(for: selectedStyle, data: data)
            .frame(width: 1080, height: 1920) // Render at full resolution
        
        if let image = ShareArtifactRenderer.render(view: viewToRender) {
            self.renderedImage = image
            self.isSharing = true
        }
    }
}

// Helper for standard share sheet with app icon
struct ShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    let message: String

    init(activityItems: [Any]) {
        // Extract image from activity items for backwards compatibility
        self.image = activityItems.compactMap { $0 as? UIImage }.first ?? UIImage()
        self.message = "hey cutie, here's @myphlock - join so i can send you songs too https://phlock.app"
    }

    init(image: UIImage, message: String) {
        self.image = image
        self.message = message
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Use custom share item sources for proper app icon in share sheet
        let imageSource = ShareItemSource(image: image, message: message)
        let messageSource = ShareMessageSource(message: message)
        return UIActivityViewController(activityItems: [imageSource, messageSource], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
