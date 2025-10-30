import SwiftUI
import WebKit

struct PhlockDetailView: View {
    let phlockId: UUID

    @State private var visualizationData: PhlockVisualizationData?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isPlaying = false
    @State private var showShareSheet = false
    @State private var selectedNodeId: String?
    @State private var viewType: VisualizationType = .network

    enum VisualizationType: String, CaseIterable {
        case stats = "Stats"
        case network = "Network"
        case timeline = "Timeline"

        var icon: String {
            switch self {
            case .stats: return "chart.bar.fill"
            case .network: return "circle.hexagongrid.fill"
            case .timeline: return "timeline.selection"
            }
        }
    }

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Loading phlock...")
            } else if let error = errorMessage {
                ErrorView(message: error) {
                    Task { await loadVisualization() }
                }
            } else if let data = visualizationData {
                VStack(spacing: 0) {
                    // View type picker
                    Picker("View Type", selection: $viewType) {
                        ForEach(VisualizationType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .padding(.top)

                    // Show appropriate visualization
                    Group {
                        switch viewType {
                        case .stats:
                            PhlockStatsView(
                                phlock: data.phlock,
                                metrics: data.metrics,
                                nodes: data.nodes,
                                links: data.links
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .network:
                            PhlockNetworkView(visualizationData: data)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .timeline:
                            PhlockTimelineView(visualizationData: data)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewType)
                }
            }
        }
        .navigationTitle(visualizationData?.phlock.trackName ?? "Phlock")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .task {
            await loadVisualization()
        }
        .sheet(isPresented: $showShareSheet) {
            if let data = visualizationData {
                ShareSheet(phlock: data.phlock, metrics: data.metrics)
            }
        }
    }

    private func loadVisualization() async {
        isLoading = true
        errorMessage = nil

        do {
            visualizationData = try await PhlockService.shared.fetchPhlockVisualization(phlockId: phlockId)
        } catch {
            errorMessage = "Failed to load visualization: \(error.localizedDescription)"
            print("❌ Error loading phlock visualization: \(error)")
        }

        isLoading = false
    }
}

// Old WebView code removed - now using native SwiftUI visualization

// MARK: - Metrics Panel

struct PhlockMetricsPanel: View {
    let metrics: PhlockMetrics
    var viewType: PhlockDetailView.VisualizationType = .network
    @Environment(\.colorScheme) var colorScheme

    private var interactionHint: String {
        switch viewType {
        case .stats:
            return "Scroll to explore detailed metrics and insights"
        case .network:
            return "Pinch to zoom • Drag to pan • Tap nodes to select"
        case .timeline:
            return "Scroll horizontally • Pinch to zoom • Tap events for details"
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Interaction hint
            Text(interactionHint)
                .font(.nunitoSans(size: 13))
                .foregroundColor(.secondary)

            // Metrics Dashboard
            HStack(spacing: 20) {
                MetricCard(
                    title: "Reach",
                    value: "\(metrics.totalReach)",
                    subtitle: "people"
                )

                MetricCard(
                    title: "Generations",
                    value: "\(metrics.generations)",
                    subtitle: "levels deep"
                )

                MetricCard(
                    title: "Save Rate",
                    value: "\(Int(metrics.saveRate * 100))%",
                    subtitle: "saved it"
                )
            }
            .padding(.horizontal, 16)

            // Virality Score
            VStack(spacing: 8) {
                Text("Virality Score")
                    .font(.nunitoSans(size: 13))
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    ForEach(0..<10, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index < Int(metrics.viralityScore) ? Color.green : Color.gray.opacity(0.2))
                            .frame(height: 6)
                    }
                }
                .padding(.horizontal, 40)

                Text(String(format: "%.1f / 10", metrics.viralityScore))
                    .font(.nunitoSans(size: 16, weight: .bold))
            }
        }
        .padding(20)
        .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.05))
        .cornerRadius(20)
        .padding(.horizontal, 16)
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.nunitoSans(size: 11))
                .foregroundColor(.secondary)

            Text(value)
                .font(.nunitoSans(size: 22, weight: .bold))

            Text(subtitle)
                .font(.nunitoSans(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(colorScheme == .dark ? 0.15 : 0.08))
        .cornerRadius(12)
    }
}

// MARK: - Share Sheet

struct ShareSheet: View {
    let phlock: PhlockVisualizationData.PhlockBasicInfo
    let metrics: PhlockMetrics
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Share your phlock")
                    .font(.nunitoSans(size: 20, weight: .bold))
                    .padding(.top, 20)

                Text("Coming soon: Export visualization to social media")
                    .font(.nunitoSans(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PhlockDetailView(phlockId: UUID())
    }
}
