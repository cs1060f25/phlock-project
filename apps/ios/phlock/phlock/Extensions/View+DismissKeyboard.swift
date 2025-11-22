import SwiftUI
import UIKit
import Combine

extension View {
    /// Dismisses the keyboard immediately when tapping outside of it
    /// Uses a simultaneous gesture so it doesn't interfere with other gestures
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    /// Dismisses the keyboard immediately on any touch event (including drag start)
    func dismissKeyboardOnTouch(enabled: Bool = true) -> some View {
        modifier(KeyboardDismissOnTouchModifier(isEnabled: enabled))
    }

    /// Allows descendants to opt out of the global keyboard-dismiss gesture
    func disableGlobalKeyboardDismiss(_ disabled: Bool) -> some View {
        modifier(GlobalKeyboardDismissDisabler(disabled: disabled))
    }
}

private struct KeyboardDismissOnTouchModifier: ViewModifier {
    @Environment(\.keyboardDismissDisabled) private var isDisabled
    @Environment(\.keyboardDismissCoordinator) private var keyboardDismissCoordinator
    var isEnabled: Bool

    func body(content: Content) -> some View {
        Group {
            if isEnabled && !isDisabled {
                content.simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            guard !keyboardDismissCoordinator.isDisabled else { return }
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                )
            } else {
                content
            }
        }
    }
}

private struct GlobalKeyboardDismissDisabler: ViewModifier {
    @Environment(\.keyboardDismissCoordinator) private var keyboardDismissCoordinator
    var disabled: Bool
    @State private var isApplied = false

    func body(content: Content) -> some View {
        content
            .environment(\.keyboardDismissDisabled, disabled)
            .onAppear {
                updateCoordinator(disabled: disabled)
            }
            .onChange(of: disabled) { _, newValue in
                updateCoordinator(disabled: newValue)
            }
            .onDisappear {
                if isApplied {
                    keyboardDismissCoordinator.decrement()
                    isApplied = false
                }
            }
    }

    private func updateCoordinator(disabled: Bool) {
        if disabled {
            if !isApplied {
                keyboardDismissCoordinator.increment()
                isApplied = true
            }
        } else if isApplied {
            keyboardDismissCoordinator.decrement()
            isApplied = false
        }
    }
}

// MARK: - Keyboard Handling

extension View {
    func keyboardResponsive(extraPadding: CGFloat = 0) -> some View {
        modifier(KeyboardResponsiveModifier(extraPadding: extraPadding))
    }
}

private struct KeyboardResponsiveModifier: ViewModifier {
    @StateObject private var keyboardObserver = KeyboardHeightObserver()
    var extraPadding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.bottom, max(0, keyboardObserver.height - extraPadding))
            .animation(.easeOut(duration: 0.25), value: keyboardObserver.height)
    }
}

final class KeyboardHeightObserver: ObservableObject {
    @Published var height: CGFloat = 0
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handle(notification: notification)
        })

        observers.append(center.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.height = 0
        })
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    private func handle(notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let safeAreaBottom = UIApplication.shared.activeKeyWindow?.safeAreaInsets.bottom ?? 0
        let screenHeight = UIScreen.main.bounds.height
        let overlap = max(0, screenHeight - frame.origin.y)
        let adjustedHeight = max(0, overlap - safeAreaBottom)

        if height != adjustedHeight {
            height = adjustedHeight
        }
    }
}

private extension UIApplication {
    var activeKeyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })
    }
}

private struct KeyboardDismissDisabledKey: EnvironmentKey {
    static let defaultValue = false
}

private struct KeyboardDismissCoordinatorKey: EnvironmentKey {
    static let defaultValue = KeyboardDismissCoordinator.shared
}

extension EnvironmentValues {
    var keyboardDismissDisabled: Bool {
        get { self[KeyboardDismissDisabledKey.self] }
        set { self[KeyboardDismissDisabledKey.self] = newValue }
    }

    var keyboardDismissCoordinator: KeyboardDismissCoordinator {
        get { self[KeyboardDismissCoordinatorKey.self] }
        set { self[KeyboardDismissCoordinatorKey.self] = newValue }
    }
}

