import Foundation
import os.log
#if canImport(CoreBluetooth)
    @preconcurrency import CoreBluetooth
#endif
#if canImport(HomeKit)
    @preconcurrency import HomeKit
#endif

// MARK: - Environment Context Provider

/// Provides environmental context including time, Bluetooth devices, and smart home state
public actor EnvironmentContextProvider: ContextProvider {
    public let providerId = "environment"
    public let displayName = "Environment"

    private let logger = Logger(subsystem: "app.thea", category: "EnvironmentProvider")

    private var state: ContextProviderState = .idle
    private var continuation: AsyncStream<ContextUpdate>.Continuation?
    private var _updates: AsyncStream<ContextUpdate>?
    private var updateTask: Task<Void, Never>?

    #if canImport(CoreBluetooth)
        private var bluetoothHelper: BluetoothHelper?
        private var discoveredDevices: [String] = []
    #endif

    #if canImport(HomeKit) && !os(tvOS)
        private var homeKitHelper: HomeKitHelper?
        private var currentScene: String?
    #endif

    public var isActive: Bool { state == .running }

    public var updates: AsyncStream<ContextUpdate> {
        if let existing = _updates {
            return existing
        }
        let (stream, cont) = AsyncStream<ContextUpdate>.makeStream()
        _updates = stream
        continuation = cont
        return stream
    }

    public init() {}

    public func start() async throws {
        guard state != .running else {
            throw ContextProviderError.alreadyRunning
        }

        state = .starting

        #if canImport(CoreBluetooth)
            await setupBluetooth()
        #endif

        #if canImport(HomeKit) && !os(tvOS)
            await setupHomeKit()
        #endif

        // Start periodic updates
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.fetchEnvironmentData()
                try? await Task.sleep(for: .seconds(30))
            }
        }

        state = .running
        logger.info("Environment provider started")
    }

    public func stop() async {
        guard state == .running else { return }

        state = .stopping
        updateTask?.cancel()
        updateTask = nil

        #if canImport(CoreBluetooth)
            if let helper = bluetoothHelper {
                await helper.stopScanning()
            }
            bluetoothHelper = nil
        #endif

        #if canImport(HomeKit) && !os(tvOS)
            homeKitHelper = nil
        #endif

        continuation?.finish()
        continuation = nil
        _updates = nil

        state = .stopped
        logger.info("Environment provider stopped")
    }

    public func getCurrentContext() async -> ContextUpdate? {
        let context = await buildEnvironmentContext()
        return ContextUpdate(
            providerId: providerId,
            updateType: .environment(context),
            priority: .low
        )
    }

    // MARK: - Private Methods

    #if canImport(CoreBluetooth)
        private func setupBluetooth() async {
            let helper = await MainActor.run {
                BluetoothHelper()
            }
            bluetoothHelper = helper

            await helper.setup { [weak self] devices in
                Task {
                    await self?.handleBluetoothUpdate(devices)
                }
            }
        }

        private func handleBluetoothUpdate(_ devices: [String]) async {
            discoveredDevices = devices
        }
    #endif

    #if canImport(HomeKit) && !os(tvOS)
        private func setupHomeKit() async {
            let helper = await MainActor.run {
                HomeKitHelper()
            }
            homeKitHelper = helper

            await helper.setup { [weak self] scene in
                Task {
                    await self?.handleHomeKitUpdate(scene)
                }
            }
        }

        private func handleHomeKitUpdate(_ scene: String?) async {
            currentScene = scene
        }
    #endif

    private func fetchEnvironmentData() async {
        let context = await buildEnvironmentContext()

        let update = ContextUpdate(
            providerId: providerId,
            updateType: .environment(context),
            priority: .low
        )
        continuation?.yield(update)
    }

    private func buildEnvironmentContext() async -> EnvironmentContext {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)

        let timeOfDay: EnvironmentContext.TimeOfDay = switch hour {
        case 5 ..< 8: .earlyMorning
        case 8 ..< 12: .morning
        case 12 ..< 17: .afternoon
        case 17 ..< 21: .evening
        default: .night
        }

        let isWeekend = weekday == 1 || weekday == 7

        // Determine if daylight (simplified - would use actual sunrise/sunset)
        let isDaylight = hour >= 6 && hour < 20

        #if canImport(CoreBluetooth)
            let bluetoothDevices = discoveredDevices
        #else
            let bluetoothDevices: [String] = []
        #endif

        #if canImport(HomeKit) && !os(tvOS)
            let homeScene = currentScene
        #else
            let homeScene: String? = nil
        #endif

        return EnvironmentContext(
            timeOfDay: timeOfDay,
            isWeekend: isWeekend,
            isDaylight: isDaylight,
            ambientLightLevel: nil, // Would need sensors
            noiseLevel: nil, // Would need microphone
            nearbyBluetoothDevices: bluetoothDevices,
            connectedAccessories: getConnectedAccessories(),
            homeKitScene: homeScene,
            weatherCondition: nil, // Would need WeatherKit
            temperature: nil
        )
    }

    private func getConnectedAccessories() -> [String] {
        let accessories: [String] = []

        #if os(iOS)
            // Check for AirPods, etc. via AVAudioSession
            // Simplified implementation
        #endif

        return accessories
    }
}

// MARK: - Bluetooth Helper

#if canImport(CoreBluetooth)
    @MainActor
    private final class BluetoothHelper: NSObject, CBCentralManagerDelegate {
        private var centralManager: CBCentralManager?
        private var onDevicesDiscovered: (@Sendable ([String]) -> Void)?
        private var discoveredDevices: Set<String> = []

        override nonisolated init() {
            super.init()
        }

        func setup(onDevicesDiscovered: @escaping @Sendable ([String]) -> Void) {
            self.onDevicesDiscovered = onDevicesDiscovered
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }

        func stopScanning() {
            centralManager?.stopScan()
            centralManager = nil
        }

        nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
            Task { @MainActor in
                if central.state == .poweredOn {
                    // Start scanning for nearby devices
                    central.scanForPeripherals(withServices: nil, options: [
                        CBCentralManagerScanOptionAllowDuplicatesKey: false
                    ])
                }
            }
        }

        nonisolated func centralManager(_: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData _: [String: Any], rssi _: NSNumber) {
            Task { @MainActor in
                if let name = peripheral.name {
                    self.discoveredDevices.insert(name)
                    self.onDevicesDiscovered?(Array(self.discoveredDevices))
                }
            }
        }
    }
#endif

// MARK: - HomeKit Helper

#if canImport(HomeKit) && !os(tvOS)
    @MainActor
    private final class HomeKitHelper: NSObject, HMHomeManagerDelegate {
        private var homeManager: HMHomeManager?
        private var onSceneChange: (@Sendable (String?) -> Void)?

        override nonisolated init() {
            super.init()
        }

        func setup(onSceneChange: @escaping @Sendable (String?) -> Void) {
            self.onSceneChange = onSceneChange
            homeManager = HMHomeManager()
            homeManager?.delegate = self
        }

        nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
            Task { @MainActor in
                // Check first home for active scene (primaryHome is deprecated)
                if manager.homes.first != nil {
                    // HomeKit doesn't directly expose "current scene"
                    // We'd need to infer from accessory states
                    self.onSceneChange?(nil)
                }
            }
        }
    }
#endif
