import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedConversation: Conversation?
    @State private var showingSettings = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedConversation)
        } detail: {
            if let conversation = selectedConversation {
                ChatView(conversation: conversation)
            } else {
                WelcomeView()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.newConversation)) { _ in
            createNewConversation()
        }
    }

    private func createNewConversation() {
        let conversation = ChatManager.shared.createConversation()
        selectedConversation = conversation
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Conversation.self, Message.self])
}