final class KeyboardDismissCoordinator {
    static let shared = KeyboardDismissCoordinator()

    private var disableCount: Int = 0

    var isDisabled: Bool {
        disableCount > 0
    }

    func increment() {
        disableCount += 1
    }

    func decrement() {
        disableCount = max(0, disableCount - 1)
    }
}

// MARK: - Full-Screen Back Gesture Support

extension View {
    /// Enables a full-screen back swipe gesture for any embedded NavigationStack
    func fullScreenSwipeBack() -> some View {
        background(FullScreenSwipeBackResolver())
    }
}

private struct FullScreenSwipeBackResolver: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let navigationController = context.coordinator.findNavigationController(from: uiView) else {
                return
            }
            context.coordinator.attachIfNeeded(to: navigationController)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var navigationController: UINavigationController?
        private weak var panGesture: UIPanGestureRecognizer?

        func attachIfNeeded(to navigationController: UINavigationController) {
            if self.navigationController !== navigationController {
                if let existingGesture = panGesture {
                    existingGesture.view?.removeGestureRecognizer(existingGesture)
                }
                self.navigationController = navigationController
                panGesture = nil
            }

            guard panGesture == nil else { return }
            installGesture(on: navigationController)
        }

        private func installGesture(on navigationController: UINavigationController) {
            guard let systemGesture = navigationController.interactivePopGestureRecognizer,
                  let gestureView = systemGesture.view else {
                return
            }

            guard let internalTargets = systemGesture.value(forKey: "_targets") as? [NSObject],
                  let firstTarget = internalTargets.first,
                  let target = firstTarget.value(forKey: "target") else {
                return
            }

            let action = Selector(("handleNavigationTransition:"))
            guard (target as AnyObject).responds(to: action) else { return }

            let gesture = UIPanGestureRecognizer()
            gesture.maximumNumberOfTouches = 1
            gesture.cancelsTouchesInView = true
            gesture.delegate = self
            gesture.addTarget(target, action: action)
            gestureView.addGestureRecognizer(gesture)

            panGesture = gesture
            systemGesture.isEnabled = false
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let panGesture = panGesture, gestureRecognizer === panGesture else {
                return true
            }
            guard let navigationController = navigationController else { return false }
            if navigationController.viewControllers.count <= 1 {
                return false
            }
            let translation = panGesture.translation(in: panGesture.view)
            if translation.x <= 0 {
                return false
            }
            if abs(translation.y) > abs(translation.x) {
                return false
            }
            if let blockingScrollView = scrollViewForCurrentTouch(in: panGesture), blockingScrollView.contentOffset.x > 0 {
                return false
            }
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let panGesture = panGesture, gestureRecognizer === panGesture else {
                return false
            }
            return true
        }

        private func scrollViewForCurrentTouch(in gesture: UIPanGestureRecognizer) -> UIScrollView? {
            guard let hostView = gesture.view else { return nil }
            let location = gesture.location(in: hostView)
            guard let hitView = hostView.hitTest(location, with: nil) else { return nil }

            var current: UIView? = hitView
            while let view = current {
                if let scrollView = view as? UIScrollView {
                    return scrollView
                }
                current = view.superview
            }
            return nil
        }

        fileprivate func findNavigationController(from view: UIView) -> UINavigationController? {
            var responder: UIResponder? = view
            while let currentResponder = responder {
                if let navigationController = currentResponder as? UINavigationController {
                    return navigationController
                }
                if let viewController = currentResponder as? UIViewController,
                   let navigationController = viewController.navigationController {
                    return navigationController
                }
                responder = currentResponder.next
            }

            if let window = view.window {
                return findNavigationController(in: window.rootViewController)
            }

            return nil
        }

        private func findNavigationController(in controller: UIViewController?) -> UINavigationController? {
            guard let controller = controller else { return nil }

            if let navigationController = controller as? UINavigationController {
                return navigationController
            }

            for child in controller.children {
                if let navigationController = findNavigationController(in: child) {
                    return navigationController
                }
            }

            return findNavigationController(in: controller.presentedViewController)
        }
    }
}
