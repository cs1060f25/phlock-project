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
    // Custom Hashable Point struct to avoid iOS 18 requirement for CGPoint
    struct Point: Hashable {
        let x: CGFloat
        let y: CGFloat
    }

    // First generation positions (6 nodes, evenly spaced at 60° intervals, 60 units from center)
    // Matching phlock_network_logo_fixed.svg exactly
    private let firstGenPositions: [Point] = [
        Point(x: 120, y: 60),   // Top
        Point(x: 172, y: 90),   // Top right
        Point(x: 172, y: 150),  // Bottom right
        Point(x: 120, y: 180),  // Bottom
        Point(x: 68, y: 150),   // Bottom left
        Point(x: 68, y: 90)     // Top left
    ]

    // Second generation positions (12 nodes, evenly spaced at 30° intervals, 95 units from center)
    // Matching phlock_network_logo_fixed.svg exactly
    private let secondGenPositions: [Point] = [
        Point(x: 120, y: 25),     // Top
        Point(x: 167.5, y: 37.5), // 30°
        Point(x: 202.5, y: 72.5), // 60°
        Point(x: 215, y: 120),    // 90° Right
        Point(x: 202.5, y: 167.5),// 120°
        Point(x: 167.5, y: 202.5),// 150°
        Point(x: 120, y: 215),    // 180° Bottom
        Point(x: 72.5, y: 202.5), // 210°
        Point(x: 37.5, y: 167.5), // 240°
        Point(x: 25, y: 120),     // 270° Left
        Point(x: 37.5, y: 72.5),  // 300°
        Point(x: 72.5, y: 37.5)   // 330°
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
