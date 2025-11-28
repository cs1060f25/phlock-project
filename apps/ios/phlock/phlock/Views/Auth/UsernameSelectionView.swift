import SwiftUI

struct UsernameSelectionView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme

    @State private var showSignOutConfirmation = false
    @State private var displayName = ""
    @State private var username = ""
    @State private var isChecking = false
    @State private var isAvailable: Bool?
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""

    @FocusState private var isDisplayNameFocused: Bool
    @FocusState private var isUsernameFocused: Bool

    private var isValidFormat: Bool {
        let u = username.lowercased()

        // Basic character set: lowercase letters, numbers, underscores, periods
        let basicRegex = "^[a-z0-9_.]{3,20}$"
        guard u.range(of: basicRegex, options: .regularExpression) != nil else {
            return false
        }

        // Cannot start or end with a period (underscores OK)
        if u.hasPrefix(".") || u.hasSuffix(".") {
            return false
        }

        // Cannot have consecutive periods (consecutive underscores OK)
        if u.contains("..") {
            return false
        }

        // Must contain at least one letter (blocks only numbers, periods, underscores)
        if !u.contains(where: { $0.isLetter }) {
            return false
        }

        return true
    }

    /// Returns a specific error message for the first validation rule that fails, or nil if valid
    private var validationErrorMessage: String? {
        let u = username.lowercased()

        if u.isEmpty {
            return nil
        }

        if u.count < 3 {
            return "Username must be at least 3 characters"
        }

        if u.count > 20 {
            return "Username must be 20 characters or less"
        }

        // Check for invalid characters
        let validChars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_.")
        if u.unicodeScalars.contains(where: { !validChars.contains($0) }) {
            return "Only letters, numbers, underscores, and periods allowed"
        }

        if u.hasPrefix(".") {
            return "Username can't start with a period"
        }

        if u.hasSuffix(".") {
            return "Username can't end with a period"
        }

        if u.contains("..") {
            return "Username can't have consecutive periods"
        }

        if !u.contains(where: { $0.isLetter }) {
            return "Username must include at least one letter"
        }

        return nil
    }

    private var isDisplayNameValid: Bool {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 1 && trimmed.count <= 50
    }

    private var canSubmit: Bool {
        isDisplayNameValid && isValidFormat && isAvailable == true && !isSubmitting
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Text("set up your profile")
                    .font(.lora(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("choose a name and username")
                    .font(.lora(size: 16))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 60)
            .padding(.bottom, 32)

            // Display Name Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.lora(size: 14, weight: .medium))
                    .foregroundColor(.secondary)

                TextField("Your name", text: $displayName)
                    .font(.lora(size: 18))
                    .focused($isDisplayNameFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .secondarySystemBackground))
                    )
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)

            // Username Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Username")
                    .font(.lora(size: 14, weight: .medium))
                    .foregroundColor(.secondary)

                HStack {
                    Text("@")
                        .font(.lora(size: 18, weight: .medium))
                        .foregroundColor(.secondary)

                    TextField("username", text: $username)
                        .font(.lora(size: 18))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isUsernameFocused)
                        .onChange(of: username) { newValue in
                            // Normalize to lowercase and remove invalid characters
                            let normalized = newValue.lowercased().filter { char in
                                char.isLetter || char.isNumber || char == "_" || char == "."
                            }
                            if normalized != newValue {
                                username = normalized
                            }

                            // Check availability after a short delay
                            isAvailable = nil
                            checkAvailability()
                        }

                    if isChecking {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if let available = isAvailable {
                        Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(available ? .green : .red)
                            .font(.system(size: 20))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(uiColor: .secondarySystemBackground))
                )

                // Validation message
                if !username.isEmpty {
                    if let errorMessage = validationErrorMessage {
                        Text(errorMessage)
                            .font(.lora(size: 13))
                            .foregroundColor(.red)
                    } else if let available = isAvailable {
                        Text(available ? "Username is available!" : "Username is already taken")
                            .font(.lora(size: 13))
                            .foregroundColor(available ? .green : .red)
                    }
                }
            }
            .padding(.horizontal, 32)

            // Guidelines
            VStack(alignment: .leading, spacing: 8) {
                Text("Username guidelines:")
                    .font(.lora(size: 14, weight: .semiBold))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    GuidelineRow(
                        text: "3-20 characters",
                        isMet: username.isEmpty ? nil : (username.count >= 3 && username.count <= 20)
                    )
                    GuidelineRow(
                        text: "Letters, numbers, underscores, periods",
                        isMet: username.isEmpty ? nil : isValidFormat
                    )
                    GuidelineRow(
                        text: "Must include at least one letter",
                        isMet: username.isEmpty ? nil : username.contains(where: { $0.isLetter })
                    )
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)

            Spacer()

            // Continue Button
            Button {
                Task {
                    await submitUsername()
                }
            } label: {
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
            .background(canSubmit ? Color.primaryColor(for: colorScheme) : Color.gray)
            .cornerRadius(16)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .disabled(!canSubmit)
        }
        .onAppear {
            isDisplayNameFocused = true
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Sign Out?", isPresented: $showSignOutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    try? await AuthServiceV3.shared.signOut()
                    await MainActor.run {
                        authState.isAuthenticated = false
                        authState.needsUsernameSetup = false
                    }
                }
            }
        } message: {
            Text("You'll need to sign in again to continue.")
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showSignOutConfirmation = true
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
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
            try await AuthServiceV3.shared.setUsernameAndDisplayName(
                username: username,
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            // Fetch updated user
            let updatedUser = try await AuthServiceV3.shared.currentUser

            await MainActor.run {
                authState.currentUser = updatedUser
                authState.needsUsernameSetup = false
                authState.needsMusicPlatform = true
                print("✅ Username set - transitioning to music platform selection")
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

// MARK: - Guideline Row

struct GuidelineRow: View {
    let text: String
    let isMet: Bool?  // nil = neutral (not yet evaluated), true = met, false = not met

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 14))
                .foregroundColor(iconColor)

            Text(text)
                .font(.lora(size: 13))
                .foregroundColor(.secondary)
        }
    }

    private var iconName: String {
        switch isMet {
        case .none:
            return "circle"  // Neutral - empty circle
        case .some(true):
            return "checkmark.circle.fill"  // Met - green check
        case .some(false):
            return "xmark.circle.fill"  // Not met - red x
        }
    }

    private var iconColor: Color {
        switch isMet {
        case .none:
            return .gray  // Neutral
        case .some(true):
            return .green  // Met
        case .some(false):
            return .red  // Not met
        }
    }
}

#Preview {
    NavigationStack {
        UsernameSelectionView()
            .environmentObject(AuthenticationState())
    }
}
