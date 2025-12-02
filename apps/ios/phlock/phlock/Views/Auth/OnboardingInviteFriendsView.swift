import SwiftUI
import MessageUI

struct OnboardingInviteFriendsView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme

    @State private var searchText = ""
    @State private var invitedContacts: Set<String> = [] // Track by phone number
    @State private var inviteTarget: InviteTarget?
    @State private var isButtonPressed = false

    // Wrapper for .sheet(item:) to avoid SwiftUI timing issues
    struct InviteTarget: Identifiable {
        let id = UUID()
        let phone: String
    }

    // Filter contacts based on search
    private var filteredContacts: [(name: String, phone: String)] {
        if searchText.isEmpty {
            return authState.onboardingAllContacts
        }
        return authState.onboardingAllContacts.filter { contact in
            contact.name.localizedCaseInsensitiveContains(searchText)
        }
    }

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
                        skipInvites()
                    }
                    .font(.lora(size: 15))
                    .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }

            // Title
            Text("invite friends\nto share music")
                .font(.lora(size: 28, weight: .bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.top, 24)
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }

            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("search friends", text: $searchText)
                    .font(.lora(size: 16))
                    .foregroundColor(.primary)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Contacts list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredContacts, id: \.phone) { contact in
                        InviteContactRow(
                            name: contact.name,
                            phone: contact.phone,
                            isInvited: invitedContacts.contains(contact.phone),
                            onInvite: {
                                inviteTarget = InviteTarget(phone: contact.phone)
                            }
                        )
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer()

            // Continue button - using gesture for press feedback
            Text("continue")
                .font(.lora(size: 17, weight: .semiBold))
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
                            withAnimation(.easeInOut(duration: 0.1)) {
                                isButtonPressed = true
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.easeInOut(duration: 0.1)) {
                                isButtonPressed = false
                            }
                            skipInvites()
                        }
                )
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
        }
        .background(Color.appBackground)
        .dismissKeyboardOnTouch()
        .sheet(item: $inviteTarget) { target in
            MessageComposeView(
                recipients: [target.phone],
                body: "hey cutie - I have a song for you https://phlock.app",
                onFinished: { result in
                    if result == .sent {
                        invitedContacts.insert(target.phone)
                    }
                    inviteTarget = nil
                }
            )
        }
    }

    // MARK: - Actions

    private func skipInvites() {
        authState.needsInviteFriends = false
        authState.needsNotificationPermission = true
        print("⏭️ Invites completed/skipped - moving to notifications")
    }
}

// MARK: - Invite Contact Row

struct InviteContactRow: View {
    @Environment(\.colorScheme) var colorScheme

    let name: String
    let phone: String
    let isInvited: Bool
    let onInvite: () -> Void

    // Generate consistent color for initials
    private var avatarColor: Color {
        let colors: [Color] = [.orange, .green, .blue, .purple, .pink, .red, .teal, .indigo]
        let index = abs(phone.hashValue) % colors.count
        return colors[index]
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        } else if let first = parts.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }

    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            Circle()
                .fill(avatarColor)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(initials)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                )

            // Name
            Text(name)
                .font(.lora(size: 17))
                .foregroundColor(.primary)

            Spacer()

            // Invite button
            Button {
                onInvite()
            } label: {
                Text(isInvited ? "invited" : "invite")
                    .font(.lora(size: 15, weight: .medium))
                    .foregroundColor(isInvited ? .secondary : Color.background(for: colorScheme))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(isInvited ? Color.secondary.opacity(0.2) : Color.primaryColor(for: colorScheme))
                    .cornerRadius(20)
            }
            .disabled(isInvited)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Message Compose View

struct MessageComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    let onFinished: (MessageComposeResult) -> Void

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = recipients
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinished: onFinished)
    }

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinished: (MessageComposeResult) -> Void

        init(onFinished: @escaping (MessageComposeResult) -> Void) {
            self.onFinished = onFinished
        }

        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true) {
                self.onFinished(result)
            }
        }
    }
}

#Preview {
    OnboardingInviteFriendsView()
        .environmentObject(AuthenticationState())
}
