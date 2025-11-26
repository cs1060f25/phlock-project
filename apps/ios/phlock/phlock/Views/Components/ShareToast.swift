import SwiftUI

/// Toast notification for share success/error feedback
struct ShareToast: View {
    let message: String
    let type: ToastType
    let onUndo: (() -> Void)?

    @Environment(\.colorScheme) var colorScheme

    enum ToastType {
        case success
        case error
        case info

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            case .info: return .blue
            }
        }
    }

    var body: some View {
        let background: Color = {
            if colorScheme == .dark {
                return Color(.tertiarySystemBackground).opacity(0.95)
            } else {
                return Color(.systemBackground).opacity(0.95)
            }
        }()

        let textColor: Color = {
            if colorScheme == .dark {
                return .white
            } else {
                return .black
            }
        }()

        HStack(spacing: 12) {
            // Icon
            Image(systemName: type.icon)
                .font(.dmSans(size: 20, weight: .semiBold))
                .foregroundColor(type.color)

            // Message
            Text(message)
                .font(.dmSans(size: 10))
                .foregroundColor(textColor)

            Spacer()

            // Undo button (if provided)
            if let onUndo = onUndo {
                Button("undo") {
                    onUndo()
                }
                .font(.dmSans(size: 10))
                .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(background)
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 16)
    }
}

/// View modifier to show a toast notification
struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let type: ShareToast.ToastType
    let duration: TimeInterval
    let onUndo: (() -> Void)?

    func body(content: Content) -> some View {
        ZStack {
            content

            if isPresented {
                ShareToast(message: message, type: type, onUndo: onUndo)
                    .frame(maxWidth: 360)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
                    .onAppear {
                        // Auto-dismiss after duration
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPresented = false
                            }
                        }
                    }
                    .zIndex(999)
        }
    }
}
}

extension View {
    /// Show a toast notification
    /// - Parameters:
    ///   - isPresented: Binding to control toast visibility
    ///   - message: Message to display
    ///   - type: Toast type (success, error, info)
    ///   - duration: How long to show toast (default: 3 seconds)
    ///   - onUndo: Optional undo action
    func toast(
        isPresented: Binding<Bool>,
        message: String,
        type: ShareToast.ToastType = .success,
        duration: TimeInterval = 3.0,
        onUndo: (() -> Void)? = nil
    ) -> some View {
        self.modifier(
            ToastModifier(
                isPresented: isPresented,
                message: message,
                type: type,
                duration: duration,
                onUndo: onUndo
            )
        )
    }
}

/// Confetti animation view for celebrations
struct ConfettiView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<20, id: \.self) { index in
                ConfettiPiece(delay: Double(index) * 0.05)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .onAppear {
            animate = true
        }
    }
}

struct ConfettiPiece: View {
    let delay: Double

    @State private var yOffset: CGFloat = -50
    @State private var xOffset: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1

    private let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
    private let color: Color
    private let size: CGFloat

    init(delay: Double) {
        self.delay = delay
        self.color = colors.randomElement() ?? .blue
        self.size = CGFloat.random(in: 6...12)
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .offset(x: xOffset, y: yOffset)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 1.5)
                    .delay(delay)
                ) {
                    yOffset = UIScreen.main.bounds.height + 100
                    xOffset = CGFloat.random(in: -150...150)
                    rotation = Double.random(in: 0...720)
                    opacity = 0
                }
            }
    }
}

/// View modifier to show confetti animation
struct ConfettiModifier: ViewModifier {
    @Binding var trigger: Bool

    func body(content: Content) -> some View {
        ZStack {
            content

            if trigger {
                ConfettiView()
                    .transition(.opacity)
                    .onAppear {
                        // Auto-remove after animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            trigger = false
                        }
                    }
            }
        }
    }
}

extension View {
    /// Show confetti animation
    /// - Parameter trigger: Binding that triggers the animation when set to true
    func confetti(trigger: Binding<Bool>) -> some View {
        self.modifier(ConfettiModifier(trigger: trigger))
    }
}

#Preview("Success Toast") {
    VStack {
        Spacer()
        ShareToast(
            message: "Sent to Sarah, Mike, Alex",
            type: .success,
            onUndo: {}
        )
        Spacer()
    }
    .background(Color.gray.opacity(0.2))
}

#Preview("Error Toast") {
    VStack {
        Spacer()
        ShareToast(
            message: "Failed to send share",
            type: .error,
            onUndo: nil
        )
        Spacer()
    }
    .background(Color.gray.opacity(0.2))
}

#Preview("Confetti") {
    ConfettiView()
        .background(Color.white)
}
