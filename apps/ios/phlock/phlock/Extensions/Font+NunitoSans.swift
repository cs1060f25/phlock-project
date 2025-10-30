import SwiftUI

extension Font {
    // Nunito Sans font family (Variable Font)
    // Variable fonts allow dynamic weight specification
    static func nunitoSans(size: CGFloat, weight: NunitoSansWeight = .extraLight) -> Font {
        // Use system font with custom font modifier for variable fonts
        // iOS variable fonts require the base font name only
        let baseFont = Font.custom("Nunito Sans", size: size)

        // Apply weight - variable fonts automatically interpolate weights
        switch weight {
        case .extraLight: return baseFont.weight(.thin)       // 200
        case .light: return baseFont.weight(.light)           // 300
        case .regular: return baseFont.weight(.regular)       // 400
        case .medium: return baseFont.weight(.medium)         // 500
        case .semiBold: return baseFont.weight(.semibold)     // 600
        case .bold: return baseFont.weight(.bold)             // 700
        case .extraBold: return baseFont.weight(.heavy)       // 800
        }
    }

    enum NunitoSansWeight {
        case extraLight  // 200
        case light       // 300
        case regular     // 400
        case medium      // 500
        case semiBold    // 600
        case bold        // 700
        case extraBold   // 800
    }
}
