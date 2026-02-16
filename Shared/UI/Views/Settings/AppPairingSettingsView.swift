import SwiftUI

#if os(macOS)

// MARK: - App Pairing Settings View
// Placeholder for G2: Automatic Foreground App Pairing
// Will be implemented in next phase

struct AppPairingSettingsView: View {
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "app.connected.to.app.below.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.blue.gradient)

                        VStack(alignment: .leading) {
                            Text("App Pairing")
                                .font(.theaTitle2)
                            Text("Context-aware assistance for your foreground apps")
                                .font(.theaCaption1)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("This feature will automatically detect your foreground application and provide contextual assistance.")
                        .font(.theaBody)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)

                    Text("Coming in G2 phase...")
                        .font(.theaCaption1)
                        .foregroundStyle(.orange)
                        .padding(.top, 4)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("App Pairing")
    }
}

#Preview {
    AppPairingSettingsView()
        .frame(width: 600, height: 400)
}

#endif
