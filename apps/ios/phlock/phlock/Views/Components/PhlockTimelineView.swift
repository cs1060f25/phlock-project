import SwiftUI

/// Alternative timeline view for phlock visualization
/// Shows the music propagation over time in a linear format
struct PhlockTimelineView: View {
    let visualizationData: PhlockVisualizationData
    @State private var selectedEventId: String?
    @State private var timelineScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var scrollPosition: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme

    private var timeRange: (min: Date, max: Date) {
        let timestamps = visualizationData.nodes.compactMap { node in
            findTimestamp(for: node.id)
        }

        guard !timestamps.isEmpty else {
            return (Date(), Date().addingTimeInterval(3600))
        }

        let min = timestamps.min() ?? Date()
        let max = timestamps.max() ?? Date()

        // Add padding
        let padding = max.timeIntervalSince(min) * 0.1
        return (min.addingTimeInterval(-padding), max.addingTimeInterval(padding))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            TimelineHeader(phlock: visualizationData.phlock)
                .padding()

            // Timeline
            ScrollView(.horizontal, showsIndicators: false) {
                TimelineCanvas(
                    data: visualizationData,
                    selectedEventId: $selectedEventId,
                    scale: timelineScale,
                    timeRange: timeRange
                )
                .frame(width: calculateTimelineWidth())
            }
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        timelineScale = min(max(lastScale * value, 0.5), 3.0)
                    }
                    .onEnded { _ in
                        lastScale = timelineScale
                    }
            )

            // Event details
            if let eventId = selectedEventId,
               let event = findEvent(with: eventId) {
                EventDetailCard(event: event)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func calculateTimelineWidth() -> CGFloat {
        let baseWidth: CGFloat = 1200
        return baseWidth * timelineScale
    }

    private func findEvent(with id: String) -> TimelineEvent? {
        // Convert nodes to timeline events
        let events = visualizationData.nodes.map { node in
            TimelineEvent(
                id: node.id,
                userName: node.name,
                action: determineAction(node),
                depth: node.depth,
                timestamp: findTimestamp(for: node.id)
            )
        }
        return events.first { $0.id == id }
    }

    private func determineAction(_ node: VisualizationNode) -> String {
        if node.saved && node.forwarded {
            return "Saved & Shared"
        } else if node.saved {
            return "Saved"
        } else if node.forwarded {
            return "Shared"
        } else if node.played {
            return "Played"
        } else {
            return "Received"
        }
    }

    private func findTimestamp(for nodeId: String) -> Date {
        // Find the link that created this node
        if let link = visualizationData.links.first(where: { $0.target == nodeId }) {
            return ISO8601DateFormatter().date(from: link.timestamp) ?? Date()
        }
        return Date()
    }
}

// MARK: - Timeline Header

struct TimelineHeader: View {
    let phlock: PhlockVisualizationData.PhlockBasicInfo

    var body: some View {
        HStack(spacing: 16) {
            // Album art placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.dmSans(size: 20, weight: .semiBold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(phlock.trackName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(phlock.artistName)
                    .font(.dmSans(size: 10))
                    .foregroundColor(.secondary)
                Text("Timeline View")
                    .font(.dmSans(size: 10))
                    .foregroundColor(.blue)
            }

            Spacer()
        }
    }
}

// MARK: - Timeline Canvas

struct TimelineCanvas: View {
    let data: PhlockVisualizationData
    @Binding var selectedEventId: String?
    let scale: CGFloat
    let timeRange: (min: Date, max: Date)

    var body: some View {
        Canvas { context, size in
            let events = createTimelineEvents()
            let lanes = organizeLanes(events: events)

            // Draw time axis
            drawTimeAxis(context: context, size: size)

            // Draw lanes
            for (laneIndex, lane) in lanes.enumerated() {
                drawLane(
                    context: context,
                    events: lane,
                    laneIndex: laneIndex,
                    totalLanes: lanes.count,
                    size: size
                )
            }

            // Draw connections
            drawConnections(context: context, events: events, size: size)
        }
        .frame(height: 400)
        .onTapGesture { location in
            handleTap(at: location)
        }
    }

    private func createTimelineEvents() -> [TimelineEvent] {
        data.nodes.map { node in
            TimelineEvent(
                id: node.id,
                userName: node.name,
                action: determineNodeAction(node),
                depth: node.depth,
                timestamp: findNodeTimestamp(node.id)
            )
        }
    }

    private func determineNodeAction(_ node: VisualizationNode) -> String {
        if node.saved && node.forwarded {
            return "💚 Saved & Shared"
        } else if node.saved {
            return "❤️ Saved"
        } else if node.forwarded {
            return "📤 Shared"
        } else if node.played {
            return "▶️ Played"
        } else {
            return "📥 Received"
        }
    }

