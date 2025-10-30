import SwiftUI

extension Font {
    // Montserrat font family
    static func montserrat(size: CGFloat, weight: MontserratWeight = .regular) -> Font {
        return .custom(weight.fontName, size: size)
    }

    enum MontserratWeight {
        case light
        case regular
        case medium
        case semiBold
        case bold

        var fontName: String {
            switch self {
            case .light: return "Montserrat-Light"
            case .regular: return "Montserrat-Regular"
            case .medium: return "Montserrat-Medium"
            case .semiBold: return "Montserrat-SemiBold"
            case .bold: return "Montserrat-Bold"
            }
        }
    }
}
