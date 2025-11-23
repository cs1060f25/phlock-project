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
            .onChange(of: disabled) { newValue in
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
        background(FullScreenSwipeBack())
    }
}

