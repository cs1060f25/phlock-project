import Foundation
import Network
import Combine

/// Monitors network connectivity and publishes status changes
@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .unknown

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    enum ConnectionType {
        case wifi
        case cellular
        case wiredEthernet
        case unknown
    }

    private init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(from: path) ?? .unknown

                if path.status == .satisfied {
                    print("📶 Network connected: \(self?.connectionType ?? .unknown)")
                } else {
                    print("📶 Network disconnected")
                }
            }
        }
        monitor.start(queue: queue)
    }

    nonisolated private func stopMonitoring() {
        monitor.cancel()
    }

    private func getConnectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wiredEthernet
        }
        return .unknown
    }

    /// Check if the current network is available (convenience method)
    var isAvailable: Bool {
        isConnected
    }

    /// Throws a network error if not connected
    func requireConnection() throws {
        guard isConnected else {
            throw AppError.network(underlying: nil)
        }
    }
}

// MARK: - Offline Banner View

import SwiftUI

/// A banner that appears when the device is offline
struct OfflineBanner: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared

    var body: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 14, weight: .medium))

                Text("You're offline")
                    .font(.system(size: 14, weight: .medium))

                Spacer()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.gray)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - View Modifier

/// View modifier that adds offline detection to any view
struct OfflineAwareModifier: ViewModifier {
    @ObservedObject var networkMonitor = NetworkMonitor.shared

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            OfflineBanner()
                .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)

            content
        }
    }
}

extension View {
    /// Adds an offline banner that appears when the device loses connectivity
    func offlineAware() -> some View {
        modifier(OfflineAwareModifier())
    }
}
