import SwiftUI
import UIKit

/// UIViewControllerRepresentable wrapper for full-screen swipe-back gesture
struct FullScreenSwipeBack: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> FullScreenSwipeBackViewController {
        return FullScreenSwipeBackViewController()
    }

    func updateUIViewController(_ uiViewController: FullScreenSwipeBackViewController, context: Context) {
        // No updates needed
    }
}

/// UIViewController that enables full-screen swipe-back navigation
class FullScreenSwipeBackViewController: UIViewController, UINavigationControllerDelegate {
    private var fullScreenGesture: UIPanGestureRecognizer?
    private var interactiveTransition: UIPercentDrivenInteractiveTransition?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupFullScreenGesture()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cleanupGesture()
    }

    private func setupFullScreenGesture() {
        guard let navController = navigationController,
              let window = view.window,
              fullScreenGesture == nil else { return }

        // Don't modify delegate - just set ourselves as the transition provider
        navController.delegate = self

        // Disable edge gesture
        navController.interactivePopGestureRecognizer?.isEnabled = false

        // Add gesture to WINDOW (not nav view) so it persists during transitions
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        window.addGestureRecognizer(pan)
        fullScreenGesture = pan
    }

    private func cleanupGesture() {
        // Remove gesture from window
        if let gesture = fullScreenGesture, let window = view.window {
            window.removeGestureRecognizer(gesture)
            fullScreenGesture = nil
        }

        // Restore nav controller state
        if let navController = navigationController {
            navController.interactivePopGestureRecognizer?.isEnabled = true
            if navController.delegate === self {
                navController.delegate = nil
            }
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let navController = navigationController else { return }

        let view = navController.view!
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)

        // Calculate progress based on screen width
        let screenWidth = view.bounds.width
        let rawProgress = translation.x / screenWidth
        let progress = min(max(rawProgress, 0), 1)

        switch gesture.state {
        case .began:
            break

        case .changed:
            // Check if this is a valid rightward swipe
            let isRightward = translation.x > 0
            let isHorizontal = abs(translation.x) > abs(translation.y)

            // Start transition once we've confirmed direction and moved enough
            if interactiveTransition == nil && isRightward && isHorizontal && translation.x > 20 {
                // Create transition that expects interactive start
                let transition = UIPercentDrivenInteractiveTransition()
                transition.wantsInteractiveStart = true
                transition.completionSpeed = 0.35
                transition.completionCurve = .easeOut
                interactiveTransition = transition

                // Start the pop
                navController.popViewController(animated: true)

                // Immediately update to current position
                transition.update(progress)
            } else if let transition = interactiveTransition {
                // Continue updating if transition is active
                transition.update(progress)
            }

        case .ended, .cancelled:
            guard let transition = interactiveTransition else {
                return
            }

            let shouldComplete = progress > 0.35 || velocity.x > 1000

            if shouldComplete {
                transition.finish()
            } else {
                transition.cancel()
            }

            interactiveTransition = nil

        default:
            break
        }
    }

    // MARK: - UINavigationControllerDelegate

    func navigationController(_ navigationController: UINavigationController,
                            interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return interactiveTransition
    }
}

// MARK: - UIGestureRecognizerDelegate

extension FullScreenSwipeBackViewController: UIGestureRecognizerDelegate {

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let navController = navigationController else { return false }
        return navController.viewControllers.count > 1
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                          shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
