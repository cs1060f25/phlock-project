import SwiftUI

/// Comprehensive statistics view for phlock analytics
struct PhlockStatsView: View {
    let phlock: PhlockVisualizationData.PhlockBasicInfo
    let metrics: PhlockMetrics
    let nodes: [VisualizationNode]
    let links: [VisualizationLink]

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Track Info Header
                trackInfoSection

                // Key Metrics Cards
                keyMetricsSection

                // Engagement Breakdown
                engagementSection

                // Generation Analysis
                generationSection

                // Top Sharers
                topSharersSection

                // Virality Analysis
                viralitySection
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    // MARK: - Track Info Section

    private var trackInfoSection: some View {
        VStack(spacing: 12) {
            // Album art placeholder
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.dmSans(size: 48, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                )

            Text(phlock.trackName)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text(phlock.artistName)
                .font(.dmSans(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Key Metrics Section

    private var keyMetricsSection: some View {
        VStack(spacing: 16) {
            Text("Overview")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                StatCard(
                    title: "Total Reach",
                    value: "\(metrics.totalReach)",
                    subtitle: "people",
                    color: .blue,
                    icon: "person.3.fill"
                )

                StatCard(
                    title: "Generations",
                    value: "\(metrics.generations)",
                    subtitle: "levels deep",
                    color: .purple,
                    icon: "arrow.down.right.circle.fill"
                )
            }

            HStack(spacing: 12) {
                StatCard(
                    title: "Save Rate",
                    value: String(format: "%.0f%%", metrics.saveRate * 100),
                    subtitle: "saved track",
                    color: .green,
                    icon: "heart.fill"
                )

                StatCard(
                    title: "Share Rate",
                    value: String(format: "%.0f%%", metrics.forwardRate * 100),
                    subtitle: "shared track",
                    color: .orange,
                    icon: "arrow.right.circle.fill"
                )
            }

            // Virality Score (full width)
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.dmSans(size: 20, weight: .semiBold))
                        .foregroundColor(.pink)

                    Text("Virality Score")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))

                    Spacer()

                    Text(String(format: "%.1f", metrics.viralityScore))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.pink)

                    Text("/ 10")
                        .font(.dmSans(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(
                                colors: [.pink, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: geometry.size.width * CGFloat(metrics.viralityScore / 10), height: 8)
                    }
                }
                .frame(height: 8)
            }
            .padding()
            .background(colorScheme == .dark ? Color(white: 0.15) : .white)
            .cornerRadius(16)
        }
    }

    // MARK: - Engagement Section

    private var engagementSection: some View {
        VStack(spacing: 16) {
            Text("Engagement Breakdown")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                EngagementRow(
                    label: "Saved & Shared",
                    count: nodes.filter { $0.saved && $0.forwarded }.count,
                    total: nodes.count,
                    color: Color(red: 0.2, green: 0.8, blue: 0.6),
                    icon: "star.fill"
                )

                Divider().padding(.horizontal)

                EngagementRow(
                    label: "Saved Only",
                    count: nodes.filter { $0.saved && !$0.forwarded }.count,
                    total: nodes.count,
                    color: Color(red: 0.4, green: 0.8, blue: 0.4),
                    icon: "heart.fill"
                )

                Divider().padding(.horizontal)

                EngagementRow(
                    label: "Shared Only",
                    count: nodes.filter { !$0.saved && $0.forwarded }.count,
                    total: nodes.count,
                    color: Color(red: 0.6, green: 0.7, blue: 1.0),
                    icon: "arrow.right.circle.fill"
                )

                Divider().padding(.horizontal)

                EngagementRow(
                    label: "Played Only",
                    count: nodes.filter { $0.played && !$0.saved && !$0.forwarded }.count,
                    total: nodes.count,
                    color: Color(red: 0.7, green: 0.7, blue: 0.8),
                    icon: "play.fill"
                )
            }
            .padding()
            .background(colorScheme == .dark ? Color(white: 0.15) : .white)
            .cornerRadius(16)
        }
    }

    // MARK: - Generation Section

    private var generationSection: some View {
        VStack(spacing: 16) {
            Text("Growth by Generation")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                ForEach(0...metrics.generations, id: \.self) { gen in
                    let genNodes = nodes.filter { $0.depth == gen }
                    GenerationRow(
                        generation: gen,
                        count: genNodes.count,
                        maxCount: nodes.map { node in nodes.filter { $0.depth == node.depth }.count }.max() ?? 1
                    )
                }
            }
            .padding()
            .background(colorScheme == .dark ? Color(white: 0.15) : .white)
            .cornerRadius(16)
        }
    }

    // MARK: - Top Sharers Section

    private var topSharersSection: some View {
        VStack(spacing: 16) {
            Text("Top Contributors")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                // Calculate shares per node
                let sharesPerNode = nodes.map { node -> (VisualizationNode, Int) in
                    let shareCount = links.filter { $0.source == node.id }.count
                    return (node, shareCount)
                }
                .filter { $0.1 > 0 }
                .sorted { $0.1 > $1.1 }
                .prefix(5)

                if sharesPerNode.isEmpty {
                    Text("No shares yet")
                        .font(.dmSans(size: 10))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    ForEach(Array(sharesPerNode.enumerated()), id: \.offset) { index, item in
                        TopSharerRow(
                            rank: index + 1,
                            name: item.0.name,
                            shareCount: item.1,
                            generation: item.0.depth
                        )

                        if index < sharesPerNode.count - 1 {
                            Divider().padding(.horizontal)
                        }
                    }
                }
            }
            .padding()
            .background(colorScheme == .dark ? Color(white: 0.15) : .white)
            .cornerRadius(16)
        }
    }

    // MARK: - Virality Section

    private var viralitySection: some View {
        VStack(spacing: 16) {
            Text("Virality Analysis")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 16) {
                ViralityInsight(
                    icon: "flame.fill",
                    title: "Spread Velocity",
                    value: spreadVelocity,
                    color: .orange
                )

                Divider()

                ViralityInsight(
                    icon: "arrow.triangle.branch",
                    title: "Branching Factor",
                    value: branchingFactor,
                    color: .purple
                )

                Divider()

                ViralityInsight(
                    icon: "chart.bar.fill",
                    title: "Engagement Quality",
                    value: engagementQuality,
                    color: .green
                )
            }
            .padding()
            .background(colorScheme == .dark ? Color(white: 0.15) : .white)
            .cornerRadius(16)
        }
    }

    // MARK: - Computed Properties

    private var spreadVelocity: String {
        let avgSharesPerNode = Double(links.count) / Double(max(nodes.count, 1))
        return String(format: "%.1f shares/person", avgSharesPerNode)
    }

    private var branchingFactor: String {
        // Average number of shares per sharer
        let sharers = nodes.filter { node in
            links.contains { $0.source == node.id }
        }
        let avgBranching = Double(links.count) / Double(max(sharers.count, 1))
        return String(format: "%.1f", avgBranching)
    }

    private var engagementQuality: String {
        let highEngagement = nodes.filter { $0.saved && $0.forwarded }.count
        let percentage = Double(highEngagement) / Double(max(nodes.count, 1)) * 100
        return String(format: "%.0f%% high", percentage)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.dmSans(size: 10, weight: .medium))
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(title)
                .font(.dmSans(size: 10))
                .foregroundColor(.primary)

            Text(subtitle)
                .font(.dmSans(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(colorScheme == .dark ? Color(white: 0.15) : .white)
        .cornerRadius(16)
    }
}

