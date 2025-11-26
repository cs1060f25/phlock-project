import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.dismiss) var dismiss
    @FocusState private var focusedField: Field?

    @State private var displayName = ""
    @State private var bio = ""
    @State private var profileImage: Image?
    @State private var profileImageData: Data?
    @State private var isUploading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showImagePicker = false

    enum Field: Hashable {
        case displayName
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
            .navigationTitle("Edit Profile")
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
                    bio = user.bio ?? ""
                }
            }
        }
        .dismissKeyboardOnTouch()
        .keyboardResponsive()
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
                } else {
                    print("⚠️ User cancelled crop")
                }
                picker.dismiss(animated: false) {
                    self.parent.dismiss()
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

    init(image: UIImage, completion: @escaping (UIImage?) -> Void) {
        self.originalImage = image
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        // This initializer is required by UIViewController but not used in SwiftUI
        // Return nil instead of crashing
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
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(scrollView)

        imageView = UIImageView(image: originalImage)
        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)

        // Set image view frame
        let imageSize = originalImage.size
        let screenWidth = view.bounds.width
        let scale = screenWidth / imageSize.width
        let scaledHeight = imageSize.height * scale

        imageView.frame = CGRect(x: 0, y: (view.bounds.height - scaledHeight) / 2,
                                width: screenWidth, height: scaledHeight)
        scrollView.contentSize = imageView.frame.size
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
        completion(nil)
    }

    @objc private func chooseTapped() {
        print("🎯 Choose tapped - starting crop")
        let croppedImage = cropToCircle()
        if let croppedImage = croppedImage {
            print("✅ Crop successful - image size: \(croppedImage.size)")
        } else {
            print("❌ Crop failed - no image returned")
        }
        completion(croppedImage)
    }

    private func cropToCircle() -> UIImage? {
        let cropSize: CGFloat = min(view.bounds.width, view.bounds.height) - 80
        let circleRect = CGRect(
            x: (view.bounds.width - cropSize) / 2,
            y: (view.bounds.height - cropSize) / 2,
            width: cropSize,
            height: cropSize
        )

        print("📏 Rendering crop - circle rect in view: \(circleRect)")
        print("📏 ScrollView zoom: \(scrollView.zoomScale)")
        print("📏 ScrollView bounds: \(scrollView.bounds)")
        print("📏 ImageView frame: \(imageView.frame)")

        // Find where the circle rect intersects with scrollView in the view's coordinate space
        let scrollViewFrameInView = scrollView.frame
        print("📏 ScrollView frame in view: \(scrollViewFrameInView)")

        // Calculate the intersection between circle and scrollView
        let circleInViewCoords = circleRect
        let scrollViewInViewCoords = scrollViewFrameInView

        // The circle rect relative to the scrollView's origin
        let circleRelativeToScrollView = CGRect(
            x: circleInViewCoords.origin.x - scrollViewInViewCoords.origin.x,
            y: circleInViewCoords.origin.y - scrollViewInViewCoords.origin.y,
            width: circleInViewCoords.width,
            height: circleInViewCoords.height
        )

        print("📏 Circle relative to scrollView bounds: \(circleRelativeToScrollView)")

        // Take a snapshot of ONLY the scrollView (not the overlay)
        let renderer = UIGraphicsImageRenderer(bounds: scrollView.bounds)
        let scrollViewSnapshot = renderer.image { context in
            scrollView.drawHierarchy(in: scrollView.bounds, afterScreenUpdates: false)
        }

        print("📏 ScrollView snapshot size: \(scrollViewSnapshot.size)")

        // Crop to the circle area (accounting for scale)
        let scale = scrollViewSnapshot.scale
        let cropRectInPixels = CGRect(
            x: circleRelativeToScrollView.origin.x * scale,
            y: circleRelativeToScrollView.origin.y * scale,
            width: circleRelativeToScrollView.width * scale,
            height: circleRelativeToScrollView.height * scale
        )

        print("📏 Crop rect in pixels: \(cropRectInPixels)")
        print("📏 Snapshot pixel size: \(scrollViewSnapshot.size.width * scale) x \(scrollViewSnapshot.size.height * scale)")

        guard let cgImage = scrollViewSnapshot.cgImage?.cropping(to: cropRectInPixels) else {
            print("❌ Failed to crop snapshot")
            return nil
        }

        let croppedImage = UIImage(cgImage: cgImage, scale: scale, orientation: .up)
        print("✂️ Cropped image size: \(croppedImage.size)")

        // Apply circular mask
        let circularImage = croppedImage.circularMask()
        print("⭕ Final circular image: \(circularImage.size)")

        return circularImage
    }
}

extension CircularCropViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
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

// MARK: - UIImage Extension for Circular Crop

extension UIImage {
    func circularMask() -> UIImage {
        print("🔵 Applying circular mask to image: \(size), scale: \(scale)")

        let minDimension = min(size.width, size.height)
        let squareSize = CGSize(width: minDimension, height: minDimension)

        // Calculate crop rect to make it square centered (in points)
        let cropRectInPoints = CGRect(
            x: (size.width - minDimension) / 2,
            y: (size.height - minDimension) / 2,
            width: minDimension,
            height: minDimension
        )

        // Convert to pixels for cgImage cropping
        let cropRectInPixels = CGRect(
            x: cropRectInPoints.origin.x * scale,
            y: cropRectInPoints.origin.y * scale,
            width: cropRectInPoints.width * scale,
            height: cropRectInPoints.height * scale
        )

        print("🔵 Square crop rect (points): \(cropRectInPoints)")
        print("🔵 Square crop rect (pixels): \(cropRectInPixels)")

        // Crop to square first
        guard let cgImage = self.cgImage?.cropping(to: cropRectInPixels) else {
            print("❌ Failed to crop to square in circularMask")
            return self
        }
        let squareImage = UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)

        print("🔵 Square image size: \(squareImage.size)")

        // Create circular mask
        let renderer = UIGraphicsImageRenderer(size: squareSize)
        let circularImage = renderer.image { context in
            // Create circular clipping path
            let circlePath = UIBezierPath(
                ovalIn: CGRect(origin: .zero, size: squareSize)
            )
            circlePath.addClip()

            // Draw the square image within the circular clip
            squareImage.draw(in: CGRect(origin: .zero, size: squareSize))
        }

        print("🔵 Final circular image size: \(circularImage.size)")
        return circularImage
    }
}

#Preview {
    EditProfileView()
        .environmentObject(AuthenticationState())
}
