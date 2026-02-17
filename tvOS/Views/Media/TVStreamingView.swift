import SwiftUI

// MARK: - TV Streaming View
// Shows streaming availability with Swiss bundled services awareness

struct TVStreamingView: View {
    @StateObject private var streamingService = StreamingAvailabilityService.shared
    @State private var selectedAccount: StreamingAccount?
    @State private var showingAddAccount = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 40) {
                    // Swiss Bundled Services Info
                    swissBundledServicesCard

                    // Configured Accounts
                    accountsSection

                    // Quick Access Grid
                    streamingAppsGrid
                }
                .padding(60)
            }
            .navigationTitle("Streaming")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddAccount = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddAccount) {
                AddStreamingAccountView()
            }
        }
    }

    // MARK: - Swiss Bundled Services Card

    private var swissBundledServicesCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(.theaWarning)
                Text("Your Swiss Streaming Bundle")
                    .font(.title3)
                    .fontWeight(.bold)
            }

            Text("Via Swisscom TV + Canal+ Switzerland, you have access to:")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 30) {
                BundledServiceBadge(name: "Canal+", icon: "tv.fill", color: .black)
                BundledServiceBadge(name: "HBO Max", icon: "film.fill", color: .purple)
                BundledServiceBadge(name: "Paramount+", icon: "mountain.2.fill", color: .theaInfo)
            }

            Text("All content accessible through the Canal+ app")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(30)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.theaInfo.opacity(0.3), .purple.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Accounts Section

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your Accounts")
                .font(.title2)
                .fontWeight(.bold)

            if streamingService.accounts.isEmpty {
                emptyAccountsView
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    ForEach(streamingService.accounts) { account in
                        AccountCard(account: account) {
                            selectedAccount = account
                        }
                    }
                }
            }
        }
    }

    private var emptyAccountsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            Text("No streaming accounts configured")
                .font(.headline)

            Text("Add your streaming subscriptions to track availability")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button("Add Account") {
                showingAddAccount = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Streaming Apps Grid

    private var streamingAppsGrid: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Quick Launch")
                .font(.title2)
                .fontWeight(.bold)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 24) {
                ForEach(StreamingAppID.allCases.filter { $0 != .other }, id: \.self) { app in
                    StreamingAppButton(app: app)
                }
            }
        }
    }
}

// MARK: - Bundled Service Badge

struct BundledServiceBadge: View {
    let name: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(name)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Account Card

struct AccountCard: View {
    let account: StreamingAccount
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: account.appID.iconName)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(appColor)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Spacer()

                    if account.isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.theaSuccess)
                    }
                }

                Text(account.appID.displayName)
                    .font(.headline)

                Text(account.accountName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Text(account.tier.rawValue.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.theaInfo.opacity(0.2))
                        .clipShape(Capsule())

                    Text(account.features.maxQuality.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.purple.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var appColor: Color {
        switch account.appID {
        case .netflix: .theaError
        case .prime: .theaInfo
        case .disney: .indigo
        case .apple: .gray
        case .hbo: .purple
        case .paramount: .theaInfo
        case .canalCH, .canal: .black
        default: .secondary
        }
    }
}

// MARK: - Streaming App Button

struct StreamingAppButton: View {
    let app: StreamingAppID

    var body: some View {
        Button {
            launchApp()
        } label: {
            VStack(spacing: 12) {
                Image(systemName: app.iconName)
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 70, height: 70)
                    .background(appColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(app.displayName)
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private var appColor: Color {
        switch app {
        case .netflix: .theaError
        case .prime: .theaInfo
        case .disney: .indigo
        case .apple: .gray
        case .hbo: .purple
        case .paramount: .theaInfo
        case .peacock: .theaSuccess
        case .hulu: .theaSuccess
        case .canalCH, .canal: .black
        case .plex: .theaWarning
        case .youtube: .theaError
        case .crunchyroll: .theaWarning
        case .swisscom: .theaInfo
        case .other: .secondary
        }
    }

    private func launchApp() {
        // On tvOS, attempt to open the app via URL scheme
        if let scheme = app.urlScheme, let url = URL(string: scheme) {
            // UIApplication.shared.open would be used here
            print("Would launch: \(url)")
        }
    }
}

// MARK: - Add Streaming Account View

struct AddStreamingAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var streamingService = StreamingAvailabilityService.shared

    @State private var selectedApp: StreamingAppID = .netflix
    @State private var accountName = ""
    @State private var selectedTier: SubscriptionTier = .premium
    @State private var maxQuality: VideoQuality = .uhd4K
    @State private var hasHDR = true
    @State private var hasDolbyVision = true
    @State private var hasDolbyAtmos = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Streaming Service") {
                    Picker("Service", selection: $selectedApp) {
                        ForEach(StreamingAppID.allCases.filter { $0 != .other }, id: \.self) { app in
                            Text(app.displayName).tag(app)
                        }
                    }
                }

                Section("Account Details") {
                    TextField("Account Name (e.g., Family)", text: $accountName)

                    Picker("Subscription Tier", selection: $selectedTier) {
                        Text("Free").tag(SubscriptionTier.free)
                        Text("Ad-Supported").tag(SubscriptionTier.adSupported)
                        Text("Standard").tag(SubscriptionTier.standard)
                        Text("Premium").tag(SubscriptionTier.premium)
                        Text("4K").tag(SubscriptionTier.fourK)
                    }
                }

                Section("Features") {
                    Picker("Max Quality", selection: $maxQuality) {
                        Text("480p").tag(VideoQuality.sd480)
                        Text("720p").tag(VideoQuality.hd720)
                        Text("1080p").tag(VideoQuality.fullHD1080)
                        Text("4K").tag(VideoQuality.uhd4K)
                    }

                    Toggle("HDR", isOn: $hasHDR)
                    Toggle("Dolby Vision", isOn: $hasDolbyVision)
                    Toggle("Dolby Atmos", isOn: $hasDolbyAtmos)
                }
            }
            .navigationTitle("Add Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addAccount()
                        dismiss()
                    }
                    .disabled(accountName.isEmpty)
                }
            }
        }
    }

    private func addAccount() {
        let account = StreamingAccount(
            id: UUID().uuidString,
            appID: selectedApp,
            accountName: accountName.isEmpty ? "Default" : accountName,
            country: "CH",
            tier: selectedTier,
            features: StreamingAccount.StreamingFeatures(
                maxQuality: maxQuality,
                hasAds: selectedTier == .adSupported || selectedTier == .free,
                simultaneousStreams: selectedTier == .premium ? 4 : 2,
                downloadable: selectedTier != .free,
                hdr: hasHDR,
                dolbyVision: hasDolbyVision,
                dolbyAtmos: hasDolbyAtmos
            ),
            isActive: true
        )

        streamingService.addAccount(account)
    }
}

// MARK: - Preview

#Preview {
    TVStreamingView()
}
