import SwiftData
import SwiftUI

// MARK: - Life Tracking Dashboard (Simplified)
// Placeholder view for life tracking features

struct LifeTrackingView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var selectedDate = Date()

    private var config: LifeTrackingConfiguration {
        AppConfiguration.shared.lifeTrackingConfig
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    trackingStatusSection

                    comingSoonSection
                }
                .padding()
            }
            .navigationTitle("Life Tracking")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                        .labelsHidden()
                }
            }
        }
    }

    // MARK: - Tracking Status

    private var trackingStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tracking Status")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                #if os(iOS) || os(watchOS)
                if config.healthTrackingEnabled {
                    StatusRow(title: "Health Tracking", isEnabled: true)
                }

                if config.locationTrackingEnabled {
                    StatusRow(title: "Location Tracking", isEnabled: true)
                }
                #endif

                #if os(macOS)
                if config.screenTimeTrackingEnabled {
                    StatusRow(title: "Screen Time", isEnabled: true)
                }

                if config.inputTrackingEnabled {
                    StatusRow(title: "Input Activity", isEnabled: true)
                }
                #endif

                if config.browserTrackingEnabled {
                    StatusRow(title: "Browsing History", isEnabled: true)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }

    // MARK: - Coming Soon

    private var comingSoonSection: some View {
        VStack(alignment: .center, spacing: 16) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Life Tracking Dashboard")
                .font(.title2)
                .bold()

            Text("Comprehensive health, activity, and productivity insights coming soon.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Supporting Views

struct StatusRow: View {
    let title: String
    let isEnabled: Bool

    var body: some View {
        HStack {
            Circle()
                .fill(isEnabled ? Color.green : Color.gray)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.body)

            Spacer()

            Text(isEnabled ? "Enabled" : "Disabled")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
