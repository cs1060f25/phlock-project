import SwiftUI

struct GeometricLogoView: View {
    let size: CGFloat
    var color: Color = .primary

    var body: some View {
        ZStack {
            // Scale from SVG viewBox (240x240) to provided size
            let scale = size / 240.0

            // Center node (you) - r=12 in SVG
            Circle()
                .fill(color)
                .frame(width: 24 * scale, height: 24 * scale)
                .position(x: 120 * scale, y: 120 * scale)

            // First generation (direct connections) - 6 nodes, r=10 in SVG
            ForEach(firstGenPositions, id: \.self) { pos in
                Circle()
                    .fill(color)
                    .frame(width: 20 * scale, height: 20 * scale)
                    .position(x: pos.x * scale, y: pos.y * scale)
            }

            // Second generation (friends of friends) - 12 nodes, r=8 with opacity 0.8 in SVG
            ForEach(secondGenPositions, id: \.self) { pos in
                Circle()
                    .fill(color.opacity(0.8))
                    .frame(width: 16 * scale, height: 16 * scale)
                    .position(x: pos.x * scale, y: pos.y * scale)
            }
        }
        .frame(width: size, height: size)
    }

    // First generation positions (6 nodes, evenly spaced at 60° intervals, 60 units from center)
    // Matching phlock_network_logo_fixed.svg exactly
    private let firstGenPositions: [CGPoint] = [
        CGPoint(x: 120, y: 60),   // Top
        CGPoint(x: 172, y: 90),   // Top right
        CGPoint(x: 172, y: 150),  // Bottom right
        CGPoint(x: 120, y: 180),  // Bottom
        CGPoint(x: 68, y: 150),   // Bottom left
        CGPoint(x: 68, y: 90)     // Top left
    ]

    // Second generation positions (12 nodes, evenly spaced at 30° intervals, 95 units from center)
    // Matching phlock_network_logo_fixed.svg exactly
    private let secondGenPositions: [CGPoint] = [
        CGPoint(x: 120, y: 25),     // Top
        CGPoint(x: 167.5, y: 37.5), // 30°
        CGPoint(x: 202.5, y: 72.5), // 60°
        CGPoint(x: 215, y: 120),    // 90° Right
        CGPoint(x: 202.5, y: 167.5),// 120°
        CGPoint(x: 167.5, y: 202.5),// 150°
        CGPoint(x: 120, y: 215),    // 180° Bottom
        CGPoint(x: 72.5, y: 202.5), // 210°
        CGPoint(x: 37.5, y: 167.5), // 240°
        CGPoint(x: 25, y: 120),     // 270° Left
        CGPoint(x: 37.5, y: 72.5),  // 300°
        CGPoint(x: 72.5, y: 37.5)   // 330°
    ]
}

#Preview {
    VStack(spacing: 40) {
        GeometricLogoView(size: 200, color: .black)
        GeometricLogoView(size: 200, color: .white)
            .background(Color.black)
    }
    .padding()
}
