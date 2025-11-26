import SwiftUI

extension Font {
    // DM Sans font family with proper weight support
    static func dmSans(size: CGFloat, weight: DMSansWeight = .regular) -> Font {
        switch weight {
        case .light: return Font.custom("DMSans-Light", size: size)
        case .regular: return Font.custom("DMSans-Regular", size: size)
        case .medium: return Font.custom("DMSans-Medium", size: size)
        case .semiBold: return Font.custom("DMSans-SemiBold", size: size)
        case .bold: return Font.custom("DMSans-Bold", size: size)
        case .extraBold: return Font.custom("DMSans-ExtraBold", size: size)
        case .italic: return Font.custom("DMSans-Italic", size: size)
        case .mediumItalic: return Font.custom("DMSans-MediumItalic", size: size)
        case .semiBoldItalic: return Font.custom("DMSans-SemiBoldItalic", size: size)
        case .boldItalic: return Font.custom("DMSans-BoldItalic", size: size)
        }
    }

    enum DMSansWeight {
        case light
        case regular
        case medium
        case semiBold
        case bold
        case extraBold
        case italic
        case mediumItalic
        case semiBoldItalic
        case boldItalic
    }
}