// MARK: - Engagement Row

struct EngagementRow: View {
    let label: String
    let count: Int
    let total: Int
    let color: Color
    let icon: String

    var percentage: Double {
        Double(count) / Double(max(total, 1)) * 100
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.dmSans(size: 10))
                .foregroundColor(color)
                .frame(width: 24)

            Text(label)
                .font(.dmSans(size: 10))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(count)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(String(format: "%.0f%%", percentage))
                .font(.dmSans(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Generation Row

struct GenerationRow: View {
    let generation: Int
    let count: Int
    let maxCount: Int

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Gen \(generation)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .frame(width: 60, alignment: .leading)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 24)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: geometry.size.width * CGFloat(count) / CGFloat(maxCount), height: 24)

                        Text("\(count)")
                            .font(.dmSans(size: 10))
                            .foregroundColor(.white)
                            .padding(.leading, 8)
                    }
                }
                .frame(height: 24)
            }
        }
    }
}

// MARK: - Top Sharer Row

struct TopSharerRow: View {
    let rank: Int
    let name: String
    let shareCount: Int
    let generation: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.blue)
                .frame(width: 30)

            Circle()
                .fill(LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(name.prefix(1)))
                        .font(.dmSans(size: 10))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.dmSans(size: 10))

                Text("Generation \(generation)")
                    .font(.dmSans(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.dmSans(size: 10))
                    .foregroundColor(.green)

                Text("\(shareCount)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Virality Insight

struct ViralityInsight: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.dmSans(size: 20, weight: .semiBold))
                .foregroundColor(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.dmSans(size: 10))
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }

            Spacer()
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
            VisualizationNode(id: "4", userId: "4", name: "James", profilePhotoUrl: nil, depth: 2, saved: true, forwarded: false, played: true, isRoot: false)
        ],
        links: [
            VisualizationLink(source: "1", target: "2", timestamp: "2025-10-29T00:00:00Z"),
            VisualizationLink(source: "1", target: "3", timestamp: "2025-10-29T00:00:00Z"),
            VisualizationLink(source: "2", target: "4", timestamp: "2025-10-29T01:00:00Z")
        ],
        metrics: PhlockMetrics(totalReach: 15, generations: 3, saveRate: 0.73, forwardRate: 0.60, viralityScore: 7.8)
    )

    PhlockStatsView(
        phlock: sampleData.phlock,
        metrics: sampleData.metrics,
        nodes: sampleData.nodes,
        links: sampleData.links
    )
}
