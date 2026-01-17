import SwiftUI
import SwiftData

@main
struct TheaMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [
                    Conversation.self,
                    AIMessage.self,
                    Project.self
                ])
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Conversation") {
                    // New conversation action
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .modelContainer(for: [
                    Conversation.self,
                    AIMessage.self,
                    Project.self
                ])
        }
    }
}

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            HomeView()
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
