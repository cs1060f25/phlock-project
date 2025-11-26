import SwiftUI

/// Clean radial phlock visualization with concentric rings by generation
struct PhlockNetworkView: View {
    let visualizationData: PhlockVisualizationData

    @State private var selectedNodeId: String?
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastDragValue: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var highlightGeneration: Int?

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main visualization
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let maxGeneration = visualizationData.nodes.map { $0.depth }.max() ?? 0
                    let baseRadius = min(size.width, size.height) / 2 - 40

                    // Apply transformations - scale from center, then translate
                    context.translateBy(x: size.width / 2, y: size.height / 2)
                    context.scaleBy(x: scale, y: scale)
                    context.translateBy(x: -size.width / 2 + offset.width / scale, y: -size.height / 2 + offset.height / scale)

                    // Group nodes by generation
                    let nodesByGen = Dictionary(grouping: visualizationData.nodes, by: { $0.depth })

                    // Draw generation rings (background guides)
                    if maxGeneration > 0 {
                        drawGenerationRings(
                            context: context,
                            center: center,
                            maxGeneration: maxGeneration,
                            baseRadius: baseRadius
                        )
                    }

                    // Draw connections first (so they're behind nodes)
                    drawConnections(
                        context: context,
                        center: center,
                        baseRadius: baseRadius,
                        nodesByGen: nodesByGen,
                        maxGeneration: maxGeneration
                    )

