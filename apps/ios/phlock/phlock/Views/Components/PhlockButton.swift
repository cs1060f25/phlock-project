import SwiftUI

struct PhlockButton: View {
    let title: String
    let action: () -> Void
    var variant: ButtonVariant = .primary
    var isLoading: Bool = false
    var fullWidth: Bool = false
    @Environment(\.colorScheme) var colorScheme

    enum ButtonVariant {
        case primary
        case secondary
        case spotify
        case appleMusic

        func backgroundColor(for colorScheme: ColorScheme) -> Color {
            switch self {
            case .primary: return colorScheme == .dark ? .white : .black
            case .secondary: return Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.2)
            case .spotify: return Color(red: 0.11, green: 0.73, blue: 0.33) // Spotify green
            case .appleMusic: return Color(red: 0.98, green: 0.26, blue: 0.42) // Apple Music red
            }
        }

        func foregroundColor(for colorScheme: ColorScheme) -> Color {
            switch self {
            case .primary: return colorScheme == .dark ? .black : .white
            case .secondary: return .primary
            case .spotify, .appleMusic: return .white
            }
        }
    }

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: variant.foregroundColor(for: colorScheme)))
                } else {
                    Text(title)
                        .font(.nunitoSans(size: 17, weight: .semiBold))
                }
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: 50)
            .padding(.horizontal, 24)
            .background(variant.backgroundColor(for: colorScheme))
            .foregroundColor(variant.foregroundColor(for: colorScheme))
            .cornerRadius(12)
        }
        .disabled(isLoading)
    }
}

#Preview {
    VStack(spacing: 16) {
        PhlockButton(title: "Primary Button", action: {}, variant: .primary)
        PhlockButton(title: "Secondary Button", action: {}, variant: .secondary)
        PhlockButton(title: "Continue with Spotify", action: {}, variant: .spotify, fullWidth: true)
        PhlockButton(title: "Continue with Apple Music", action: {}, variant: .appleMusic, fullWidth: true)
        PhlockButton(title: "Loading...", action: {}, isLoading: true)
    }
    .padding()
}
