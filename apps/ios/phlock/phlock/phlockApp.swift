//
//  phlockApp.swift
//  phlock
//
//  Created by Woon Lee on 10/24/25.
//

import SwiftUI
import Supabase

@main
struct phlockApp: App {
    @StateObject private var authState = AuthenticationState()

    init() {
        // Hide the default refresh control spinner since we render our own
        UIRefreshControl.appearance().tintColor = .clear
        UIRefreshControl.appearance().backgroundColor = .clear

        // Configure navigation bar to use Lora font
        configureNavigationBarAppearance()
    }

    private func configureNavigationBarAppearance() {
        // Create Lora fonts for navigation bar titles
        let loraRegular = UIFont(name: "Lora-SemiBold", size: 17) ?? UIFont.systemFont(ofSize: 17)
        let loraLarge = UIFont(name: "Lora-Bold", size: 34) ?? UIFont.boldSystemFont(ofSize: 34)

        // Configure standard navigation bar appearance (inline titles)
        let standardAppearance = UINavigationBarAppearance()
        standardAppearance.configureWithDefaultBackground()
        standardAppearance.titleTextAttributes = [
            .font: loraRegular
        ]

        // Configure large title appearance
        let largeTitleAppearance = UINavigationBarAppearance()
        largeTitleAppearance.configureWithDefaultBackground()
        largeTitleAppearance.largeTitleTextAttributes = [
            .font: loraLarge
        ]
        largeTitleAppearance.titleTextAttributes = [
            .font: loraRegular
        ]

        // Apply to all navigation bars
        UINavigationBar.appearance().standardAppearance = standardAppearance
        UINavigationBar.appearance().compactAppearance = standardAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = largeTitleAppearance
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authState)
                .onOpenURL { url in
                    // Handle OAuth callback from Supabase
                    Task {
                        do {
                            try await PhlockSupabaseClient.shared.client.auth.session(from: url)
                            print("✅ OAuth callback handled: \(url)")
                        } catch {
                            print("❌ Failed to handle OAuth callback: \(error)")
                        }
                    }
                }
        }
    }
}
