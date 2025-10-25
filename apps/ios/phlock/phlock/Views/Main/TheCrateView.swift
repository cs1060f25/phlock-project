import SwiftUI

struct TheCrateView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 12) {
                    Text("🎵")
                        .font(.system(size: 64))

                    Text("The Crate")
                        .font(.system(size: 28, weight: .bold))

                    Text("Your personalized music feed from friends")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Text("Coming soon...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .padding(32)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(20)
                .padding(.horizontal, 24)

                Spacer()
            }
            .navigationTitle("The Crate")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    TheCrateView()
}
