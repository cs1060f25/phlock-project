import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var currentUser: User?
    @State private var isLoadingUser = true
    @State private var isPrivate = false
    @State private var isUpdatingPrivacy = false

    // Legal URLs - these must be hosted before TestFlight submission
    private let privacyPolicyURL = URL(string: "https://phlock.app/privacy")!
    private let termsOfServiceURL = URL(string: "https://phlock.app/terms")!

    // App version string
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                // Music Platform Section
                Section {
                    if isLoadingUser {
                        HStack {
                            Text("Loading...")
                                .font(.lora(size: 16))
                                .foregroundColor(.secondary)
                            Spacer()
                            ProgressView()
                        }
                    } else if let platform = currentUser?.resolvedPlatformType {
                        // Connected platform
                        HStack {
                            Image(platform == .spotify ? "SpotifyLogo" : "AppleMusicLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)

                            Text(platform == .spotify ? "Spotify" : "Apple Music")
                                .font(.lora(size: 16))

                            Spacer()

                            Text("Connected")
                                .font(.lora(size: 14))
                                .foregroundColor(.green)
                        }
                    } else {
                        // Fallback for users who somehow have no platform
                        Text("No music service connected")
                            .font(.lora(size: 16))
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Music Platform")
                        .font(.lora(size: 12))
                }

                // Privacy Section
                Section {
                    Toggle(isOn: $isPrivate) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Private Account")
                                .font(.lora(size: 16))
                            Text("Only approved followers can see your profile")
                                .font(.lora(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(isUpdatingPrivacy || isLoadingUser)
                    .onChange(of: isPrivate) { newValue in
                        Task {
                            await updatePrivacySetting(newValue)
                        }
                    }
                } header: {
                    Text("Privacy")
                        .font(.lora(size: 12))
                } footer: {
                    Text("When your account is private, people must send a follow request to see your songs and profile.")
                        .font(.lora(size: 12))
                }

                Section {
                    Link(destination: privacyPolicyURL) {
                        HStack {
                            Text("Privacy Policy")
                                .font(.lora(size: 16))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.lora(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }

                    Link(destination: termsOfServiceURL) {
                        HStack {
                            Text("Terms of Service")
                                .font(.lora(size: 16))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.lora(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Legal")
                        .font(.lora(size: 12))
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Text("Delete Account")
                            .font(.lora(size: 16))
                    }
                } header: {
                    Text("Account")
                        .font(.lora(size: 12))
                } footer: {
                    Text("Deleting your account is permanent and cannot be undone. All your data will be removed.")
                        .font(.lora(size: 12))
                }
                
                Section {
                    Button {
                        Task {
                            await authState.signOut()
                        }
                    } label: {
                        Text("Sign Out")
                            .font(.lora(size: 16))
                            .foregroundColor(.red)
                    }
                }

                Section {
                    HStack {
                        Text("Version")
                            .font(.lora(size: 16))
                        Spacer()
                        Text(appVersion)
                            .font(.lora(size: 16))
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                        .font(.lora(size: 12))
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.lora(size: 16, weight: .medium))
                }
            }
            .alert("Delete Account?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone.")
            }
            .overlay {
                if isDeleting {
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea()
                        ProgressView("Deleting...")
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                    }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )) {
                Button("OK") { }
            } message: {
                if let error = deleteError {
                    Text(error)
                }
            }
            .task {
                await loadCurrentUser()
            }
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await AuthServiceV2.shared.deleteAccount()
            await authState.signOut()
        } catch {
            deleteError = error.localizedDescription
        }
    }

    private func loadCurrentUser() async {
        isLoadingUser = true
        defer { isLoadingUser = false }

        do {
            currentUser = try await AuthServiceV3.shared.currentUser
            // Initialize the toggle state from the user's current setting
            if let user = currentUser {
                isPrivate = user.isPrivate
            }
        } catch {
            print("⚠️ Failed to load current user: \(error)")
        }
    }

    private func updatePrivacySetting(_ newValue: Bool) async {
        // Skip if we're still loading the initial value
        guard !isLoadingUser else { return }

        // Skip if the value hasn't actually changed from the user's setting
        guard currentUser?.isPrivate != newValue else { return }

        isUpdatingPrivacy = true
        defer { isUpdatingPrivacy = false }

        do {
            try await AuthServiceV3.shared.setPrivateProfile(newValue)
            // Refresh user to get updated value
            currentUser = try await AuthServiceV3.shared.currentUser
        } catch {
            // Revert toggle on error
            isPrivate = !newValue
            deleteError = error.localizedDescription
        }
    }
}
