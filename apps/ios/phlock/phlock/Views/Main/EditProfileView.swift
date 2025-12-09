import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct EditProfileView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.dismiss) var dismiss
    @FocusState private var focusedField: Field?

    @State private var displayName = ""
    @State private var username = ""
    @State private var bio = ""
    @State private var profileImage: Image?
    @State private var profileImageData: Data?
    @State private var isUploading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showImagePicker = false

    enum Field: Hashable {
        case displayName
        case username
        case bio
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Photo Picker with Crop
                    Button {
                        focusedField = nil
                        showImagePicker = true
                    } label: {
                        ZStack {
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
                                        .font(.lora(size: 32, weight: .bold))
                                        .foregroundColor(.gray)

                                    Text("add photo")
                                        .font(.lora(size: 10))
                                        .foregroundColor(.gray)
                                }
                            }

                            // Camera overlay for existing photos
                            if profileImage != nil || authState.currentUser?.profilePhotoUrl != nil {
                                Circle()
                                    .fill(Color.black.opacity(0.4))
                                    .frame(width: 120, height: 120)

                                Image(systemName: "camera.fill")
                                    .font(.lora(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .sheet(isPresented: $showImagePicker) {
                        ImagePicker(image: $profileImage, imageData: $profileImageData)
                    }
                    .padding(.top, 24)

                    // Form
                    VStack(spacing: 20) {
                        PhlockTextField(
                            label: "Display Name",
                            placeholder: "Your name",
                            text: $displayName
                        )
                        .focused($focusedField, equals: .displayName)

                        PhlockTextField(
                            label: "Username",
                            placeholder: "username",
                            text: $username
                        )
                        .focused($focusedField, equals: .username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                        PhlockTextField(
                            label: "Bio",
                            placeholder: "Tell friends about your music taste...",
                            text: $bio,
                            multiline: true
                        )
                        .focused($focusedField, equals: .bio)
                    }
                    .padding(.horizontal, 24)

                    // Save Button
                    PhlockButton(
                        title: "save changes",
                        action: { Task { await saveProfile() } },
                        variant: .primary,
                        isLoading: isUploading,
                        fullWidth: true
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .disabled(displayName.isEmpty)
                }
                .background(
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            focusedField = nil
                        }
                )
            }
            .navigationTitle("edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        focusedField = nil
                        dismiss()
                    }
                }

                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("done") {
                            focusedField = nil
                        }
                        .fontWeight(.semibold)
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
                    username = user.username ?? ""
                    bio = user.bio ?? ""
                }
            }
        }
        .dismissKeyboardOnTouch()
    }

    private func saveProfile() async {
        guard !displayName.isEmpty else { return }

        focusedField = nil
        isUploading = true

        // Determine the final photo URL
        var finalPhotoUrl: String?

        // Upload photo if a new one was selected
        if let imageData = profileImageData {
            print("📸 Uploading profile photo (\(imageData.count) bytes)...")
            let uploadedUrl = await authState.uploadProfilePhoto(imageData: imageData)

            if let uploadedUrl = uploadedUrl {
                print("✅ Photo uploaded successfully: \(uploadedUrl)")
                finalPhotoUrl = uploadedUrl
            } else {
                print("❌ Photo upload failed, keeping current photo")
                finalPhotoUrl = authState.currentUser?.profilePhotoUrl
            }
        } else {
            // No new photo selected, keep current
            finalPhotoUrl = authState.currentUser?.profilePhotoUrl
        }

        // Update profile with the final URL
        print("💾 Updating profile with photo URL: \(finalPhotoUrl ?? "nil")")
        await authState.updateProfile(
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            username: username.isEmpty ? nil : username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            bio: bio.isEmpty ? nil : bio.trimmingCharacters(in: .whitespacesAndNewlines),
            profilePhotoUrl: finalPhotoUrl
        )

        if let error = authState.error {
            print("❌ Profile update error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
            isUploading = false
        } else {
            print("✅ Profile updated successfully")
            print("✅ Final URL in database: \(authState.currentUser?.profilePhotoUrl ?? "nil")")
            isUploading = false
            dismiss()
        }
    }
}

