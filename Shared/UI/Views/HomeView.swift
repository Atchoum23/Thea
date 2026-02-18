@preconcurrency import SwiftData
import SwiftUI

struct HomeView: View {
    @State private var selectedConversation: Conversation?
    @State private var showingSettings = false
    @State private var errorMessage: String?
    @State private var showingError = false

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
                        do {
                            try await ChatManager.shared.sendMessage(prompt, in: conversation)
                        } catch {
                            errorMessage = "Failed to send message: \(error.localizedDescription)"
                            showingError = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .alert("Error", isPresented: $showingError, presenting: errorMessage) { _ in
            Button("OK") { }
        } message: { message in
            Text(message)
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
