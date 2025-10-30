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
