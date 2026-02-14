@preconcurrency import SwiftData
import SwiftUI

struct HomeView: View {
    @State private var selectedConversation: Conversation?
    @State private var showingSettings = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedConversation)
        } detail: {
            if let conversation = selectedConversation {
                ChatView(conversation: conversation)
            } else {
                WelcomeView { prompt in
                    let conversation = ChatManager.shared.createConversation(title: "New Conversation")
                    selectedConversation = conversation
                    Task {
                        try? await ChatManager.shared.sendMessage(prompt, in: conversation)
                    }
                }
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
