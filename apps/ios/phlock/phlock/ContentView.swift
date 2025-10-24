//
//  ContentView.swift
//  phlock
//
//  Created by Woon Lee on 10/24/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authState: AuthenticationState

    var body: some View {
        Group {
            if authState.isLoading {
                LoadingView(message: "Loading...")
            } else if authState.isAuthenticated {
                MainView()
            } else {
                WelcomeView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationState())
}
