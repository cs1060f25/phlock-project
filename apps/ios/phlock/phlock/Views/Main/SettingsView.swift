import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    // TODO: Replace with actual URLs
    private let privacyPolicyURL = URL(string: "https://phlock.app/privacy")!
    private let termsOfServiceURL = URL(string: "https://phlock.app/terms")!

    var body: some View {
        NavigationStack {
            List {
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
}