                    // Draw nodes
                    drawNodes(
                        context: context,
                        center: center,
                        baseRadius: baseRadius,
                        nodesByGen: nodesByGen,
                        maxGeneration: maxGeneration,
                        currentScale: scale
                    )
                }
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = min(max(lastScale * value, 0.5), 5.0)
                        }
                        .onEnded { value in
                            lastScale = scale
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastDragValue.width + value.translation.width,
                                height: lastDragValue.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastDragValue = offset
                        }
                )
                .onTapGesture { location in
                    handleTap(at: location, in: geometry.size)
                }

                // Top controls
                VStack {
                    HStack {
                        Spacer()

                        // Generation filter
                        let maxGen = visualizationData.nodes.map { $0.depth }.max() ?? 0
                        if maxGen > 1 {
                            Menu {
                                Button("All Generations") {
                                    withAnimation {
                                        highlightGeneration = nil
                                    }
                                }
                                ForEach(0...maxGen, id: \.self) { gen in
                                    Button("Generation \(gen)") {
                                        withAnimation {
                                            highlightGeneration = gen
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "slider.horizontal.3")
                                    Text(highlightGeneration != nil ? "Gen \(highlightGeneration!)" : "Filter")
                                }
                                .font(.dmSans(size: 10))
                                .foregroundColor(highlightGeneration != nil ? .white : .secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(highlightGeneration != nil ? Color.blue : Color.gray.opacity(0.2))
                                .cornerRadius(20)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)

                    Spacer()

                    // Node detail panel (bottom)
                    if let nodeId = selectedNodeId,
                       let node = visualizationData.nodes.first(where: { $0.id == nodeId }) {
                        NodeDetailPanel(
                            node: node,
                            visualizationData: visualizationData,
                            onDismiss: { selectedNodeId = nil }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding()
                    }
                }

                // Legend
                if selectedNodeId == nil {
                    VStack {
                        Spacer()
                        HStack {
                            NetworkLegend()
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                            Spacer()
                        }
                        .padding()
                    }
                }
            }
        }
    }

    // MARK: - Drawing Functions

    private func drawGenerationRings(
        context: GraphicsContext,
        center: CGPoint,
        maxGeneration: Int,
        baseRadius: CGFloat
    ) {
        for gen in 1...maxGeneration {
            let radius = calculateRadius(for: gen, maxGeneration: maxGeneration, baseRadius: baseRadius)

            let ringPath = Path(ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))

            let isHighlighted = highlightGeneration == gen
            let opacity: Double = isHighlighted ? 0.4 : (highlightGeneration != nil ? 0.1 : 0.15)

            context.stroke(
                ringPath,
                with: .color((colorScheme == .dark ? Color.white : Color.gray).opacity(opacity)),
                style: StrokeStyle(lineWidth: isHighlighted ? 2 : 1, dash: [5, 5])
            )
        }
    }

    private func drawConnections(
        context: GraphicsContext,
        center: CGPoint,
        baseRadius: CGFloat,
        nodesByGen: [Int: [VisualizationNode]],
        maxGeneration: Int
    ) {
        // Calculate all node positions first
        var nodePositions: [String: CGPoint] = [:]
        for (gen, nodes) in nodesByGen {
            let positions = calculateNodePositions(
                for: nodes,
                generation: gen,
                center: center,
                baseRadius: baseRadius,
                maxGeneration: maxGeneration
            )
            nodePositions.merge(positions) { $1 }
        }

        // Draw links
        for link in visualizationData.links {
            guard let sourcePos = nodePositions[link.source],
                  let targetPos = nodePositions[link.target] else {
                continue
            }

            // Determine if this link should be highlighted
            let sourceNode = visualizationData.nodes.first { $0.id == link.source }
            let targetNode = visualizationData.nodes.first { $0.id == link.target }

            let isHighlighted = highlightGeneration == nil ||
                                sourceNode?.depth == highlightGeneration ||
                                targetNode?.depth == highlightGeneration

            let isSelected = selectedNodeId == link.source || selectedNodeId == link.target
            let hasSelection = selectedNodeId != nil

            // Create curved path
            var path = Path()
            path.move(to: sourcePos)

            // Control point for curve (slightly inward)
            let midX = (sourcePos.x + targetPos.x) / 2
            let midY = (sourcePos.y + targetPos.y) / 2
            let controlX = midX + (center.x - midX) * 0.2
            let controlY = midY + (center.y - midY) * 0.2
            let controlPoint = CGPoint(x: controlX, y: controlY)

            path.addQuadCurve(to: targetPos, control: controlPoint)

            // Much clearer differentiation when a node is selected
            let baseOpacity: Double = isHighlighted ? 0.25 : 0.08
            let opacity: Double
            let lineWidth: CGFloat
            let color: Color

            if hasSelection {
                if isSelected {
                    // Active connections: bright and thick
                    opacity = 0.9
                    lineWidth = 2.5
                    color = Color.blue
                } else {
                    // Inactive connections: very dim
                    opacity = 0.03
                    lineWidth = 0.5
                    color = colorScheme == .dark ? Color.white : Color.gray
                }
            } else {
                // No selection: normal state
                opacity = baseOpacity
                lineWidth = 0.75
                color = colorScheme == .dark ? Color.white : Color.gray
            }

            context.stroke(
                path,
                with: .color(color.opacity(opacity)),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
        }
    }

    private func drawNodes(
        context: GraphicsContext,
        center: CGPoint,
        baseRadius: CGFloat,
        nodesByGen: [Int: [VisualizationNode]],
        maxGeneration: Int,
        currentScale: CGFloat
    ) {
        // Draw by generation (outer to inner) so center node is on top
        let sortedGenerations = nodesByGen.keys.sorted(by: >)

        for gen in sortedGenerations {
            guard let nodes = nodesByGen[gen] else { continue }

            let positions = calculateNodePositions(
                for: nodes,
                generation: gen,
                center: center,
                baseRadius: baseRadius,
                maxGeneration: maxGeneration
            )

            let isHighlighted = highlightGeneration == nil || highlightGeneration == gen

            for node in nodes {
                guard let position = positions[node.id] else { continue }

                let isSelected = selectedNodeId == node.id
                let nodeRadius: CGFloat = node.isRoot ? 16 : 12

                // Node circle
                let nodePath = Path(ellipseIn: CGRect(
                    x: position.x - nodeRadius,
                    y: position.y - nodeRadius,
                    width: nodeRadius * 2,
                    height: nodeRadius * 2
                ))

                // Gradient fill
                let nodeColor = getNodeColor(for: node)
                let opacity = isHighlighted ? 1.0 : 0.3

                context.fill(
                    nodePath,
                    with: .linearGradient(
                        Gradient(colors: [
                            nodeColor.opacity(opacity),
                            nodeColor.opacity(opacity * 0.7)
                        ]),
                        startPoint: CGPoint(x: position.x - nodeRadius, y: position.y - nodeRadius),
                        endPoint: CGPoint(x: position.x + nodeRadius, y: position.y + nodeRadius)
                    )
                )

                // Border
                context.stroke(
                    nodePath,
                    with: .color(isSelected ? Color.white : Color.white.opacity(0.5 * opacity)),
                    style: StrokeStyle(lineWidth: isSelected ? 2 : 1, lineCap: .round)
                )

                // Engagement indicator
                if node.saved && node.forwarded {
                    let ringPath = Path(ellipseIn: CGRect(
                        x: position.x - nodeRadius - 4,
                        y: position.y - nodeRadius - 4,
                        width: (nodeRadius + 4) * 2,
                        height: (nodeRadius + 4) * 2
                    ))
                    context.stroke(
                        ringPath,
                        with: .color(Color.green.opacity(0.3 * opacity)),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                    )
                }

                // Draw initial letter inside node
                context.draw(
                    Text(String(node.name.prefix(1)))
                        .font(.system(size: node.isRoot ? 10 : 8, weight: .bold))
                        .foregroundColor(.white.opacity(opacity * 0.9)),
                    at: position,
                    anchor: .center
                )
            }
        }
    }

    // MARK: - Helper Functions

    private func calculateRadius(for generation: Int, maxGeneration: Int, baseRadius: CGFloat) -> CGFloat {
        if generation == 0 { return 0 }

        // Progressive spacing - inner rings closer, outer rings more spaced
        let maxGen = CGFloat(max(maxGeneration, 1))
        let genFloat = CGFloat(generation)

        // Use a power function for progressive spacing
        let progress = genFloat / maxGen
        return baseRadius * pow(progress, 0.85)
    }

    private func calculateNodePositions(
        for nodes: [VisualizationNode],
        generation: Int,
        center: CGPoint,
        baseRadius: CGFloat,
        maxGeneration: Int
    ) -> [String: CGPoint] {
        var positions: [String: CGPoint] = [:]

        // Center node
        if generation == 0 {
            if let node = nodes.first {
                positions[node.id] = center
            }
            return positions
        }

        // Calculate radius for this generation
        let radius = calculateRadius(for: generation, maxGeneration: maxGeneration, baseRadius: baseRadius)

        // Distribute nodes evenly around the circle
        let angleStep = (2 * CGFloat.pi) / CGFloat(nodes.count)
        let startAngle = -CGFloat.pi / 2 // Start at top

        for (index, node) in nodes.enumerated() {
            let angle = startAngle + (angleStep * CGFloat(index))
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            positions[node.id] = CGPoint(x: x, y: y)
        }

        return positions
    }

    private func getNodeColor(for node: VisualizationNode) -> Color {
        if node.isRoot {
            return Color(red: 0.3, green: 0.6, blue: 1.0)
        } else if node.saved && node.forwarded {
            return Color(red: 0.2, green: 0.8, blue: 0.6)
        } else if node.saved {
            return Color(red: 0.4, green: 0.8, blue: 0.4)
        } else if node.forwarded {
            return Color(red: 0.6, green: 0.7, blue: 1.0)
        } else if node.played {
            return Color(red: 0.7, green: 0.7, blue: 0.8)
        } else {
            return Color(red: 0.5, green: 0.5, blue: 0.6)
        }
    }

    private func handleTap(at location: CGPoint, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxGeneration = visualizationData.nodes.map { $0.depth }.max() ?? 0
        let baseRadius = min(size.width, size.height) / 2 - 80

        // Group nodes
        let nodesByGen = Dictionary(grouping: visualizationData.nodes, by: { $0.depth })

        // Calculate all positions
        var allPositions: [String: CGPoint] = [:]
        for (gen, nodes) in nodesByGen {
            let positions = calculateNodePositions(
                for: nodes,
                generation: gen,
                center: center,
                baseRadius: baseRadius,
                maxGeneration: maxGeneration
            )
            allPositions.merge(positions) { $1 }
        }

        // Adjust for transformations
        let adjustedLocation = CGPoint(
            x: (location.x - size.width / 2 - offset.width) / scale + size.width / 2,
            y: (location.y - size.height / 2 - offset.height) / scale + size.height / 2
        )

        // Find tapped node
        for (nodeId, position) in allPositions {
            let node = visualizationData.nodes.first { $0.id == nodeId }
            let nodeRadius: CGFloat = node?.isRoot == true ? 16 : 12

            let distance = sqrt(
                pow(adjustedLocation.x - position.x, 2) +
                pow(adjustedLocation.y - position.y, 2)
            )

            if distance <= nodeRadius * 1.5 {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedNodeId = selectedNodeId == nodeId ? nil : nodeId
                }
                return
            }
        }

        // Clear selection if tapped elsewhere
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedNodeId = nil
        }
    }
}

