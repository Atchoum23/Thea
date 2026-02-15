import SwiftUI

// MARK: - iOS Settings View

struct iOSSettingsView: View {
    @State private var settingsManager = SettingsManager.shared
    @State private var voiceManager = VoiceActivationManager.shared
    @State private var migrationManager = MigrationManager.shared

    @State private var showingMigration = false
    @State private var showingAbout = false
    @State private var showingAPIKeys = false
    @State private var showingPermissions = false
    @State private var showingClearDataConfirmation = false

    var body: some View {
        Form {
            // MARK: - AI & Models Section
            Section {
                NavigationLink {
                    IOSAIProvidersSettingsView()
                } label: {
                    SettingsRow(
                        icon: "cloud.fill",
                        iconColor: .blue,
                        title: "AI Providers",
                        subtitle: "API keys, health, usage"
                    )
                }

                NavigationLink {
                    IOSModelsSettingsView()
                } label: {
                    SettingsRow(
                        icon: "cpu",
                        iconColor: .purple,
                        title: "Models",
                        subtitle: "Favorites, capabilities, comparison"
                    )
                }

                // Local Models - not available on iOS (MLX is macOS only)
                NavigationLink {
                    IOSLocalModelsUnavailableView()
                } label: {
                    SettingsRow(
                        icon: "desktopcomputer",
                        iconColor: .gray,
                        title: "Local Models",
                        subtitle: "macOS only"
                    )
                }

                NavigationLink {
                    IOSOrchestratorSettingsView()
                } label: {
                    SettingsRow(
                        icon: "gearshape.2.fill",
                        iconColor: .orange,
                        title: "Orchestrator",
                        subtitle: "Agent pool, routing rules"
                    )
                }
            } header: {
                Text("AI & Models")
            }

            // MARK: - Assistant Section
            Section {
                NavigationLink {
                    iOSVoiceSettingsView()
                } label: {
                    SettingsRow(
                        icon: "waveform.circle.fill",
                        iconColor: .pink,
                        title: "Voice",
                        subtitle: voiceManager.isEnabled ? "Enabled" : "Disabled"
                    )
                }

                NavigationLink {
                    IOSMemorySettingsView()
                } label: {
                    SettingsRow(
                        icon: "brain",
                        iconColor: .indigo,
                        title: "Memory",
                        subtitle: "Context, learning, recall"
                    )
                }

                NavigationLink {
                    IOSAutomationSettingsView()
                } label: {
                    SettingsRow(
                        icon: "bolt.fill",
                        iconColor: .yellow,
                        title: "Automation",
                        subtitle: "Workflows, execution modes"
                    )
                }
            } header: {
                Text("Assistant")
            }

            // MARK: - Integrations Section
            Section {
                NavigationLink {
                    IOSIntegrationsSettingsView()
                } label: {
                    SettingsRow(
                        icon: "square.grid.2x2.fill",
                        iconColor: .teal,
                        title: "Integrations",
                        subtitle: "Apps, services, MCP"
                    )
                }
            } header: {
                Text("Integrations")
            }

            // MARK: - Life Section
            Section {
                NavigationLink {
                    TaskManagerView()
                } label: {
                    SettingsRow(
                        icon: "checklist",
                        iconColor: .green,
                        title: "Tasks",
                        subtitle: "\(TheaTaskManager.shared.pendingTasks.count) pending"
                    )
                }

                NavigationLink {
                    HabitTrackerView()
                } label: {
                    SettingsRow(
                        icon: "repeat.circle",
                        iconColor: .orange,
                        title: "Habits",
                        subtitle: "\(HabitManager.shared.activeHabits.count) active"
                    )
                }

                NavigationLink {
                    PackageTrackerView()
                } label: {
                    SettingsRow(
                        icon: "shippingbox",
                        iconColor: .brown,
                        title: "Packages",
                        subtitle: "Track deliveries"
                    )
                }

                NavigationLink {
                    DocumentScannerView()
                } label: {
                    SettingsRow(
                        icon: "doc.viewfinder",
                        iconColor: .teal,
                        title: "Documents",
                        subtitle: "\(DocumentScanner.shared.totalDocuments) scanned"
                    )
                }

                NavigationLink {
                    DocumentSuiteView()
                } label: {
                    SettingsRow(
                        icon: "doc.richtext",
                        iconColor: .purple,
                        title: "Document Suite",
                        subtitle: "Create & export documents"
                    )
                }

                NavigationLink {
                    DownloadManagerView()
                } label: {
                    SettingsRow(
                        icon: "arrow.down.circle",
                        iconColor: .green,
                        title: "Downloads",
                        subtitle: "Manage downloads"
                    )
                }

                NavigationLink {
                    MediaPlayerView()
                } label: {
                    SettingsRow(
                        icon: "play.rectangle",
                        iconColor: .indigo,
                        title: "Media Player",
                        subtitle: "\(MediaPlayer.shared.history.count) items"
                    )
                }

                NavigationLink {
                    MediaServerView()
                } label: {
                    SettingsRow(
                        icon: "network",
                        iconColor: .blue,
                        title: "Media Server",
                        subtitle: "\(MediaServer.shared.items.count) items"
                    )
                }

                NavigationLink {
                    LifeManagementDashboardView()
                } label: {
                    SettingsRow(
                        icon: "calendar.badge.clock",
                        iconColor: .blue,
                        title: "Life Dashboard",
                        subtitle: "Daily review & goals"
                    )
                }

                NavigationLink {
                    HealthDashboardView()
                } label: {
                    SettingsRow(
                        icon: "heart.fill",
                        iconColor: .red,
                        title: "Health",
                        subtitle: "Metrics & insights"
                    )
                }

                NavigationLink {
                    FinancialDashboardView()
                } label: {
                    SettingsRow(
                        icon: "chart.line.uptrend.xyaxis",
                        iconColor: .green,
                        title: "Finance",
                        subtitle: "Transactions & budgets"
                    )
                }
                NavigationLink {
                    NotificationIntelligenceSettingsView()
                } label: {
                    SettingsRow(
                        icon: "bell.badge",
                        iconColor: .purple,
                        title: "Notifications",
                        subtitle: "Cross-device intelligence"
                    )
                }

                NavigationLink {
                    WebClipperView()
                } label: {
                    SettingsRow(
                        icon: "scissors",
                        iconColor: .indigo,
                        title: "Web Clipper",
                        subtitle: "\(WebClipper.shared.articles.count) articles"
                    )
                }

                NavigationLink {
                    QRIntelligenceView()
                } label: {
                    SettingsRow(
                        icon: "qrcode",
                        iconColor: .teal,
                        title: "QR Scanner",
                        subtitle: "\(QRIntelligence.shared.scannedCodes.count) scanned"
                    )
                }

                NavigationLink {
                    ImageIntelligenceView()
                } label: {
                    SettingsRow(
                        icon: "photo.artframe",
                        iconColor: .pink,
                        title: "Image Intelligence",
                        subtitle: "AI-powered image processing"
                    )
                }
                NavigationLink {
                    CodeAssistantView()
                } label: {
                    SettingsRow(
                        icon: "chevron.left.forwardslash.chevron.right",
                        iconColor: .cyan,
                        title: "Code Assistant",
                        subtitle: "\(CodeAssistant.shared.projects.count) projects"
                    )
                }

                NavigationLink {
                    TravelPlanningView()
                } label: {
                    SettingsRow(
                        icon: "airplane",
                        iconColor: .blue,
                        title: "Travel",
                        subtitle: "\(TravelManager.shared.upcomingTrips.count) upcoming"
                    )
                }

                NavigationLink {
                    VehicleMaintenanceView()
                } label: {
                    SettingsRow(
                        icon: "car",
                        iconColor: .gray,
                        title: "Vehicles",
                        subtitle: "\(VehicleManager.shared.vehicles.count) vehicles"
                    )
                }

                NavigationLink {
                    ExternalSubscriptionsView()
                } label: {
                    SettingsRow(
                        icon: "creditcard.circle",
                        iconColor: .orange,
                        title: "Subscriptions",
                        subtitle: "\(ExternalSubscriptionManager.shared.activeSubscriptions.count) active"
                    )
                }

                NavigationLink {
                    PasswordVaultView()
                } label: {
                    SettingsRow(
                        icon: "lock.shield",
                        iconColor: .red,
                        title: "Passwords",
                        subtitle: "\(PasswordManager.shared.entries.count) credentials"
                    )
                }

                NavigationLink {
                    LearningDashboardView()
                } label: {
                    SettingsRow(
                        icon: "graduationcap",
                        iconColor: .purple,
                        title: "Learning",
                        subtitle: "\(LearningTracker.shared.activeGoals.count) active goals"
                    )
                }

                NavigationLink {
                    HomeIntelligenceView()
                } label: {
                    SettingsRow(
                        icon: "house.fill",
                        iconColor: .cyan,
                        title: "Home",
                        subtitle: "\(HomeKitService.shared.accessories.count) devices"
                    )
                }
            } header: {
                Text("Life")
            }

            // MARK: - Appearance Section
            Section {
                Picker("Theme", selection: $settingsManager.theme) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.menu)

                Picker("Font Size", selection: $settingsManager.fontSize) {
                    Text("Small").tag("small")
                    Text("Medium").tag("medium")
                    Text("Large").tag("large")
                }
                .pickerStyle(.menu)
            } header: {
                Text("Appearance")
            }

            // MARK: - Data & Sync Section
            Section {
                NavigationLink {
                    IOSSyncSettingsView()
                } label: {
                    SettingsRow(
                        icon: "icloud.fill",
                        iconColor: .cyan,
                        title: "Sync",
                        subtitle: settingsManager.iCloudSyncEnabled ? "iCloud enabled" : "Off"
                    )
                }

                NavigationLink {
                    IOSBackupSettingsView()
                } label: {
                    SettingsRow(
                        icon: "arrow.clockwise.icloud.fill",
                        iconColor: .mint,
                        title: "Backup & Restore",
                        subtitle: "Manage backups"
                    )
                }

                Button {
                    showingMigration = true
                } label: {
                    SettingsRow(
                        icon: "arrow.down.doc.fill",
                        iconColor: .blue,
                        title: "Import Data",
                        subtitle: "From ChatGPT, Claude, Cursor"
                    )
                }
                .tint(.primary)
            } header: {
                Text("Data & Sync")
            }

            // MARK: - Privacy & Security Section
            Section {
                NavigationLink {
                    SystemMonitorView()
                } label: {
                    SettingsRow(
                        icon: "gauge.with.dots.needle.33percent",
                        iconColor: .blue,
                        title: "System Monitor",
                        subtitle: SystemMonitor.shared.statusSummary
                    )
                }

                NavigationLink {
                    SystemCleanerView()
                } label: {
                    SettingsRow(
                        icon: "trash.circle",
                        iconColor: .orange,
                        title: "System Cleaner",
                        subtitle: "\(SystemCleaner.shared.formattedAvailableSpace) free"
                    )
                }

                NavigationLink {
                    BatteryIntelligenceView()
                } label: {
                    SettingsRow(
                        icon: "battery.75",
                        iconColor: .green,
                        title: "Battery",
                        subtitle: BatteryOptimizer.shared.optimizationMode.displayName
                    )
                }

                NavigationLink {
                    ServiceHealthDashboardView()
                } label: {
                    SettingsRow(
                        icon: "stethoscope",
                        iconColor: .teal,
                        title: "Service Health",
                        subtitle: BackgroundServiceMonitor.shared.latestSnapshot.map {
                            "\($0.healthyCount)/\($0.checks.count) healthy"
                        } ?? "Not checked"
                    )
                }

                NavigationLink {
                    SecurityScannerView()
                } label: {
                    SettingsRow(
                        icon: "shield.lefthalf.filled",
                        iconColor: .red,
                        title: "Security",
                        subtitle: "Scan for threats"
                    )
                }

                NavigationLink {
                    IOSPrivacySettingsView()
                } label: {
                    SettingsRow(
                        icon: "hand.raised.fill",
                        iconColor: .red,
                        title: "Privacy",
                        subtitle: "Data, retention, export"
                    )
                }

                Button {
                    showingPermissions = true
                } label: {
                    SettingsRow(
                        icon: "lock.shield.fill",
                        iconColor: .gray,
                        title: "Permissions",
                        subtitle: "Camera, microphone, photos"
                    )
                }
                .tint(.primary)
            } header: {
                Text("Privacy & Security")
            }

            // MARK: - Subscription Section
            Section {
                NavigationLink {
                    SubscriptionSettingsView()
                } label: {
                    SettingsRow(
                        icon: "creditcard.fill",
                        iconColor: .purple,
                        title: "Subscription",
                        subtitle: StoreKitService.shared.subscriptionStatus.displayName
                    )
                }
            } header: {
                Text("Account")
            }

            // MARK: - Advanced Section
            Section {
                NavigationLink {
                    IOSAdvancedSettingsView()
                } label: {
                    SettingsRow(
                        icon: "wrench.and.screwdriver.fill",
                        iconColor: .gray,
                        title: "Advanced",
                        subtitle: "Network, logging, performance"
                    )
                }
            } header: {
                Text("Advanced")
            }

            // MARK: - Danger Zone Section
            Section {
                Button(role: .destructive) {
                    showingClearDataConfirmation = true
                } label: {
                    Label("Clear All Data", systemImage: "trash.fill")
                }
            } header: {
                Text("Danger Zone")
            } footer: {
                Text("Permanently delete all conversations, projects, and settings")
            }

            // MARK: - About Section
            Section {
                Button {
                    showingAbout = true
                } label: {
                    SettingsRow(
                        icon: "info.circle.fill",
                        iconColor: .blue,
                        title: "About THEA",
                        subtitle: "Version 1.0.0"
                    )
                }
                .tint(.primary)
            } header: {
                Text("About")
            }
        }
        .sheet(isPresented: $showingMigration) {
            iOSMigrationView()
        }
        .sheet(isPresented: $showingAbout) {
            iOSAboutView()
        }
        .sheet(isPresented: $showingAPIKeys) {
            iOSAPIKeysView()
        }
        .sheet(isPresented: $showingPermissions) {
            IOSPermissionsView()
        }
        .confirmationDialog(
            "Clear All Data",
            isPresented: $showingClearDataConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All Data", role: .destructive) {
                clearAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all your conversations, projects, and settings. This action cannot be undone.")
        }
    }

    private func clearAllData() {
        ChatManager.shared.clearAllData()
        ProjectManager.shared.clearAllData()
        KnowledgeManager.shared.clearAllData()
        FinancialManager.shared.clearAllData()
        settingsManager.resetToDefaults()
    }
}

// MARK: - Settings Row Component

private struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(iconColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
