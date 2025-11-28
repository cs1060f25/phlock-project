import SwiftUI
import UIKit

// MARK: - Extensions

extension View {
    func instagramRefreshable(onRefresh: @escaping () async -> Void) -> some View {
        self.refreshable {
            await onRefresh()
        }
    }

    func pullToRefreshWithSpinner(
        isRefreshing: Binding<Bool>,
        pullProgress: Binding<CGFloat>,
        colorScheme: ColorScheme,
        overlayCompensation: CGFloat = 0,
        onRefresh: @escaping () async -> Void
    ) -> some View {
        self.refreshable {
            await onRefresh()
        }
    }
}
