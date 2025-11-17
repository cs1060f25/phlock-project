import SwiftUI

extension View {
    /// Dismisses the keyboard immediately when tapping outside of it
    /// Uses a simultaneous gesture so it doesn't interfere with other gestures
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    /// Dismisses the keyboard immediately on any touch event (including drag start)
    func dismissKeyboardOnTouch() -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        )
    }
}
