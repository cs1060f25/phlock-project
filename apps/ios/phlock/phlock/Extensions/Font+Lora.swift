import SwiftUI

extension Font {
    // Lora font family
    static func lora(size: CGFloat, weight: LoraWeight = .regular) -> Font {
        switch weight {
        case .regular: return Font.custom("Lora-Regular", size: size)
        case .medium: return Font.custom("Lora-Medium", size: size)
        case .semiBold: return Font.custom("Lora-SemiBold", size: size)
        case .bold: return Font.custom("Lora-Bold", size: size)
        }
    }

    enum LoraWeight {
        case regular
        case medium
        case semiBold
        case bold
    }
}
