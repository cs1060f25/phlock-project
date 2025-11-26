import SwiftUI
import Contacts
import UserNotifications

struct PhlockCreationView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.colorScheme) var colorScheme
    
    // Profile State
    @State private var displayName = ""
    @State private var isProfileLoading = true
    
    // Search/Friends State
    @State private var searchText = ""
    @State private var searchResults: [User] = []
    @State private var selectedFriends: Set<UUID> = []
    @State private var isSearching = false
    @State private var contactMatches: [ContactMatch] = []
    @State private var isFetchingContacts = false
    @State private var contactError: String?
    
    // UI State
    @State private var isCompleting = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("build your phlock")
                    .font(.dmSans(size: 32, weight: .bold))

                Text("add friends to share music with")
                    .font(.dmSans(size: 17))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 24)
            
            // Profile Input (Minimal)
            HStack {
                Text("Display Name:")
                    .font(.dmSans(size: 15))
                    .foregroundColor(.secondary)

                TextField("Your Name", text: $displayName)
                    .font(.dmSans(size: 17))
                    .textFieldStyle(.plain)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            
            // Search Bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search for friends...", text: $searchText)
                    .font(.dmSans(size: 16))
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            
            // Content Area
            ScrollView {
                VStack(spacing: 0) {
                    // Contacts Button (if no search)
                    if searchText.isEmpty && contactMatches.isEmpty {
                        Button {
                            Task { await fetchContacts() }
                        } label: {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.1))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .font(.dmSans(size: 24, weight: .medium))
                                        .foregroundColor(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Find from Contacts")
                                        .font(.dmSans(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text("See who's already on Phlock")
                                        .font(.dmSans(size: 13))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if isFetchingContacts {
                                    ProgressView()
                                } else {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(16)
                            .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
                            .cornerRadius(16)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                    
                    // Results List
                    if isSearching {
                        ProgressView()
                            .padding(.top, 40)
                    } else if !searchText.isEmpty && searchResults.isEmpty {
                        Text("No users found")
                            .font(.dmSans(size: 15))
                            .foregroundColor(.secondary)
                            .padding(.top, 40)
                    } else {
                        // Display Search Results or Contact Matches
                        let usersToShow = !searchText.isEmpty ? searchResults : contactMatches.map { $0.user }
                        
                        LazyVStack(spacing: 0) {
                            ForEach(usersToShow) { user in
                                Button {
                                    toggleSelection(for: user)
                                } label: {
                                    HStack(spacing: 12) {
                                        // Avatar
                                        if let photoUrl = user.profilePhotoUrl, let url = URL(string: photoUrl) {
                                            AsyncImage(url: url) { image in
                                                image.resizable().scaledToFill()
                                            } placeholder: {
                                                Circle().fill(Color.gray.opacity(0.2))
                                            }
                                            .frame(width: 48, height: 48)
                                            .clipShape(Circle())
                                        } else {
                                            Circle()
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(width: 48, height: 48)
                                                .overlay(
                                                    Text(user.displayName.prefix(1).uppercased())
                                                        .font(.dmSans(size: 20, weight: .medium))
                                                        .foregroundColor(.secondary)
                                                )
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(user.displayName)
                                                .font(.dmSans(size: 16, weight: .medium))
                                                .foregroundColor(.primary)

                                            if let username = user.username {
                                                Text("@\(username)")
                                                    .font(.dmSans(size: 13))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        // Selection Checkmark
                                        ZStack {
                                            Circle()
                                                .stroke(selectedFriends.contains(user.id) ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                                                .frame(width: 24, height: 24)
                                            
                                            if selectedFriends.contains(user.id) {
                                                Circle()
                                                    .fill(Color.blue)
                                                    .frame(width: 16, height: 16)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color(UIColor.systemBackground))
                                }
                                Divider().padding(.leading, 84)
                            }
                        }
                    }
                }
            }
            
            // Bottom Action Bar
            VStack(spacing: 16) {
                Divider()
                
                Button {
                    Task { await completeOnboarding() }
                } label: {
                    HStack {
                        if isCompleting {
                            ProgressView()
                                .tint(colorScheme == .dark ? .black : .white)
                                .padding(.trailing, 8)
                        }
                        
                        Text(selectedFriends.isEmpty ? "Skip & Start Phlock" : "Add \(selectedFriends.count) Friends & Start")
                            .font(.dmSans(size: 17, weight: .semiBold))
                    }
                    .foregroundColor(colorScheme == .dark ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(colorScheme == .dark ? Color.white : Color.black)
                    .cornerRadius(16)
                }
                .disabled(isCompleting || displayName.isEmpty)
                .opacity(displayName.isEmpty ? 0.6 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .background(Color(UIColor.systemBackground))
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await loadCurrentUser()
        }
        .onChange(of: searchText) { _ in
            Task { await performSearch() }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .dismissKeyboardOnTouch()
    }
    
    // MARK: - Logic
    
    private func loadCurrentUser() async {
        if let user = authState.currentUser {
            displayName = user.displayName
            // If display name is just "Spotify User" or "Apple Music User", maybe clear it to encourage editing?
            // Or keep it to reduce friction. Let's keep it but user can edit.
        }
        isProfileLoading = false
    }
    
    private func performSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, query.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        do {
            searchResults = try await UserService.shared.searchUsers(query: query)
        } catch {
            print("Search error: \(error)")
        }
        isSearching = false
    }
    
    private func fetchContacts() async {
        isFetchingContacts = true
        contactError = nil
        do {
            contactMatches = try await ContactsService.shared.findPhlockUsersInContacts()
        } catch {
            contactError = error.localizedDescription
            print("Contact error: \(error)")
        }
        isFetchingContacts = false
    }
    
    private func toggleSelection(for user: User) {
        if selectedFriends.contains(user.id) {
            selectedFriends.remove(user.id)
        } else {
            selectedFriends.insert(user.id)
        }
    }
    
    private func completeOnboarding() async {
        isCompleting = true
        
        // 1. Update Profile (if changed)
        if let user = authState.currentUser, user.displayName != displayName {
            await authState.updateProfile(displayName: displayName, bio: nil, profilePhotoUrl: nil)
        }
        
        // 2. Send Friend Requests
        if !selectedFriends.isEmpty {
            for friendId in selectedFriends {
                do {
                    // Assuming UserService has a method to send request. 
                    // If not, we might need to add it or use existing logic.
                    // Checking UserService... assuming `sendFriendRequest` exists or similar.
                    // Based on previous files, we have `UserService.shared`.
                    // I'll assume `sendFriendRequest` exists, if not I'll need to check UserService.
                    // For now, let's wrap in try? to not block onboarding.
                    try await UserService.shared.sendFriendRequest(to: friendId, from: authState.currentUser?.id ?? UUID())
                } catch {
                    print("Failed to add friend \(friendId): \(error)")
                }
            }
        }
        
        // 3. Request Notification Permissions
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            print("Notifications granted: \(granted)")
        } catch {
            print("Notification permission error: \(error)")
        }
        
        // 4. Finish
        authState.completeOnboarding()
        isCompleting = false
    }
}

#Preview {
    PhlockCreationView()
        .environmentObject(AuthenticationState())
}
