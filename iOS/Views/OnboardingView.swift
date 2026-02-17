import SwiftUI

struct OnboardingView: View {
    @State private var permissionsManager = PermissionsManager.shared
    @State private var currentPage = 0
    @State private var isRequestingPermissions = false
    @Binding var isPresented: Bool

    let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "brain.head.profile",
            title: "Welcome to THEA",
            description: "Your AI Life Companion across all Apple devices",
            color: .theaPrimary
        ),
        OnboardingPage(
            icon: "mic.fill",
            title: "Voice Activation",
            description: "Say 'Hey Thea' or just 'Thea' to activate voice commands",
            color: .theaAccent
        ),
        OnboardingPage(
            icon: "icloud.fill",
            title: "Seamless Sync",
            description: "Your conversations sync across Mac, iPhone, iPad, Apple Watch, and Apple TV",
            color: .theaPurple
        ),
        OnboardingPage(
            icon: "shield.fill",
            title: "Privacy First",
            description: "All data is encrypted and stored securely on your devices",
            color: .theaGold
        ),
        OnboardingPage(
            icon: "checkmark.seal.fill",
            title: "Grant Permissions",
            description: "THEA needs a few permissions to provide the best experience",
            color: .theaPrimary
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(0 ..< pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            bottomBar
        }
        .background(Color(uiColor: .systemBackground))
    }

    private var bottomBar: some View {
        VStack(spacing: 16) {
            if currentPage == pages.count - 1 {
                permissionsSection
            }

            HStack(spacing: 16) {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Back")
                    .accessibilityHint("Goes to the previous onboarding page")
                }

                Spacer()

                if currentPage < pages.count - 1 {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.theaPrimary)
                    .accessibilityLabel("Next")
                    .accessibilityHint("Goes to the next onboarding page")
                } else {
                    Button {
                        completeOnboarding()
                    } label: {
                        if isRequestingPermissions {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Text("Get Started")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.theaPrimary)
                    .disabled(isRequestingPermissions)
                    .accessibilityLabel(isRequestingPermissions ? "Requesting permissions" : "Get Started")
                    .accessibilityHint("Requests permissions and completes onboarding setup")
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemBackground))
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OnboardingPermissionRow(
                icon: "mic.fill",
                title: "Speech Recognition",
                description: "For voice commands",
                status: permissionsManager.speechRecognitionStatus,
                isRequired: true
            )

            OnboardingPermissionRow(
                icon: "waveform",
                title: "Microphone",
                description: "To hear your voice",
                status: permissionsManager.microphoneStatus,
                isRequired: true
            )

            OnboardingPermissionRow(
                icon: "bell.fill",
                title: "Notifications",
                description: "For important updates",
                status: permissionsManager.notificationsStatus,
                isRequired: false
            )

            OnboardingPermissionRow(
                icon: "person.fill",
                title: "Contacts",
                description: "To assist with contact queries",
                status: permissionsManager.contactsStatus,
                isRequired: false
            )

            OnboardingPermissionRow(
                icon: "calendar",
                title: "Calendar",
                description: "To help manage your schedule",
                status: permissionsManager.calendarStatus,
                isRequired: false
            )

            OnboardingPermissionRow(
                icon: "photo.fill",
                title: "Photos",
                description: "To analyze images",
                status: permissionsManager.photosStatus,
                isRequired: false
            )

            #if os(iOS)
                OnboardingPermissionRow(
                    icon: "location.fill",
                    title: "Location",
                    description: "For location-aware features",
                    status: permissionsManager.locationStatus,
                    isRequired: false
                )
            #endif

            #if os(macOS)
                OnboardingPermissionRow(
                    icon: "internaldrive.fill",
                    title: "Full Disk Access",
                    description: "To scan and index your files",
                    status: permissionsManager.fullDiskAccessStatus,
                    isRequired: false
                )
            #endif
        }
        .padding()
        .background(Color(uiColor: .systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func completeOnboarding() {
        isRequestingPermissions = true

        Task {
            await permissionsManager.requestAllPermissions()

            await MainActor.run {
                isRequestingPermissions = false
                isPresented = false
            }
        }
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 100))
                .foregroundStyle(page.color)
                .symbolEffect(.bounce, value: page.icon)
                .accessibilityHidden(true)

            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct OnboardingPermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
    let isRequired: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(statusColor)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)

                    if isRequired {
                        Text("Required")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.theaError.opacity(0.2))
                            .foregroundStyle(.theaError)
                            .clipShape(Capsule())
                    }
                }

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusIndicator
                .accessibilityHidden(true)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(description)\(isRequired ? ", required" : ""), \(statusText)")
    }

    private var statusText: String {
        switch status {
        case .authorized: "granted"
        case .denied: "denied"
        case .restricted: "restricted"
        case .limited: "limited access"
        case .provisional: "provisional"
        case .notDetermined: "not yet requested"
        case .notAvailable: "not available"
        case .unknown: "unknown"
        }
    }

    private var statusColor: Color {
        switch status {
        case .authorized:
            .theaSuccess
        case .denied:
            .theaError
        case .restricted:
            .theaWarning
        case .limited:
            .theaWarning
        case .provisional:
            .theaInfo
        case .notDetermined, .notAvailable, .unknown:
            .gray
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch status {
        case .authorized:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.theaSuccess)
        case .denied:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.theaError)
        case .restricted:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.theaWarning)
        case .limited:
            Image(systemName: "checkmark.circle.badge.questionmark")
                .foregroundStyle(.theaWarning)
        case .provisional:
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.theaInfo)
        case .notDetermined, .notAvailable, .unknown:
            Image(systemName: "circle")
                .foregroundStyle(.gray)
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
