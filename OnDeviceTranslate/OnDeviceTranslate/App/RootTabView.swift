import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            FeedView()
                .tabItem { Label("Feed", systemImage: "square.grid.2x2") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            DebugSettingsView()
                .tabItem { Label("Debug", systemImage: "ladybug") }
        }
    }
}
