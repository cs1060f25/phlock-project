import SwiftUI

struct MainView: View {
    @EnvironmentObject var authState: AuthenticationState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // The Crate Tab
            TheCrateView()
                .tabItem {
                    Label("The Crate", systemImage: "square.stack.3d.up.fill")
                }
                .tag(0)

            // Friends Tab
            FriendsView()
                .tabItem {
                    Label("Friends", systemImage: "person.2.fill")
                }
                .tag(1)

            // Profile Tab
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
                .tag(2)
        }
        .accentColor(.black)
    }
}

#Preview {
    MainView()
        .environmentObject(AuthenticationState())
}
