import SwiftUI

struct OnboardingNameView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme

    @State private var name = ""
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isButtonPressed = false

    @FocusState private var isNameFocused: Bool

    // Validation: 1-30 chars, letters/spaces/hyphens/apostrophes only
    private var isValidName: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 1 && trimmed.count <= 30 else { return false }

        // Allow letters (including unicode), spaces, hyphens, apostrophes
        let allowedCharacters = CharacterSet.letters
            .union(CharacterSet(charactersIn: " -'"))
        return trimmed.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
    }

    private var canSubmit: Bool {
        isValidName && !isSubmitting
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with logo
            HStack(spacing: 8) {
                Image("PhlockLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)

                Text("phlock")
                    .font(.lora(size: 24, weight: .bold))
                    .foregroundColor(.primary)
            }
            .padding(.top, 60)

            // Title
            Text("what's your name?")
                .font(.lora(size: 28, weight: .bold))
                .foregroundColor(.primary)
                .padding(.top, 40)

            // Name input field
            VStack(spacing: 16) {
                TextField("", text: $name)
                    .font(.lora(size: 32, weight: .semiBold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($isNameFocused)
                    .submitLabel(.continue)
                    .onSubmit {
                        if canSubmit {
                            Task {
                                await submitName()
                            }
                        }
                    }

                // Helper text
                Text("what your friends call you")
                    .font(.lora(size: 16))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 60)
            .padding(.horizontal, 32)

            Spacer()

            // Continue Button - using gesture for reliable keyboard-visible taps with press feedback
            Group {
                if isSubmitting {
                    ProgressView()
                        .tint(Color.background(for: colorScheme))
                } else {
                    Text("continue")
                        .font(.lora(size: 17, weight: .semiBold))
                }
            }
            .foregroundColor(Color.background(for: colorScheme))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(canSubmit ? Color.primaryColor(for: colorScheme) : Color.gray.opacity(0.3))
            .cornerRadius(16)
            .scaleEffect(isButtonPressed ? 0.97 : 1.0)
            .opacity(canSubmit ? (isButtonPressed ? 0.8 : 1.0) : 0.6)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard canSubmit else { return }
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isButtonPressed = true
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isButtonPressed = false
                        }
                        guard canSubmit else { return }
                        isNameFocused = false
                        Task {
                            await submitName()
                        }
                    }
            )
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .background(Color.appBackground)
        .onAppear {
            // Auto-focus the text field to bring up keyboard
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isNameFocused = true
            }
        }
        .alert("error", isPresented: $showError) {
            Button("ok") { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Submit

    private func submitName() async {
        isSubmitting = true

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            // Save the display name
            try await AuthServiceV3.shared.setDisplayName(trimmedName)

            // Fetch updated user
            let updatedUser = try await AuthServiceV3.shared.currentUser

            await MainActor.run {
                authState.currentUser = updatedUser
                authState.needsNameSetup = false
                authState.needsUsernameSetup = true
                print("✅ Name set - transitioning to username selection")
            }

        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }

        await MainActor.run {
            isSubmitting = false
        }
    }
}

#Preview {
    OnboardingNameView()
        .environmentObject(AuthenticationState())
}
