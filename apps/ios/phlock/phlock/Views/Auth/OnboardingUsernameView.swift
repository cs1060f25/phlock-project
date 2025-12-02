import SwiftUI

struct OnboardingUsernameView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme

    @State private var username = ""
    @State private var isChecking = false
    @State private var isAvailable: Bool?
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isButtonPressed = false

    @FocusState private var isUsernameFocused: Bool

    private var isValidFormat: Bool {
        validationError == nil
    }

    /// Returns a specific error message if the username is invalid, or nil if valid
    private var validationError: String? {
        let u = username.lowercased()

        // Check minimum length
        if u.count < 3 {
            return "must be at least 3 characters"
        }

        // Check maximum length
        if u.count > 20 {
            return "must be 20 characters or less"
        }

        // Check for invalid characters
        let validChars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_.")
        if u.unicodeScalars.contains(where: { !validChars.contains($0) }) {
            return "only letters, numbers, _ and . allowed"
        }

        // Cannot start or end with a period
        if u.hasPrefix(".") {
            return "can't start with a period"
        }
        if u.hasSuffix(".") {
            return "can't end with a period"
        }

        // Cannot have consecutive periods
        if u.contains("..") {
            return "can't have consecutive periods"
        }

        // Must contain at least one letter
        if !u.contains(where: { $0.isLetter }) {
            return "must include at least one letter"
        }

        return nil
    }

    private var canSubmit: Bool {
        isValidFormat && isAvailable == true && !isSubmitting
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
            Text("create a username")
                .font(.lora(size: 28, weight: .bold))
                .foregroundColor(.primary)
                .padding(.top, 40)

            // Username input field
            VStack(spacing: 16) {
                HStack(spacing: 0) {
                    Spacer()
                    // @ symbol prefix
                    Text("@")
                        .font(.lora(size: 32, weight: .semiBold))
                        .foregroundColor(.secondary.opacity(0.5))

                    TextField("", text: $username)
                        .font(.lora(size: 32, weight: .semiBold))
                        .foregroundColor(.primary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isUsernameFocused)
                        .submitLabel(.continue)
                        .fixedSize(horizontal: true, vertical: false)
                        .onChange(of: username) { newValue in
                            // Normalize to lowercase and remove invalid characters
                            let normalized = newValue.lowercased().filter { char in
                                char.isLetter || char.isNumber || char == "_" || char == "."
                            }
                            if normalized != newValue {
                                username = normalized
                            }

                            // Reset availability and check again
                            isAvailable = nil
                            checkAvailability()
                        }
                        .onSubmit {
                            if canSubmit {
                                Task {
                                    await submitUsername()
                                }
                            }
                        }
                    Spacer()
                }

                // Status indicator
                if !username.isEmpty {
                    HStack(spacing: 8) {
                        if isChecking {
                            ProgressView()
                                .tint(.secondary)
                                .scaleEffect(0.8)
                        } else if let error = validationError {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.lora(size: 16))
                                .foregroundColor(.red)
                        } else if let available = isAvailable {
                            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(available ? .green : .red)
                            Text(available ? "available" : "not available")
                                .font(.lora(size: 16))
                                .foregroundColor(available ? .green : .red)
                        }
                    }
                } else {
                    // Helper text when empty
                    Text("you can change this later")
                        .font(.lora(size: 16))
                        .foregroundColor(.secondary)
                }
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
                        isUsernameFocused = false
                        Task {
                            await submitUsername()
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
                isUsernameFocused = true
            }
        }
        .alert("error", isPresented: $showError) {
            Button("ok") { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Check Availability

    @MainActor
    private func checkAvailability() {
        guard isValidFormat else {
            isAvailable = nil
            return
        }

        isChecking = true

        Task {
            // Debounce
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            do {
                let available = try await AuthServiceV3.shared.isUsernameAvailable(username)
                await MainActor.run {
                    isAvailable = available
                    isChecking = false
                }
            } catch {
                await MainActor.run {
                    isChecking = false
                }
            }
        }
    }

    // MARK: - Submit

    private func submitUsername() async {
        isSubmitting = true

        do {
            // Save the username
            try await AuthServiceV3.shared.setUsername(username)

            // Fetch updated user
            let updatedUser = try await AuthServiceV3.shared.currentUser

            await MainActor.run {
                authState.currentUser = updatedUser
                authState.needsUsernameSetup = false
                authState.needsContactsPermission = true
                print("✅ Username set - transitioning to contacts permission")
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
    OnboardingUsernameView()
        .environmentObject(AuthenticationState())
}
