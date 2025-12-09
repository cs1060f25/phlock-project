import SwiftUI
import UIKit

@MainActor
struct ShareArtifactRenderer {
    /// Render a SwiftUI view to a UIImage with high resolution suitable for social sharing
    static func render<Content: View>(view: Content, size: CGSize = CGSize(width: 1080, height: 1920)) -> UIImage? {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 3.0 // High resolution
        return renderer.uiImage
    }
}
