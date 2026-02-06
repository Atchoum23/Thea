import SwiftUI

struct WelcomeView: View {
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            // Subtle gradient background for Liquid Glass effect
            LinearGradient(
                colors: [
                    Color.theaPrimary.opacity(0.05),
                    Color.purple.opacity(0.03),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Logo/Icon with Liquid Glass circle
                Image(systemName: "sparkles")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.theaPrimaryGradient)
                    .padding(32)
                    .liquidGlassCircle()
                    .shadow(color: .theaPrimary.opacity(0.2), radius: 20, x: 0, y: 10)

                // Title
                Text("Welcome to THEA")
                    .font(.theaDisplay)

                // Subtitle
                Text("Your AI Life Companion")
                    .font(.theaTitle3)
                    .foregroundStyle(.secondary)

                Spacer()

                // Quick Actions with Liquid Glass styling
                VStack(spacing: 12) {
                    Button {
                        NotificationCenter.default.post(name: Notification.Name.newConversation, object: nil)
                    } label: {
                        Label("New Conversation", systemImage: "plus.message")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(GlassButtonStyle(isProminent: true))
                    .tint(.theaPrimary)

                    Button {
                        showingSettings = true
                    } label: {
                        Label("Set Up Providers", systemImage: "network")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(GlassButtonStyle())
                }
                .frame(maxWidth: 300)

                // Feature highlights
                HStack(spacing: 20) {
                    FeatureCard(icon: "brain", title: "AI Powered", description: "Multiple models")
                    FeatureCard(icon: "lock.shield", title: "Privacy First", description: "Local processing")
                    FeatureCard(icon: "waveform", title: "Voice Ready", description: "Hands-free")
                }
                .padding(.top, 20)

                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

// MARK: - Feature Card

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.theaPrimary)

            Text(title)
                .font(.caption)
                .fontWeight(.medium)

            Text(description)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 100)
        .padding()
        .liquidGlassRounded(cornerRadius: 12)
    }
}

#Preview {
    WelcomeView()
}
