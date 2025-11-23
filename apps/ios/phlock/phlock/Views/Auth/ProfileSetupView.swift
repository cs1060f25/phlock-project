import SwiftUI
import PhotosUI

struct ProfileSetupView: View {
    @EnvironmentObject var authState: AuthenticationState
    @State private var displayName = ""
    @State private var bio = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var profileImageData: Data?
    @State private var isUploading = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Text("set up your profile")
                        .font(.lora(size: 32, weight: .bold))

                    Text("let your friends know who you are")
                        .font(.lora(size: 17))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)

                // Photo Picker
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    if let profileImage {
                        profileImage
                            .resizable()
                            .scaledToFill()
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

                                Text("add photo")
                                    .font(.lora(size: 13, weight: .semiBold))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .onChange(of: selectedPhoto) { newValue in
                    Task {
                        if let data = try? await newValue?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            profileImage = Image(uiImage: uiImage)
                            profileImageData = data
                        }
                    }
                }

                // Form
                VStack(spacing: 20) {
                    PhlockTextField(
                        label: "Display Name",
                        placeholder: "Your name",
                        text: $displayName
                    )

                    PhlockTextField(
                        label: "Bio (Optional)",
                        placeholder: "Tell friends about your music taste...",
                        text: $bio,
                        multiline: true
                    )
                }
                .padding(.horizontal, 24)

                // Complete Button
                PhlockButton(
                    title: "Complete Setup",
                    action: { Task { await completeSetup() } },
                    variant: .primary,
                    isLoading: isUploading,
                    fullWidth: true
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .disabled(displayName.isEmpty)
            }
        }
        .navigationBarBackButtonHidden(true)
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .dismissKeyboardOnTouch()
        .keyboardResponsive()
    }

    private func completeSetup() async {
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
            profilePhotoUrl: photoUrl
        )

        if let error = authState.error {
            errorMessage = error.localizedDescription
            showError = true
            isUploading = false
        }

        // Navigation is handled automatically by AuthenticationState change
    }
}

#Preview {
    NavigationStack {
        ProfileSetupView()
            .environmentObject(AuthenticationState())
    }
}
