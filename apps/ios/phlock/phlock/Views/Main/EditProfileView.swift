import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.dismiss) var dismiss

    @State private var displayName = ""
    @State private var bio = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var profileImageData: Data?
    @State private var isUploading = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Photo Picker
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        if let profileImage {
                            profileImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                        } else if let photoUrl = authState.currentUser?.profilePhotoUrl, let url = URL(string: photoUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                ProfilePhotoPlaceholder(displayName: displayName)
                            }
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                            .foregroundColor(.gray.opacity(0.3))
                                    )

                                VStack(spacing: 8) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.gray)

                                    Text("Add Photo")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .onChange(of: selectedPhoto) { oldValue, newValue in
                        Task {
                            if let data = try? await newValue?.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data) {
                                profileImage = Image(uiImage: uiImage)
                                profileImageData = data
                            }
                        }
                    }
                    .padding(.top, 24)

                    // Form
                    VStack(spacing: 20) {
                        PhlockTextField(
                            label: "Display Name",
                            placeholder: "Your name",
                            text: $displayName
                        )

                        PhlockTextField(
                            label: "Bio",
                            placeholder: "Tell friends about your music taste...",
                            text: $bio,
                            multiline: true
                        )
                    }
                    .padding(.horizontal, 24)

                    // Save Button
                    PhlockButton(
                        title: "Save Changes",
                        action: { Task { await saveProfile() } },
                        variant: .primary,
                        isLoading: isUploading,
                        fullWidth: true
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .disabled(displayName.isEmpty)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                if let user = authState.currentUser {
                    displayName = user.displayName
                    bio = user.bio ?? ""
                }
            }
        }
    }

    private func saveProfile() async {
        guard !displayName.isEmpty else { return }

        isUploading = true

        var photoUrl: String?

        // Upload photo if selected
        if let imageData = profileImageData {
            photoUrl = await authState.uploadProfilePhoto(imageData: imageData)
        }

        // Update profile
        await authState.updateProfile(
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            bio: bio.isEmpty ? nil : bio.trimmingCharacters(in: .whitespacesAndNewlines),
            profilePhotoUrl: photoUrl ?? authState.currentUser?.profilePhotoUrl
        )

        if let error = authState.error {
            errorMessage = error.localizedDescription
            showError = true
            isUploading = false
        } else {
            isUploading = false
            dismiss()
        }
    }
}

#Preview {
    EditProfileView()
        .environmentObject(AuthenticationState())
}