// MARK: - Image Picker with Circular Crop

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: Image?
    @Binding var imageData: Data?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.mediaTypes = [UTType.image.identifier]  // Only show photos, no videos
        picker.allowsEditing = false  // We'll do custom circular crop
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            guard let selectedImage = info[.originalImage] as? UIImage else {
                print("❌ No original image found")
                parent.dismiss()
                return
            }

            print("📸 Got original image: \(selectedImage.size)")

            // Show custom circular crop view
            let cropVC = CircularCropViewController(image: selectedImage) { croppedImage in
                if let croppedImage = croppedImage {
                    print("✅ Setting cropped image: \(croppedImage.size)")
                    self.parent.image = Image(uiImage: croppedImage)

                    if let jpegData = croppedImage.jpegData(compressionQuality: 0.8) {
                        print("✅ Created JPEG data: \(jpegData.count) bytes")
                        self.parent.imageData = jpegData
                    } else {
                        print("❌ Failed to create JPEG data")
                    }
                    // Only dismiss picker after successful crop
                    picker.dismiss(animated: false) {
                        self.parent.dismiss()
                    }
                } else {
                    // User cancelled crop - just dismiss the crop VC, stay on photo picker
                    print("⚠️ User cancelled crop - returning to photo picker")
                }
            }
            picker.present(cropVC, animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Circular Crop View Controller

class CircularCropViewController: UIViewController {
    private let originalImage: UIImage
    private let completion: (UIImage?) -> Void

    private var imageView: UIImageView!
    private var overlayView: CircularCropOverlay!
    private var scrollView: UIScrollView!
    private var hasSetupInitialZoom = false
    private var cropSize: CGFloat = 0

    init(image: UIImage, completion: @escaping (UIImage?) -> Void) {
        self.originalImage = image
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupScrollView()
        setupOverlay()
        setupNavigationBar()
    }

    private func setupScrollView() {
        scrollView = UIScrollView(frame: view.bounds)
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.decelerationRate = .fast
        view.addSubview(scrollView)

        imageView = UIImageView(image: originalImage)
        imageView.contentMode = .scaleAspectFill
        scrollView.addSubview(imageView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        scrollView.frame = view.bounds
        overlayView?.frame = view.bounds
        overlayView?.setNeedsDisplay()

        // Only do initial setup once
        guard !hasSetupInitialZoom else { return }
        hasSetupInitialZoom = true

        // Calculate crop circle size (same as overlay)
        cropSize = min(view.bounds.width, view.bounds.height) - 80
        let cropRect = CGRect(
            x: (view.bounds.width - cropSize) / 2,
            y: (view.bounds.height - cropSize) / 2,
            width: cropSize,
            height: cropSize
        )

        let imageSize = originalImage.size

        // Calculate zoom so image fills the crop circle
        let widthScale = cropSize / imageSize.width
        let heightScale = cropSize / imageSize.height
        let minScale = max(widthScale, heightScale)

        // Set imageView frame at 1x scale initially
        imageView.frame = CGRect(origin: .zero, size: imageSize)
        scrollView.contentSize = imageSize

        scrollView.minimumZoomScale = minScale
        scrollView.maximumZoomScale = max(minScale * 5, 5.0)
        scrollView.zoomScale = minScale

        // Set insets so the image can be positioned anywhere within the crop circle
        let insetTop = cropRect.minY
        let insetLeft = cropRect.minX
        let insetBottom = view.bounds.height - cropRect.maxY
        let insetRight = view.bounds.width - cropRect.maxX

        scrollView.contentInset = UIEdgeInsets(top: insetTop, left: insetLeft, bottom: insetBottom, right: insetRight)

        // Center the image in the crop area (accounting for content insets)
        let scaledImageSize = CGSize(width: imageSize.width * minScale, height: imageSize.height * minScale)
        let offsetX = (scaledImageSize.width - cropSize) / 2 - scrollView.contentInset.left
        let offsetY = (scaledImageSize.height - cropSize) / 2 - scrollView.contentInset.top
        scrollView.contentOffset = CGPoint(x: offsetX, y: offsetY)
    }

    private func setupOverlay() {
        overlayView = CircularCropOverlay(frame: view.bounds)
        overlayView.isUserInteractionEnabled = false
        view.addSubview(overlayView)
    }

    private func setupNavigationBar() {
        let toolbar = UIView(frame: CGRect(x: 0, y: view.safeAreaInsets.top,
                                          width: view.bounds.width, height: 44))
        toolbar.backgroundColor = .clear

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17)
        cancelButton.frame = CGRect(x: 16, y: 0, width: 80, height: 44)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        toolbar.addSubview(cancelButton)

        let chooseButton = UIButton(type: .system)
        chooseButton.setTitle("Choose", for: .normal)
        chooseButton.setTitleColor(.systemBlue, for: .normal)
        chooseButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        chooseButton.frame = CGRect(x: view.bounds.width - 96, y: 0, width: 80, height: 44)
        chooseButton.addTarget(self, action: #selector(chooseTapped), for: .touchUpInside)
        toolbar.addSubview(chooseButton)

        view.addSubview(toolbar)
    }

    @objc private func cancelTapped() {
        dismiss(animated: true) {
            self.completion(nil)
        }
    }

    @objc private func chooseTapped() {
        let croppedImage = cropToCircle()
        completion(croppedImage)
    }

    private func cropToCircle() -> UIImage? {
        // Use screenshot approach - most reliable way to get exactly what's visible
        let cropRect = CGRect(
            x: (view.bounds.width - cropSize) / 2,
            y: (view.bounds.height - cropSize) / 2,
            width: cropSize,
            height: cropSize
        )

        // Hide overlay and take screenshot of just the scrollView
        overlayView.isHidden = true

        // Render the scrollView to an image
        let renderer = UIGraphicsImageRenderer(bounds: scrollView.bounds)
        let scrollViewImage = renderer.image { context in
            scrollView.drawHierarchy(in: scrollView.bounds, afterScreenUpdates: true)
        }

        overlayView.isHidden = false

        // The crop rect in scrollView coordinates is the same as view coordinates
        // since scrollView fills the entire view
        let scale = scrollViewImage.scale
        let pixelCropRect = CGRect(
            x: cropRect.origin.x * scale,
            y: cropRect.origin.y * scale,
            width: cropRect.width * scale,
            height: cropRect.height * scale
        )

        guard let cgImage = scrollViewImage.cgImage?.cropping(to: pixelCropRect) else {
            return nil
        }

        let croppedImage = UIImage(cgImage: cgImage, scale: scale, orientation: .up)

        // Apply circular mask
        let finalSize = CGSize(width: cropSize, height: cropSize)
        let circleRenderer = UIGraphicsImageRenderer(size: finalSize)
        return circleRenderer.image { context in
            let circlePath = UIBezierPath(ovalIn: CGRect(origin: .zero, size: finalSize))
            circlePath.addClip()
            croppedImage.draw(in: CGRect(origin: .zero, size: finalSize))
        }
    }
}

extension CircularCropViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // Center the image if it's smaller than the visible area
        let imageViewSize = imageView.frame.size
        let scrollViewSize = scrollView.bounds.size

        let verticalPadding = imageViewSize.height < scrollViewSize.height ?
            (scrollViewSize.height - imageViewSize.height) / 2 : 0
        let horizontalPadding = imageViewSize.width < scrollViewSize.width ?
            (scrollViewSize.width - imageViewSize.width) / 2 : 0

        // Adjust insets to keep crop circle centered
        let cropRect = CGRect(
            x: (view.bounds.width - cropSize) / 2,
            y: (view.bounds.height - cropSize) / 2,
            width: cropSize,
            height: cropSize
        )

        scrollView.contentInset = UIEdgeInsets(
            top: max(cropRect.minY, verticalPadding),
            left: max(cropRect.minX, horizontalPadding),
            bottom: max(view.bounds.height - cropRect.maxY, verticalPadding),
            right: max(view.bounds.width - cropRect.maxX, horizontalPadding)
        )
    }
}

// MARK: - Circular Crop Overlay

class CircularCropOverlay: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        // This initializer is required by UIViewController but not used in SwiftUI
        // Return nil instead of crashing
        return nil
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        // Semi-transparent overlay
        context.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
        context.fill(rect)

        // Clear circle in the center
        let cropSize: CGFloat = min(rect.width, rect.height) - 80
        let circleRect = CGRect(
            x: (rect.width - cropSize) / 2,
            y: (rect.height - cropSize) / 2,
            width: cropSize,
            height: cropSize
        )

        context.setBlendMode(.destinationOut)
        context.fillEllipse(in: circleRect)

        // Draw circle border
        context.setBlendMode(.normal)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2)
        context.strokeEllipse(in: circleRect)
    }
}

#Preview {
    EditProfileView()
        .environmentObject(AuthenticationState())
}
