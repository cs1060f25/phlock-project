import SwiftUI

extension Font {
    // Lora font family
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
