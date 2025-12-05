//
//  ContentView.swift
//  phlock
//
//  Created by Woon Lee on 10/24/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authState: AuthenticationState
    @State private var showSplashScreen = true
    @State private var splashScreenComplete = false
    @State private var canDismissSplash = false
    @State private var isInitialLaunch = true // Track if this is the first app launch
    @AppStorage("selectedTab") private var selectedTab = 0

    var body: some View {
        ZStack {
            // Main content
            if authState.isAuthenticated {
                if authState.needsNameSetup {
                    // Step 1: Name entry
                    NavigationStack {
                        OnboardingNameView()
                    }
                } else if authState.needsUsernameSetup {
                    // Step 2: Username selection
                    NavigationStack {
                        OnboardingUsernameView()
                    }
                } else if authState.needsContactsPermission {
                    // Step 3: Contacts permission
                    NavigationStack {
                        OnboardingContactsPermissionView()
                    }
                } else if authState.needsAddFriends {
                    // Step 4: Add friends from contacts (if any found)
                    NavigationStack {
                        OnboardingAddFriendsView()
                    }
                } else if authState.needsInviteFriends {
                    // Step 5: Invite friends not on app
                    NavigationStack {
                        OnboardingInviteFriendsView()
                    }
                } else if authState.needsNotificationPermission {
                    // Step 6: Notification permission
                    NavigationStack {
                        OnboardingNotificationsView()
                    }
                } else if authState.needsMusicPlatform {
                    // Step 7: Music platform connection
                    NavigationStack {
                        MusicPlatformConnectionView()
                    }
                } else {
                    // Fully onboarded - show main app
                    MainView()
                }
            } else if !showSplashScreen {
                // Not authenticated and splash is done - show welcome screen
                WelcomeView()
            } else {
                // While splash is showing, render background
                Color.appBackground
                    .ignoresSafeArea()
            }

            // Splash screen overlay - only shows on initial app launch
            // We show it while loading, then ContentView logic decides whether to keep it (authenticated) or remove it (unauthenticated)
            if showSplashScreen && isInitialLaunch {
                SplashScreenView(onComplete: {
                    // Called when splash animation completes (dots appeared)
                    // If authenticated: fades to MainView (phlocks tab)
                    // If not authenticated: transitions to WelcomeView with rotating logo
                    print("✅ Splash screen animation completed, transitioning to next screen")
                    splashScreenComplete = true
                    canDismissSplash = true

                    // If user is authenticated, ensure we land on phlocks tab
                    if authState.isAuthenticated {
                        selectedTab = 0 // Reset to phlocks tab
                        print("✅ User authenticated - setting tab to phlocks (0)")

                        // Dismiss splash with fade for authenticated users
                        withAnimation(.easeOut(duration: 0.5)) {
                            showSplashScreen = false
                        }
                    } else {
                        // For welcome screen, dismiss instantly (no fade)
                        // Logo is already in position from the move animation
                        showSplashScreen = false
                    }

                    // Mark that initial launch is complete
                    isInitialLaunch = false
                })
                .zIndex(1)
            }
        }
        .onAppear {
            print("📱 ContentView appeared")
            print("📱 Auth state - authenticated: \(authState.isAuthenticated), loading: \(authState.isLoading)")
        }
        .onChange(of: authState.isLoading) { isLoading in
            print("📱 Auth loading changed: \(isLoading)")
            if !isLoading {
                if !authState.isAuthenticated {
                    // Auth check finished, user is NOT logged in -> Remove splash immediately
                    print("📱 User not authenticated after load - skipping splash")
                    showSplashScreen = false
                    isInitialLaunch = false
                } else {
                    print("📱 User authenticated after load - showing splash")
                    // User IS authenticated -> Keep splash screen (it will dismiss itself via onComplete)
                }
            }
        }
        .onChange(of: authState.isAuthenticated) { newValue in
            print("📱 Auth state changed - authenticated: \(newValue)")

            if !newValue {
                // User signed out - body will automatically show WelcomeView
                print("📱 User signed out, will show WelcomeView")
                // Ensure splash is hidden so WelcomeView shows
                showSplashScreen = false
                isInitialLaunch = false
            }
        }
        .dismissKeyboardOnTouch()
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationState())
}
