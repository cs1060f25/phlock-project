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
                MainView()
            } else if !showSplashScreen {
                // Not authenticated and splash is done - show welcome screen
                WelcomeView()
            } else {
                // While splash is showing, render background
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
            }

            // Splash screen overlay - only shows on initial app launch
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
        .onChange(of: authState.isAuthenticated) { _, newValue in
            print("📱 Auth state changed - authenticated: \(newValue)")

            if !newValue {
                // User signed out - body will automatically show WelcomeView
                print("📱 User signed out, will show WelcomeView")
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationState())
}
