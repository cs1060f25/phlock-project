import SwiftUI

extension Font {
    // Provide a single helper that exposes the Lora weight variants bundled with the app.
    static func lora(size: CGFloat, weight: LoraWeight = .regular) -> Font {
        return .custom(weight.fontName, size: size)
    }

    enum LoraWeight {
        case regular
        case medium
        case semiBold
        case bold

        var fontName: String {
            switch self {
            case .regular: return "Lora-Regular"
            case .medium: return "Lora-Medium"
            case .semiBold: return "Lora-SemiBold"
            case .bold: return "Lora-Bold"
            }
        }
    }
}
