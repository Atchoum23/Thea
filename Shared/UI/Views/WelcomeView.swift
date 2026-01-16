import SwiftUI

struct WelcomeView: View {
  @State private var showingSettings = false

  var body: some View {
    VStack(spacing: 24) {
      Spacer()

      // Logo/Icon
      Image(systemName: "sparkles")
        .font(.system(size: 80))
        .foregroundStyle(Color.theaPrimaryGradient)

      // Title
      Text("Welcome to THEA")
        .font(.theaDisplay)

      // Subtitle
      Text("Your AI Life Companion")
        .font(.theaTitle3)
        .foregroundStyle(.secondary)

      Spacer()

      // Quick Actions
      VStack(spacing: 12) {
        Button {
          NotificationCenter.default.post(name: Notification.Name.newConversation, object: nil)
        } label: {
          Label("New Conversation", systemImage: "plus.message")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)

        Button {
          showingSettings = true
        } label: {
          Label("Set Up Providers", systemImage: "network")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
      }
      .frame(maxWidth: 300)

      Spacer()
    }
    .padding()
    .sheet(isPresented: $showingSettings) {
      SettingsView()
    }
  }
}

#Preview {
  WelcomeView()
}
