import SwiftUI
import Contacts

struct OnboardingContactsPermissionView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme

    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSettingsAlert = false
    @State private var isButtonPressed = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with logo centered and skip button
            ZStack {
                // Centered logo
                HStack(spacing: 8) {
                    Image("PhlockLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)

                    Text("phlock")
                        .font(.lora(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                }

                // Skip button on the right
                HStack {
                    Spacer()
                    Button("skip") {
                        skipContacts()
                    }
                    .font(.lora(size: 15))
                    .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)

            // Mock phone with iOS permission dialog
            ZStack {
                // Phone frame
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .frame(width: 280, height: 340)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )

                VStack(spacing: 0) {
                    // Contact avatars grid inside phone
                    mockContactsGrid()
                        .padding(.top, 16)

                    // Mock dialog card
                    VStack(spacing: 12) {
                        Text("How do you want to\nshare contacts?")
                            .font(.system(size: 17, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                            .padding(.top, 16)

                        VStack(spacing: 8) {
                            // Select contacts button (greyed out)
                            Text("Select contacts")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(10)

                            // Allow Full Access button (highlighted)
                            Text("Allow Full Access")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color.primaryColor(for: colorScheme))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.primaryColor(for: colorScheme).opacity(0.1))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.primaryColor(for: colorScheme).opacity(0.4), lineWidth: 1.5)
                                )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    .padding(.horizontal, 16)
                    .padding(.top, -20)

                    // Home indicator
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.3))
                        .frame(width: 100, height: 5)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                }
                .frame(width: 280)

                // Pointing hand emoji - positioned so fingertip points at end of "Allow Full Access"
                Text("👆")
                    .font(.system(size: 36))
                    .offset(x: 85, y: 95)
            }
            .padding(.top, 20)

            Spacer()

            // Title and description
            VStack(spacing: 16) {
                Text("see who's already here.")
                    .font(.lora(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text("some of your friends are already here. allow ")
                    .font(.lora(size: 16))
                    .foregroundColor(.secondary)
                + Text("full access")
                    .font(.lora(size: 16, weight: .semiBold))
                    .foregroundColor(Color.primaryColor(for: colorScheme))
                + Text(" to add them to your phlock.")
                    .font(.lora(size: 16))
                    .foregroundColor(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

            Spacer()

            // Continue button - using gesture for press feedback
            Group {
                if isLoading {
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
            .background(Color.primaryColor(for: colorScheme))
            .cornerRadius(16)
            .scaleEffect(isButtonPressed ? 0.97 : 1.0)
            .opacity(isButtonPressed ? 0.8 : 1.0)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isLoading else { return }
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isButtonPressed = true
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isButtonPressed = false
                        }
                        guard !isLoading else { return }
                        Task {
                            await requestContactsAccess()
                        }
                    }
            )
            .padding(.horizontal, 32)

            // Privacy note
            HStack(spacing: 6) {
                Text("your contact list remains private and 100% secure")
                    .font(.lora(size: 13))
                    .foregroundColor(.secondary)
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Color.appBackground)
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Contacts Access Required", isPresented: $showSettingsAlert) {
            Button("Skip", role: .cancel) {
                skipContacts()
            }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("To find friends on phlock, please enable Contacts access in Settings > Apps > phlock > Contacts > Full Access.")
        }
    }

    // MARK: - Mock Contacts Grid

    @ViewBuilder
    private func mockContactsGrid() -> some View {
        let colors: [Color] = [.orange, .green, .blue, .purple, .pink, .red, .teal, .indigo]
        let initials = ["JL", "GR", "MK", "AS", "HK", "CH", "DP", "SK", "FL", "AR"]

        LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: 6), count: 5), spacing: 6) {
            ForEach(0..<10) { index in
                Circle()
                    .fill(colors[index % colors.count].opacity(0.85))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(initials[index % initials.count])
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    )
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Actions

    private func requestContactsAccess() async {
        // Check current authorization status first
        let currentStatus = ContactsService.shared.authorizationStatus()

        // If previously denied, prompt user to go to Settings
        if currentStatus == .denied || currentStatus == .restricted {
            await MainActor.run {
                showSettingsAlert = true
            }
            return
        }

        isLoading = true

        do {
            let granted = try await ContactsService.shared.requestAccessIfNeeded()

            if granted {
                // Fetch contacts that match Phlock users
                let matches = try await ContactsService.shared.findPhlockUsersInContacts()

                // Get phone numbers of matched users to exclude from invite list
                let matchedPhones = Set(matches.compactMap { match -> String? in
                    guard let phone = match.user.phone else { return nil }
                    return ContactsService.normalizePhone(phone)
                })

                // Fetch all contacts for invite screen (excluding matches)
                let allContacts = try await ContactsService.shared.fetchAllContacts(excludingPhones: matchedPhones)

                await MainActor.run {
                    authState.onboardingContactMatches = matches
                    authState.onboardingAllContacts = allContacts

                    // Mark contacts step as completed
                    UserDefaults.standard.set(true, forKey: "hasCompletedContactsStep")

                    // Transition to next screen based on whether we found matches
                    authState.needsContactsPermission = false

                    if !matches.isEmpty {
                        authState.needsAddFriends = true
                    } else {
                        // No friends found, go directly to invite friends
                        authState.needsInviteFriends = true
                    }

                    print("✅ Contacts access granted - found \(matches.count) matches, \(allContacts.count) contacts to invite")
                }
            } else {
                // User denied during the prompt - show settings alert
                await MainActor.run {
                    showSettingsAlert = true
                }
            }
        } catch {
            await MainActor.run {
                // On error, allow them to continue
                skipContacts()
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }

    private func skipContacts() {
        UserDefaults.standard.set(true, forKey: "hasCompletedContactsStep")
        authState.needsContactsPermission = false
        authState.needsNotificationPermission = true
        print("⏭️ Contacts skipped - moving to notifications")
    }
}

#Preview {
    OnboardingContactsPermissionView()
        .environmentObject(AuthenticationState())
}