    private func findNodeTimestamp(_ nodeId: String) -> Date {
        if let link = data.links.first(where: { $0.target == nodeId }) {
            return ISO8601DateFormatter().date(from: link.timestamp) ?? Date()
        }
        return Date()
    }

    private func organizeLanes(events: [TimelineEvent]) -> [[TimelineEvent]] {
        // Organize events into non-overlapping lanes
        var lanes: [[TimelineEvent]] = []

        for event in events.sorted(by: { $0.timestamp < $1.timestamp }) {
            var placed = false
            for i in 0..<lanes.count {
                if canPlaceInLane(event: event, lane: lanes[i]) {
                    lanes[i].append(event)
                    placed = true
                    break
                }
            }
            if !placed {
                lanes.append([event])
            }
        }

        return lanes
    }

    private func canPlaceInLane(event: TimelineEvent, lane: [TimelineEvent]) -> Bool {
        // Check if event can be placed without overlap
        return !lane.contains { existing in
            abs(existing.timestamp.timeIntervalSince(event.timestamp)) < 3600 // 1 hour minimum spacing
        }
    }

    private func drawTimeAxis(context: GraphicsContext, size: CGSize) {
        // Draw horizontal time axis
        var path = Path()
        path.move(to: CGPoint(x: 50, y: size.height - 30))
        path.addLine(to: CGPoint(x: size.width - 50, y: size.height - 30))

        context.stroke(
            path,
            with: .color(.gray.opacity(0.3)),
            style: StrokeStyle(lineWidth: 2, lineCap: .round)
        )

        // Draw time markers with labels
        let markerCount = 5
        let totalDuration = timeRange.max.timeIntervalSince(timeRange.min)

        for i in 0...markerCount {
            let progress = CGFloat(i) / CGFloat(markerCount)
            let x = 50 + progress * (size.width - 100)

            var markerPath = Path()
            markerPath.move(to: CGPoint(x: x, y: size.height - 35))
            markerPath.addLine(to: CGPoint(x: x, y: size.height - 25))

            context.stroke(
                markerPath,
                with: .color(.gray.opacity(0.5)),
                style: StrokeStyle(lineWidth: 1)
            )

            // Add time label
            let timestamp = timeRange.min.addingTimeInterval(totalDuration * Double(progress))
            let timeText = timestamp.formatted(date: .omitted, time: .shortened)

            context.draw(
                Text(timeText)
                    .font(.dmSans(size: 10))
                    .foregroundColor(.secondary),
                at: CGPoint(x: x, y: size.height - 15),
                anchor: .center
            )
        }
    }

    private func drawLane(
        context: GraphicsContext,
        events: [TimelineEvent],
        laneIndex: Int,
        totalLanes: Int,
        size: CGSize
    ) {
        let laneHeight = (size.height - 100) / CGFloat(max(totalLanes, 1))
        let laneY = 50 + CGFloat(laneIndex) * laneHeight

        for event in events {
            let x = mapTimeToX(timestamp: event.timestamp, size: size)
            let nodeRadius: CGFloat = 12
            let isSelected = selectedEventId == event.id

            // Draw selection glow if selected
            if isSelected {
                let glowPath = Path(ellipseIn: CGRect(
                    x: x - nodeRadius - 3,
                    y: laneY - nodeRadius - 3,
                    width: (nodeRadius + 3) * 2,
                    height: (nodeRadius + 3) * 2
                ))

                context.stroke(
                    glowPath,
                    with: .color(.white.opacity(0.8)),
                    style: StrokeStyle(lineWidth: 2)
                )
            }

            // Draw node
            let nodePath = Path(ellipseIn: CGRect(
                x: x - nodeRadius,
                y: laneY - nodeRadius,
                width: nodeRadius * 2,
                height: nodeRadius * 2
            ))

            let color = getEventColor(action: event.action)
            context.fill(
                nodePath,
                with: .linearGradient(
                    Gradient(colors: [color, color.opacity(0.7)]),
                    startPoint: CGPoint(x: x - nodeRadius, y: laneY - nodeRadius),
                    endPoint: CGPoint(x: x + nodeRadius, y: laneY + nodeRadius)
                )
            )

            context.stroke(
                nodePath,
                with: .color(isSelected ? .white : .white.opacity(0.6)),
                style: StrokeStyle(lineWidth: isSelected ? 2 : 1)
            )

            // Draw initial letter
            context.draw(
                Text(String(event.userName.prefix(1)))
                    .font(.dmSans(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.9)),
                at: CGPoint(x: x, y: laneY),
                anchor: .center
            )
        }
    }

