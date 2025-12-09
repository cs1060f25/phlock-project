import SwiftUI
import UIKit

struct UnifiedShareSheet: View {
    let userId: UUID
    @Environment(\.dismiss) private var dismiss

    @State private var selectedStyle: ViralShareStyle = .magazine
    @State private var shareData: ViralShareData?
    @State private var isLoading = true
    @State private var error: Error?

    // For sharing state
    @State private var isRendering = false
    @State private var preparedRenderData: ViralShareRenderData?
    @State private var preRenderedImages: [ViralShareStyle: UIImage] = [:]

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(.black)
            } else if let data = shareData {
                VStack(spacing: 0) {
                    // Top: Artifact Carousel (Flexible Height)
                    ViralArtifactCarousel(selectedStyle: $selectedStyle, data: data)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Middle: Style Picker
                    ViralStylePicker(selectedStyle: $selectedStyle)
                        .padding(.bottom, 20)

                    // Bottom: Share Button
                    shareButton(data: data)
                        .padding(.bottom, 30)
                }
            } else if let error = error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Could not load recap")
                        .foregroundColor(.black)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.gray)
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.black)
                }
            }

            // Loading overlay when rendering
            if isRendering {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                    Text("Preparing...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .task {
            await loadData()
            // Pre-load images, extract colors, and pre-render all styles
            if let data = shareData {
                let renderData = await ViralShareRenderData.prepare(from: data)
                preparedRenderData = renderData

                // Pre-render all styles in background for instant sharing
                for style in ViralShareStyle.allCases {
                    let viewToRender = RenderableArtifactFactory.view(for: style, renderData: renderData)
                        .frame(width: 1080, height: 1920)
                    if let image = ShareArtifactRenderer.render(view: viewToRender) {
                        preRenderedImages[style] = image
                    }
                }
            }
        }
    }

    // MARK: - Share Button

    private func shareButton(data: ViralShareData) -> some View {
        Button {
            Task { await shareArtifact(data: data) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "paperplane.fill")
                Text("Send to...")
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.black)
            .cornerRadius(14)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Data Loading

    private func loadData() async {
        do {
            shareData = try await ShareService.shared.getViralShareData(for: userId)
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    // MARK: - Sharing

    @MainActor
    private func shareArtifact(data: ViralShareData) async {
        // Try to use pre-rendered image first (instant)
        let image: UIImage
        if let preRendered = preRenderedImages[selectedStyle] {
            image = preRendered
        } else {
            // Fallback: render now if not pre-rendered
            isRendering = true
            defer { isRendering = false }

            let renderData: ViralShareRenderData
            if let prepared = preparedRenderData {
                renderData = prepared
            } else {
                renderData = await ViralShareRenderData.prepare(from: data)
            }

            let viewToRender = RenderableArtifactFactory.view(for: selectedStyle, renderData: renderData)
                .frame(width: 1080, height: 1920)

            guard let rendered = ShareArtifactRenderer.render(view: viewToRender) else { return }
            image = rendered
        }

        let message = "hey cutie, here's @myphlock - join so i can send you songs too https://phlock.app"

        // Use custom share item sources for proper app icon in share sheet
        let imageSource = ShareItemSource(image: image, message: message)
        let messageSource = ShareMessageSource(message: message)

        let activityVC = UIActivityViewController(
            activityItems: [imageSource, messageSource],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topController = rootVC
            while let presented = topController.presentedViewController {
                topController = presented
            }
            activityVC.popoverPresentationController?.sourceView = topController.view
            topController.present(activityVC, animated: true)
        }
    }
}
