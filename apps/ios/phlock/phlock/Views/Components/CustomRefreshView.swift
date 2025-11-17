import SwiftUI

struct PullToRefreshHelper: UIViewRepresentable {
    @Binding var isRefreshing: Bool
    @Binding var pullProgress: CGFloat
    let onRefresh: () async -> Void

    func makeUIView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.isHidden = true
        view.isUserInteractionEnabled = false
        view.progressHandler = makeProgressHandler()
        return view
    }

    func updateUIView(_ uiView: TrackingView, context: Context) {
        uiView.progressHandler = makeProgressHandler()
        uiView.isRefreshing = isRefreshing
        uiView.attachIfNeeded()

        if !isRefreshing && pullProgress != uiView.currentProgress {
            DispatchQueue.main.async {
                self.pullProgress = uiView.currentProgress
            }
        }
    }

    final class TrackingView: UIView {
        var isRefreshing: Bool = false {
            didSet {
                if oldValue && !isRefreshing {
                    resetProgressAfterRefresh()
                }
            }
        }
        var progressHandler: ((CGFloat) -> Void)?

        private weak var scrollView: UIScrollView?
        private var offsetObservation: NSKeyValueObservation?
        private(set) var currentProgress: CGFloat = 0
        private let pullDistance: CGFloat = 80

        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            attachIfNeeded()
        }

        override func removeFromSuperview() {
            super.removeFromSuperview()
            offsetObservation?.invalidate()
            offsetObservation = nil
            scrollView = nil
        }

        func attachIfNeeded() {
            guard scrollView == nil else { return }

            var ancestor = superview
            while let view = ancestor {
                if let scroll = findScrollView(in: view) {
                    scrollView = scroll
                    observe(scrollView: scroll)
                    break
                }
                ancestor = view.superview
            }
        }

        private func findScrollView(in view: UIView) -> UIScrollView? {
            if let scroll = view as? UIScrollView {
                return scroll
            }

            for subview in view.subviews where subview !== self {
                if let found = findScrollView(in: subview) {
                    return found
                }
            }

            return nil
        }

        private func observe(scrollView: UIScrollView) {
            offsetObservation?.invalidate()
            scrollView.alwaysBounceVertical = true
            scrollView.bounces = true
            offsetObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scroll, _ in
                self?.handle(offset: scroll.contentOffset.y)
            }
        }

        private func handle(offset: CGFloat) {
            guard !isRefreshing else { return }

            if offset < 0 {
                let progress = min(1.0, max(0, -offset / pullDistance))
                updateProgress(progress)
            } else {
                updateProgress(0)
            }
        }

        private func updateProgress(_ progress: CGFloat) {
            guard currentProgress != progress else { return }
            currentProgress = progress
            progressHandler?(progress)
        }

        private func resetProgressAfterRefresh() {
            // Ensure spacer collapses even if the scroll view has already stopped moving
            if currentProgress != 0 {
                updateProgress(0)
            }
        }

        deinit {
            offsetObservation?.invalidate()
        }
    }

    private func makeProgressHandler() -> (CGFloat) -> Void {
        { progress in
            if progress != pullProgress {
                DispatchQueue.main.async {
                    self.pullProgress = progress
                }
            }
        }
    }
}

extension View {
    func pullToRefreshWithWaveform(
        isRefreshing: Binding<Bool>,
        pullProgress: Binding<CGFloat>,
        colorScheme: ColorScheme,
        overlayCompensation: CGFloat = 0,
        onRefresh: @escaping () async -> Void
    ) -> some View {
        self
            .refreshable {
                await onRefresh()
            }
            .background(
                PullToRefreshHelper(
                    isRefreshing: isRefreshing,
                    pullProgress: pullProgress,
                    onRefresh: onRefresh
                )
            )
            .overlay(alignment: .top) {
                ZStack {
                    if isRefreshing.wrappedValue || pullProgress.wrappedValue > 0 {
                        WaveformLoadingView(
                            barCount: 5,
                            color: colorScheme == .dark ? .white : .black,
                            progress: pullProgress.wrappedValue,
                            isRefreshing: isRefreshing.wrappedValue
                        )
                        .padding(.top, 10)
                    }
                }
                .offset(y: -overlayCompensation)
            }
    }
}
