import SwiftUI

struct PhlockButton: View {
    let title: String
    let action: () -> Void
    var variant: ButtonVariant = .primary
    var isLoading: Bool = false
    var fullWidth: Bool = false

    enum ButtonVariant {
        case primary
        case secondary
        case spotify
        case appleMusic

        var backgroundColor: Color {
            switch self {
            case .primary: return Color.black
            case .secondary: return Color.gray.opacity(0.2)
            case .spotify: return Color(red: 0.11, green: 0.73, blue: 0.33) // Spotify green
            case .appleMusic: return Color(red: 0.98, green: 0.26, blue: 0.42) // Apple Music red
            }
        }

        var foregroundColor: Color {
            switch self {
            case .primary, .spotify, .appleMusic: return .white
            case .secondary: return .black
            }
        }
    }

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: variant.foregroundColor))
                } else {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: 50)
            .padding(.horizontal, 24)
            .background(variant.backgroundColor)
            .foregroundColor(variant.foregroundColor)
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
