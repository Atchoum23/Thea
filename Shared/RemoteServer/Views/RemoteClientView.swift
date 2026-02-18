//
//  RemoteClientView.swift
//  Thea
//
//  Created by Claude Code on 2026-01-22
//  Copyright © 2026. All rights reserved.
//

import OSLog
import SwiftUI

#if os(macOS) || os(iOS)

    // MARK: - Remote Client View

    /// View for connecting to and controlling remote Thea servers
    public struct RemoteClientView: View {
        @StateObject private var client = TheaRemoteClient()
        @StateObject private var discovery = NetworkDiscoveryService()
        @State private var selectedDevice: DiscoveredDevice?
        @State private var showConnectionSheet = false
        @State private var pairingCode = ""
        @State private var error: String?

        public init() {}

        public var body: some View {
            NavigationStack {
                Group {
                    switch client.connectionState {
                    case .disconnected:
                        disconnectedView
                    case .connecting, .authenticating:
                        connectingView
                    case .connected:
                        connectedView
                    case let .error(message):
                        errorView(message: message)
                    }
                }
                .navigationTitle("Remote Control")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        if client.connectionState == .connected {
                            Button("Disconnect") {
                                Task {
                                    await client.disconnect()
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showConnectionSheet) {
                ConnectionSheet(
                    device: selectedDevice,
                    pairingCode: $pairingCode,
                    onConnect: connect
                )
            }
            .task {
                await discovery.startDiscovery()
            }
        }

        // MARK: - Disconnected View

        private var disconnectedView: some View {
            VStack(spacing: 24) {
                if discovery.isSearching {
                    ProgressView()
                        .padding(.bottom)
                }

                if discovery.discoveredDevices.isEmpty {
                    ContentUnavailableView {
                        Label("No Devices Found", systemImage: "desktopcomputer.trianglebadge.exclamationmark")
                    } description: {
                        Text("Make sure Thea Remote Server is running on the device you want to connect to")
                    } actions: {
                        Button("Manual Connection") {
                            selectedDevice = nil
                            showConnectionSheet = true
                        }
                    }
                } else {
                    List(discovery.discoveredDevices) { device in
                        DiscoveredDeviceRow(device: device) {
                            selectedDevice = device
                            showConnectionSheet = true
                        }
                    }
                }
            }
            .padding()
        }

        // MARK: - Connecting View

        private var connectingView: some View {
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)

                Text(client.connectionState == .authenticating ? "Authenticating..." : "Connecting...")
                    .font(.headline)

                if let device = selectedDevice {
                    Text(device.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button("Cancel") {
                    Task {
                        await client.disconnect()
                    }
                }
            }
            .padding()
        }

        // MARK: - Connected View

        private var connectedView: some View {
            VStack(spacing: 0) {
                // Connection info bar
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)

                    Text("Connected to \(client.connectedServer?.name ?? "Unknown")")

                    Spacer()

                    Text("Latency: \(Int(client.latency * 1000))ms")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.bar)

                // Remote screen view
                RemoteScreenView(client: client)
            }
        }

        // MARK: - Error View

        private func errorView(message: String) -> some View {
            ContentUnavailableView {
                Label("Connection Error", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") {
                    Task {
                        await client.disconnect()
                    }
                }
            }
        }

        // MARK: - Connect

        private func connect() {
            Task {
                do {
                    let credentials = ClientCredentials(
                        clientName: getDeviceName(),
                        deviceType: getDeviceType(),
                        requestedPermissions: [.viewScreen, .controlScreen, .viewFiles, .readFiles],
                        pairingCode: pairingCode.isEmpty ? nil : pairingCode
                    )

                    if let device = selectedDevice, let address = device.address, let port = device.port {
                        try await client.connect(
                            to: address,
                            port: port,
                            authMethod: .pairingCode,
                            credentials: credentials
                        )
                    }

                    showConnectionSheet = false
                } catch {
                    self.error = error.localizedDescription
                }
            }
        }

        private func getDeviceName() -> String {
            #if os(macOS)
                return Host.current().localizedName ?? "Mac"
            #else
                return UIDevice.current.name
            #endif
        }

        private func getDeviceType() -> RemoteClient.DeviceType {
            #if os(macOS)
                return .mac
            #elseif os(iOS)
                if UIDevice.current.userInterfaceIdiom == .pad {
                    return .iPad
                }
                return .iPhone
            #else
                return .unknown
            #endif
        }
    }

    // MARK: - Discovered Device Row

    private struct DiscoveredDeviceRow: View {
        let device: DiscoveredDevice
        let onConnect: () -> Void

        var body: some View {
            Button(action: onConnect) {
                HStack {
                    Image(systemName: platformIcon)
                        .font(.title2)
                        .frame(width: 40)

                    VStack(alignment: .leading) {
                        Text(device.name)
                            .font(.headline)

                        Text(device.platform)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if device.isReachable {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                    }

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }

        private var platformIcon: String {
            switch device.platform.lowercased() {
            case "macos": "desktopcomputer"
            case "ios": "iphone"
            case "ipados": "ipad"
            default: "questionmark.circle"
            }
        }
    }

    // MARK: - Connection Sheet

    private struct ConnectionSheet: View {
        let device: DiscoveredDevice?
        @Binding var pairingCode: String
        let onConnect: () -> Void
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            NavigationStack {
                Form {
                    if let device {
                        Section {
                            LabeledContent("Device") {
                                Text(device.name)
                            }

                            LabeledContent("Platform") {
                                Text(device.platform)
                            }
                        } header: {
                            Text("Server")
                        }
                    }

                    Section {
                        TextField("Pairing Code", text: $pairingCode)
                            .textFieldStyle(.roundedBorder)
                        #if os(iOS)
                            .keyboardType(.numberPad)
                        #endif
                    } header: {
                        Text("Authentication")
                    } footer: {
                        Text("Enter the 6-digit pairing code shown on the server")
                    }

                    Section {
                        RemotePermissionRow(permission: .viewScreen, isRequested: true)
                        RemotePermissionRow(permission: .controlScreen, isRequested: true)
                        RemotePermissionRow(permission: .viewFiles, isRequested: true)
                        RemotePermissionRow(permission: .readFiles, isRequested: true)
                    } header: {
                        Text("Requested Permissions")
                    }
                }
                .navigationTitle("Connect")
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                dismiss()
                            }
                        }

                        ToolbarItem(placement: .confirmationAction) {
                            Button("Connect") {
                                onConnect()
                            }
                            .disabled(pairingCode.count != 6)
                        }
                    }
            }
            #if os(macOS)
            .frame(width: 400, height: 400)
            #endif
        }
    }

    // MARK: - Permission Row

    private struct RemotePermissionRow: View {
        let permission: RemotePermission
        let isRequested: Bool

        var body: some View {
            HStack {
                Image(systemName: permissionIcon)
                    .foregroundStyle(riskColor)
                    .frame(width: 24)

                Text(permission.displayName)

                Spacer()

                if isRequested {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }

        private var permissionIcon: String {
            switch permission {
            case .viewScreen: "eye"
            case .controlScreen: "cursorarrow.click"
            case .viewFiles: "folder"
            case .readFiles: "doc"
            case .writeFiles: "doc.badge.plus"
            case .deleteFiles: "trash"
            case .executeCommands: "terminal"
            case .systemControl: "power"
            case .networkAccess: "network"
            case .inferenceRelay: "brain"
            }
        }

        private var riskColor: Color {
            switch permission.riskLevel {
            case .low: .green
            case .medium: .yellow
            case .high: .orange
            case .critical: .red
            }
        }
    }

    // MARK: - Remote Screen View

    private struct RemoteScreenView: View {
        @ObservedObject var client: TheaRemoteClient
        @State private var isStreaming = false
        @State private var scale: CGFloat = 1.0
        @State private var offset: CGSize = .zero
        private let logger = Logger(subsystem: "com.thea.app", category: "RemoteClientView")

        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    Color.black

                    if let frame = client.lastScreenFrame {
                        ScreenFrameView(frame: frame, geometry: geometry)
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(magnificationGesture)
                            .gesture(dragGesture)
                            .gesture(tapGesture(in: geometry))
                    } else {
                        ContentUnavailableView {
                            Label("No Screen", systemImage: "rectangle.dashed")
                        } description: {
                            Text("Start screen sharing to view remote screen")
                        }
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    controlsOverlay
                }
            }
            .onAppear {
                Task {
                    do {
                        _ = try await client.captureScreen()
                    } catch {
                        logger.warning("Failed to capture screen on appear: \(error.localizedDescription)")
                    }
                }
            }
        }

        private var controlsOverlay: some View {
            HStack(spacing: 12) {
                Button(action: captureScreen) {
                    Image(systemName: "camera")
                }

                Button(action: toggleStream) {
                    Image(systemName: isStreaming ? "stop.fill" : "play.fill")
                }

                Button(action: resetView) {
                    Image(systemName: "arrow.counterclockwise")
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding()
        }

        private var magnificationGesture: some Gesture {
            MagnificationGesture()
                .onChanged { value in
                    scale = value
                }
        }

        private var dragGesture: some Gesture {
            DragGesture()
                .onChanged { value in
                    offset = value.translation
                }
        }

        private func tapGesture(in geometry: GeometryProxy) -> some Gesture {
            SpatialTapGesture()
                .onEnded { value in
                    guard let frame = client.lastScreenFrame else { return }

                    // Convert tap location to remote screen coordinates
                    let scaleX = CGFloat(frame.width) / geometry.size.width
                    let scaleY = CGFloat(frame.height) / geometry.size.height

                    let x = Int(value.location.x * scaleX)
                    let y = Int(value.location.y * scaleY)

                    Task {
                        do {
                            try await client.click(at: x, y)
                        } catch {
                            logger.warning("Failed to send click: \(error.localizedDescription)")
                        }
                        do {
                            _ = try await client.captureScreen()
                        } catch {
                            logger.warning("Failed to capture screen after click: \(error.localizedDescription)")
                        }
                    }
                }
        }

        private func captureScreen() {
            Task {
                do {
                    _ = try await client.captureScreen()
                } catch {
                    logger.warning("Failed to capture screen: \(error.localizedDescription)")
                }
            }
        }

        private func toggleStream() {
            Task {
                do {
                    if isStreaming {
                        try await client.stopScreenStream()
                    } else {
                        try await client.startScreenStream()
                    }
                    isStreaming.toggle()
                } catch {
                    logger.warning("Failed to toggle screen stream: \(error.localizedDescription)")
                }
            }
        }

        private func resetView() {
            withAnimation {
                scale = 1.0
                offset = .zero
            }
        }
    }

    // MARK: - Screen Frame View

    private struct ScreenFrameView: View {
        let frame: ScreenFrame
        let geometry: GeometryProxy

        var body: some View {
            if let image = createImage() {
                Image(decorative: image, scale: 1.0)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }

        private func createImage() -> CGImage? {
            #if os(macOS)
                guard let nsImage = NSImage(data: frame.data),
                      let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
                else {
                    return nil
                }
                return cgImage
            #else
                guard let uiImage = UIImage(data: frame.data) else {
                    return nil
                }
                return uiImage.cgImage
            #endif
        }
    }

    // MARK: - Preview

    #Preview {
        RemoteClientView()
    }

#endif // os(macOS) || os(iOS)
