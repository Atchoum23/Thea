import SwiftUI

#if os(macOS)
import CoreGraphics

/// Display management dashboard
public struct DisplayDashboardView: View {
    @State private var viewModel = DisplayViewModel()
    @State private var showingScheduleEditor = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Display Selector
                    if viewModel.hasMultipleDisplays {
                        displaySelectorSection
                    }

                    // Brightness Control
                    brightnessControlSection

                    // Contrast Control
                    if viewModel.supportsHardwareControl {
                        contrastControlSection
                    }

                    // Preset Profiles
                    presetProfilesSection

                    // Current Profile
                    if let profile = viewModel.currentProfile {
                        currentProfileSection(profile)
                    }

                    // Schedule Management
                    scheduleSection
                }
                .padding(.vertical)
            }
            .navigationTitle("Display")
            .toolbar {
                Button {
                    Task {
                        await viewModel.refreshData()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .sheet(isPresented: $showingScheduleEditor) {
                ScheduleEditorView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadDisplays()
            }
        }
    }

    // MARK: - Display Selector Section

    private var displaySelectorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Display")
                .font(.headline)
                .padding(.horizontal)

            Picker("Display", selection: Binding(
                get: { viewModel.selectedDisplay },
                set: { viewModel.selectedDisplay = $0 }
            )) {
                ForEach(viewModel.displays) { display in
                    Text(display.name).tag(display as Display?)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
    }

    // MARK: - Brightness Control Section

    private var brightnessControlSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Brightness")
                    .font(.headline)

                Spacer()

                Text("\(viewModel.currentProfile?.brightness ?? 50)%")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: { Double(viewModel.currentProfile?.brightness ?? 50) },
                    set: { newValue in
                        Task {
                            await viewModel.setBrightness(Int(newValue))
                        }
                    }
                ),
                in: 0...100,
                step: 1
            )

            HStack {
                Image(systemName: "sun.min")
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Contrast Control Section

    private var contrastControlSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Contrast")
                    .font(.headline)

                Spacer()

                Text("\(viewModel.currentProfile?.contrast ?? 50)%")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: { Double(viewModel.currentProfile?.contrast ?? 50) },
                    set: { newValue in
                        Task {
                            await viewModel.setContrast(Int(newValue))
                        }
                    }
                ),
                in: 0...100,
                step: 1
            )

            HStack {
                Image(systemName: "circle.lefthalf.filled")
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: "circle.fill")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Preset Profiles Section

    private var presetProfilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preset Profiles")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(viewModel.presetProfiles) { profile in
                    Button {
                        Task {
                            await viewModel.applyProfile(profile)
                        }
                    } label: {
                        ProfileCard(profile: profile)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Current Profile Section

    private func currentProfileSection(_ profile: DisplayProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Profile")
                .font(.headline)

            VStack(spacing: 8) {
                HStack {
                    Text("Profile:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(profile.name)
                }

                Divider()

                HStack {
                    Text("Color Temperature:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(profile.colorTemperature.rawValue)
                }

                Divider()

                HStack {
                    Text("HDR:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(profile.hdrEnabled ? "Enabled" : "Disabled")
                }

                Divider()

                HStack {
                    Text("Night Shift:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(profile.nightShiftStrength)%")
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Schedules")
                    .font(.headline)

                Spacer()

                Button {
                    showingScheduleEditor = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.caption)
                }
            }
            .padding(.horizontal)

            if viewModel.schedules.isEmpty {
                Text("No schedules configured")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(viewModel.schedules) { schedule in
                    ScheduleCard(schedule: schedule)
                }
            }
        }
    }
}

// MARK: - Profile Card

private struct ProfileCard: View {
    let profile: DisplayProfile

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: iconForProfile(profile.name))
                .font(.title2)
                .foregroundStyle(.blue)

            Text(profile.name)
                .font(.headline)

            HStack(spacing: 4) {
                Image(systemName: "sun.max.fill")
                    .font(.caption2)
                Text("\(profile.brightness)%")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func iconForProfile(_ name: String) -> String {
        switch name {
        case "Daytime": return "sun.max.fill"
        case "Evening": return "sunset.fill"
        case "Night": return "moon.stars.fill"
        case "Reading": return "book.fill"
        case "Movie": return "tv.fill"
        default: return "display"
        }
    }
}

// MARK: - Schedule Card

private struct ScheduleCard: View {
    let schedule: DisplaySchedule

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(schedule.name)
                    .font(.headline)

                Spacer()

                Toggle("", isOn: .constant(schedule.isEnabled))
                    .labelsHidden()
            }

            ForEach(schedule.rules) { rule in
                HStack {
                    Text(rule.time)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(rule.profile.name)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Schedule Editor View

private struct ScheduleEditorView: View {
    @Bindable var viewModel: DisplayViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var scheduleName = "Custom Schedule"
    @State private var isEnabled = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Schedule Name") {
                    TextField("Name", text: $scheduleName)
                }

                Section("Enabled") {
                    Toggle("Active", isOn: $isEnabled)
                }

                Section {
                    Button("Use Circadian Schedule") {
                        Task {
                            await viewModel.setSchedule(.circadian)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("New Schedule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    DisplayDashboardView()
}

#endif
