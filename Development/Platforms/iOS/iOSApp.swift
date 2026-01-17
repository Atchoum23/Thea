import SwiftUI
import SwiftData

@main
struct TheaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [
                    Conversation.self,
                    AIMessage.self,
                    Project.self
                ])
        }
    }
}

struct ContentView: View {
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            HomeView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { showingSettings = true }) {
                            Label("Settings", systemImage: "gear")
                        }
                    }
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView()
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Conversation.self,
            AIMessage.self,
            Project.self
        ], inMemory: true)
}
