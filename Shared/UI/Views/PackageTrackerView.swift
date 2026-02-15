// PackageTrackerView.swift
// Thea — Package tracking UI for macOS and iOS
// Replaces: Parcel app

import SwiftUI

// MARK: - Package Tracker View

struct PackageTrackerView: View {
    @StateObject private var tracker = PackageTracker.shared
    @State private var showingAddSheet = false
    @State private var selectedTab = 0
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            Picker("", selection: $selectedTab) {
                Text("Active (\(tracker.activePackages.count))").tag(0)
                Text("Delivered (\(tracker.deliveredPackages.count))").tag(1)
                Text("Archived (\(tracker.archivedPackages.count))").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if filteredPackages.isEmpty {
                emptyState
            } else {
                packageList
            }
        }
        .frame(minWidth: 350, minHeight: 300)
        .sheet(isPresented: $showingAddSheet) {
            AddPackageView(tracker: tracker)
        }
    }

    private var filteredPackages: [TrackedPackage] {
        let base: [TrackedPackage]
        switch selectedTab {
        case 0: base = tracker.activePackages
        case 1: base = tracker.deliveredPackages
        case 2: base = tracker.archivedPackages
        default: base = tracker.packages
        }
        if searchText.isEmpty { return base }
        let query = searchText.lowercased()
        return base.filter {
            $0.label.lowercased().contains(query) ||
            $0.trackingNumber.lowercased().contains(query) ||
            $0.carrier.rawValue.lowercased().contains(query)
        }
    }

    private var headerBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search packages...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.theaSurface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()

            if tracker.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                Task { await tracker.refreshAll() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .disabled(tracker.isRefreshing)
            .accessibilityLabel("Refresh all packages")

            Button {
                showingAddSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Color.theaPrimaryDefault)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add package")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                selectedTab == 0 ? "No Active Packages" : selectedTab == 1 ? "No Delivered Packages" : "No Archived Packages",
                systemImage: "shippingbox"
            )
        } description: {
            Text(selectedTab == 0 ? "Tap + to add a tracking number" : "Packages will appear here")
        } actions: {
            if selectedTab == 0 {
                Button("Add Package") {
                    showingAddSheet = true
                }
            }
        }
    }

    private var packageList: some View {
        List {
            ForEach(filteredPackages) { package in
                PackageRowView(package: package, tracker: tracker)
            }
        }
        .listStyle(.inset)
    }
}

// MARK: - Package Row View

private struct PackageRowView: View {
    let package: TrackedPackage
    @ObservedObject var tracker: PackageTracker

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: package.carrier.icon)
                    .foregroundStyle(statusColor)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(package.label)
                        .font(.theaBody)
                        .fontWeight(.medium)
                    Text(package.trackingNumber)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer()
                statusBadge
            }

            if let latestEvent = package.latestEvent {
                HStack(spacing: 4) {
                    Image(systemName: latestEvent.status.icon)
                        .font(.caption)
                    Text(latestEvent.description)
                        .font(.caption)
                        .lineLimit(1)
                    if let location = latestEvent.location {
                        Text("· \(location)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.secondary)
            }

            if let delivery = package.estimatedDelivery {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text("Est. delivery: \(delivery, style: .date)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            if let url = package.trackingURL {
                Button {
                    #if os(macOS)
                    NSWorkspace.shared.open(url)
                    #else
                    UIApplication.shared.open(url)
                    #endif
                } label: {
                    Label("Open Tracking Page", systemImage: "safari")
                }
            }

            Button {
                #if os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(package.trackingNumber, forType: .string)
                #else
                UIPasteboard.general.string = package.trackingNumber
                #endif
            } label: {
                Label("Copy Tracking Number", systemImage: "doc.on.doc")
            }

            Divider()

            Button {
                Task { await tracker.refreshPackage(package) }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }

            if package.status == .delivered {
                Button {
                    tracker.archivePackage(package)
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }
            }

            Divider()

            Button(role: .destructive) {
                tracker.removePackage(package)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    private var statusBadge: some View {
        Text(package.status.rawValue)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch package.status.color {
        case "blue": Color.blue
        case "green": Color.green
        case "orange": Color.orange
        case "red": Color.red
        case "purple": Color.purple
        default: Color.secondary
        }
    }
}

// MARK: - Add Package View

private struct AddPackageView: View {
    @ObservedObject var tracker: PackageTracker
    @Environment(\.dismiss) private var dismiss

    @State private var trackingNumber = ""
    @State private var selectedCarrier: PackageCarrier = .swissPost
    @State private var label = ""
    @State private var notes = ""
    @State private var pasteDetections: [TrackingNumberDetection] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Tracking Number") {
                    TextField("Enter tracking number", text: $trackingNumber)
                        .textFieldStyle(.roundedBorder)
                    #if os(macOS)
                        .frame(minWidth: 280)
                    #endif

                    Button("Paste & Detect") {
                        pasteAndDetect()
                    }

                    if !pasteDetections.isEmpty {
                        ForEach(pasteDetections, id: \.trackingNumber) { detection in
                            Button {
                                trackingNumber = detection.trackingNumber
                                selectedCarrier = detection.carrier
                            } label: {
                                HStack {
                                    Image(systemName: detection.carrier.icon)
                                    Text(detection.trackingNumber)
                                        .font(.caption)
                                    Spacer()
                                    Text(detection.carrier.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text("\(Int(detection.confidence * 100))%")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Carrier") {
                    Picker("Carrier", selection: $selectedCarrier) {
                        ForEach(PackageCarrier.allCases) { carrier in
                            Label(carrier.rawValue, systemImage: carrier.icon)
                                .tag(carrier)
                        }
                    }
                }

                Section("Details (Optional)") {
                    TextField("Label (e.g., 'New laptop')", text: $label)
                        .textFieldStyle(.roundedBorder)
                    TextField("Notes", text: $notes)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Package")
            #if os(macOS)
            .frame(minWidth: 400, minHeight: 350)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        tracker.addPackage(
                            trackingNumber: trackingNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                            carrier: selectedCarrier,
                            label: label,
                            notes: notes.isEmpty ? nil : notes
                        )
                        dismiss()
                    }
                    .disabled(trackingNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func pasteAndDetect() {
        #if os(macOS)
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        #else
        guard let text = UIPasteboard.general.string else { return }
        #endif
        trackingNumber = text
        pasteDetections = TrackingNumberDetection.detect(in: text)
        if let best = pasteDetections.first {
            trackingNumber = best.trackingNumber
            selectedCarrier = best.carrier
        }
    }
}

// MARK: - Preview

#Preview("Package Tracker") {
    PackageTrackerView()
        .frame(width: 500, height: 600)
}