    private func drawConnections(
        context: GraphicsContext,
        events: [TimelineEvent],
        size: CGSize
    ) {
        // First organize into lanes to find Y positions
        let lanes = organizeLanes(events: events)
        let totalLanes = lanes.count
        let laneHeight = (size.height - 100) / CGFloat(max(totalLanes, 1))

        // Create a map of event IDs to their Y positions
        var eventYPositions: [String: CGFloat] = [:]
        for (laneIndex, lane) in lanes.enumerated() {
            let laneY = 50 + CGFloat(laneIndex) * laneHeight
            for event in lane {
                eventYPositions[event.id] = laneY
            }
        }

        // Draw connections
        for link in data.links {
            if let sourceEvent = events.first(where: { $0.id == link.source }),
               let targetEvent = events.first(where: { $0.id == link.target }),
               let sourceY = eventYPositions[link.source],
               let targetY = eventYPositions[link.target] {

                let sourceX = mapTimeToX(timestamp: sourceEvent.timestamp, size: size)
                let targetX = mapTimeToX(timestamp: targetEvent.timestamp, size: size)

                var path = Path()
                path.move(to: CGPoint(x: sourceX, y: sourceY))

                // Control point for smooth curve
                let controlX = (sourceX + targetX) / 2
                let controlY = (sourceY + targetY) / 2 - 30

                path.addQuadCurve(
                    to: CGPoint(x: targetX, y: targetY),
                    control: CGPoint(x: controlX, y: controlY)
                )

                context.stroke(
                    path,
                    with: .color(.blue.opacity(0.4)),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
            }
        }
    }

    private func mapTimeToX(timestamp: Date, size: CGSize) -> CGFloat {
        // Map timestamp to x coordinate based on actual time range
        let totalDuration = timeRange.max.timeIntervalSince(timeRange.min)
        guard totalDuration > 0 else {
            return size.width / 2
        }

        let elapsed = timestamp.timeIntervalSince(timeRange.min)
        let progress = CGFloat(elapsed / totalDuration)

        // Map to canvas width with padding
        return 50 + progress * (size.width - 100)
    }

    private func getEventColor(action: String) -> Color {
        if action.contains("Saved & Shared") {
            return .green
        } else if action.contains("Saved") {
            return .red
        } else if action.contains("Shared") {
            return .blue
        } else if action.contains("Played") {
            return .purple
        } else {
            return .gray
        }
    }

    private func handleTap(at location: CGPoint) {
        let events = createTimelineEvents()
        let lanes = organizeLanes(events: events)
        let totalLanes = lanes.count
        let laneHeight = (400 - 100) / CGFloat(max(totalLanes, 1))

        // Find tapped event
        for (laneIndex, lane) in lanes.enumerated() {
            let laneY = 50 + CGFloat(laneIndex) * laneHeight

            for event in lane {
                let x = mapTimeToX(timestamp: event.timestamp, size: CGSize(width: 1200, height: 400))
                let nodeRadius: CGFloat = 12

                let distance = sqrt(
                    pow(location.x - x, 2) +
                    pow(location.y - laneY, 2)
                )

                if distance <= nodeRadius * 2 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedEventId = selectedEventId == event.id ? nil : event.id
                    }
                    return
                }
            }
        }

        // Tap outside - clear selection
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedEventId = nil
        }
    }
}

// MARK: - Timeline Event

struct TimelineEvent: Identifiable {
    let id: String
    let userName: String
    let action: String
    let depth: Int
    let timestamp: Date
}

// MARK: - Event Detail Card

struct EventDetailCard: View {
    let event: TimelineEvent
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            // User avatar
            Circle()
                .fill(LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(event.userName.prefix(1)))
                        .font(.dmSans(size: 10, weight: .medium))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(event.userName)
                    .font(.dmSans(size: 10))

                Text(event.action)
                    .font(.dmSans(size: 10))
                    .foregroundColor(.secondary)

                Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.dmSans(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("Gen \(event.depth)")
                .font(.dmSans(size: 10))
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
        }
        .padding(16)
        .background(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.05))
        .cornerRadius(16)
    }
}

// MARK: - Preview

#Preview("Timeline View") {
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
            VisualizationNode(id: "4", userId: "4", name: "James", profilePhotoUrl: nil, depth: 2, saved: true, forwarded: false, played: true, isRoot: false)
        ],
        links: [
            VisualizationLink(source: "1", target: "2", timestamp: "2025-10-29T10:00:00Z"),
            VisualizationLink(source: "1", target: "3", timestamp: "2025-10-29T11:00:00Z"),
            VisualizationLink(source: "2", target: "4", timestamp: "2025-10-29T14:00:00Z")
        ],
        metrics: PhlockMetrics(totalReach: 4, generations: 2, saveRate: 0.75, forwardRate: 0.67, viralityScore: 7.5)
    )

    PhlockTimelineView(visualizationData: sampleData)
}