// MARK: - Node Detail Panel

struct NodeDetailPanel: View {
    let node: VisualizationNode
    let visualizationData: PhlockVisualizationData
    let onDismiss: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(node.name.prefix(1)))
                        .font(.dmSans(size: 10, weight: .medium))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(node.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))

                HStack(spacing: 8) {
                    Label("Gen \(node.depth)", systemImage: "arrow.down.right.circle")
                        .font(.dmSans(size: 10))
                        .foregroundColor(.secondary)

                    if node.saved {
                        Image(systemName: "heart.fill")
                            .font(.dmSans(size: 10))
                            .foregroundColor(.red)
                    }
                    if node.forwarded {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.dmSans(size: 10))
                            .foregroundColor(.green)
                    }
                    if node.played {
                        Image(systemName: "play.fill")
                            .font(.dmSans(size: 10))
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.dmSans(size: 20, weight: .semiBold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

// MARK: - Legend

struct NetworkLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Engagement")
                .font(.dmSans(size: 10))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                LegendItem(color: Color(red: 0.2, green: 0.8, blue: 0.6), label: "Saved & Shared")
                LegendItem(color: Color(red: 0.4, green: 0.8, blue: 0.4), label: "Saved")
                LegendItem(color: Color(red: 0.6, green: 0.7, blue: 1.0), label: "Shared")
                LegendItem(color: Color(red: 0.7, green: 0.7, blue: 0.8), label: "Played")
            }
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleData = PhlockVisualizationData(
        phlock: PhlockVisualizationData.PhlockBasicInfo(
            id: "1",
            trackName: "Get Lucky",
            artistName: "Daft Punk",
            albumArtUrl: nil
        ),
        nodes: [
            VisualizationNode(id: "1", userId: "1", name: "You", profilePhotoUrl: nil, depth: 0, saved: true, forwarded: true, played: true, isRoot: true),
            VisualizationNode(id: "2", userId: "2", name: "Alex", profilePhotoUrl: nil, depth: 1, saved: true, forwarded: true, played: true, isRoot: false),
            VisualizationNode(id: "3", userId: "3", name: "Maria", profilePhotoUrl: nil, depth: 1, saved: false, forwarded: true, played: true, isRoot: false),
            VisualizationNode(id: "4", userId: "4", name: "James", profilePhotoUrl: nil, depth: 1, saved: true, forwarded: false, played: true, isRoot: false),
            VisualizationNode(id: "5", userId: "5", name: "Sarah", profilePhotoUrl: nil, depth: 2, saved: true, forwarded: true, played: true, isRoot: false),
            VisualizationNode(id: "6", userId: "6", name: "Mike", profilePhotoUrl: nil, depth: 2, saved: false, forwarded: false, played: true, isRoot: false),
            VisualizationNode(id: "7", userId: "7", name: "Emma", profilePhotoUrl: nil, depth: 2, saved: true, forwarded: true, played: true, isRoot: false),
            VisualizationNode(id: "8", userId: "8", name: "Chris", profilePhotoUrl: nil, depth: 3, saved: true, forwarded: false, played: true, isRoot: false),
            VisualizationNode(id: "9", userId: "9", name: "Lisa", profilePhotoUrl: nil, depth: 3, saved: false, forwarded: false, played: false, isRoot: false),
            VisualizationNode(id: "10", userId: "10", name: "Tom", profilePhotoUrl: nil, depth: 3, saved: true, forwarded: true, played: true, isRoot: false),
            VisualizationNode(id: "11", userId: "11", name: "Rachel", profilePhotoUrl: nil, depth: 1, saved: true, forwarded: true, played: true, isRoot: false),
            VisualizationNode(id: "12", userId: "12", name: "David", profilePhotoUrl: nil, depth: 1, saved: false, forwarded: true, played: true, isRoot: false),
            VisualizationNode(id: "13", userId: "13", name: "Sophie", profilePhotoUrl: nil, depth: 1, saved: true, forwarded: false, played: true, isRoot: false),
            VisualizationNode(id: "14", userId: "14", name: "Ryan", profilePhotoUrl: nil, depth: 2, saved: true, forwarded: true, played: true, isRoot: false),
            VisualizationNode(id: "15", userId: "15", name: "Emily", profilePhotoUrl: nil, depth: 2, saved: false, forwarded: false, played: true, isRoot: false)
        ],
        links: [
            VisualizationLink(source: "1", target: "2", timestamp: "2025-10-29T00:00:00Z"),
            VisualizationLink(source: "1", target: "3", timestamp: "2025-10-29T00:00:00Z"),
            VisualizationLink(source: "1", target: "4", timestamp: "2025-10-29T00:00:00Z"),
            VisualizationLink(source: "1", target: "11", timestamp: "2025-10-29T00:00:00Z"),
            VisualizationLink(source: "1", target: "12", timestamp: "2025-10-29T00:00:00Z"),
            VisualizationLink(source: "1", target: "13", timestamp: "2025-10-29T00:00:00Z"),
            VisualizationLink(source: "2", target: "5", timestamp: "2025-10-29T01:00:00Z"),
            VisualizationLink(source: "2", target: "6", timestamp: "2025-10-29T01:00:00Z"),
            VisualizationLink(source: "3", target: "7", timestamp: "2025-10-29T02:00:00Z"),
            VisualizationLink(source: "11", target: "14", timestamp: "2025-10-29T02:00:00Z"),
            VisualizationLink(source: "12", target: "15", timestamp: "2025-10-29T02:00:00Z"),
            VisualizationLink(source: "5", target: "8", timestamp: "2025-10-29T03:00:00Z"),
            VisualizationLink(source: "5", target: "9", timestamp: "2025-10-29T03:00:00Z"),
            VisualizationLink(source: "7", target: "10", timestamp: "2025-10-29T04:00:00Z")
        ],
        metrics: PhlockMetrics(totalReach: 15, generations: 4, saveRate: 0.7, forwardRate: 0.6, viralityScore: 7.8)
    )

    PhlockNetworkView(visualizationData: sampleData)
}
