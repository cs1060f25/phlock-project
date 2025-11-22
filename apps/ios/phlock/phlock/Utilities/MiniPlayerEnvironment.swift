import SwiftUI

private struct MiniPlayerBottomInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var miniPlayerBottomInset: CGFloat {
        get { self[MiniPlayerBottomInsetKey.self] }
        set { self[MiniPlayerBottomInsetKey.self] = newValue }
    }
}
