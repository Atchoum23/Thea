// DynamicResourceAllocator.swift
// AI-powered dynamic resource allocation for local model inference
// Adapts in real-time based on system metrics: memory, thermal, GPU, battery, bandwidth
//
// References:
// - ProcessInfo.thermalState (Darwin)
// - sysctl for CPU/memory metrics
// - IOReport for GPU utilization (undocumented but used by iStat Menus)
// - Memory pressure notifications (Darwin)

import Foundation
import Combine
import OSLog
#if os(macOS)
import IOKit.ps
import IOKit
#elseif os(iOS) || os(watchOS) || os(tvOS)
import UIKit
#endif

// MARK: - Dynamic Resource Allocator

/// AI-powered system that dynamically allocates resources for local model inference
/// based on real-time system metrics (thermal, memory pressure, GPU, battery, bandwidth)
@MainActor
@Observable
final class DynamicResourceAllocator {
    static let shared = DynamicResourceAllocator()

    // MARK: - Published State

    private(set) var currentAllocation = ResourceAllocation()
    private(set) var systemMetrics = SystemMetrics()
    private(set) var isMonitoring = false
    private(set) var lastAdjustmentReason: String?
    private(set) var adjustmentHistory: [ResourceAdjustment] = []
    private(set) var recommendations: [ResourceRecommendation] = []

    // Configuration
    private(set) var configuration = Configuration()

    // Types are defined in DynamicResourceAllocatorTypes.swift

    // MARK: - Initialization

    private let logger = Logger(subsystem: "ai.thea.app", category: "DynamicResourceAllocator")
    private var monitoringTask: Task<Void, Never>?
    private var memoryPressureSource: DispatchSourceMemoryPressure?

    private init() {
        loadConfiguration()
        collectInitialMetrics()
        calculateInitialAllocation()

        if configuration.enableDynamicAllocation {
            startMonitoring()
        }
    }

    // MARK: - Metrics Collection

    private func collectInitialMetrics() {
        systemMetrics.totalMemoryBytes = ProcessInfo.processInfo.physicalMemory
        systemMetrics.timestamp = Date()
        updateAllSystemMetrics()
    }

    private func updateAllSystemMetrics() {
        systemMetrics.totalMemoryBytes = ProcessInfo.processInfo.physicalMemory
        systemMetrics.availableMemoryBytes = getAvailableMemory()
        systemMetrics.thermalState = getThermalState()
        systemMetrics.memoryPressure = getMemoryPressure()
        systemMetrics.cpuUsagePercent = getCPUUsage()

        #if os(macOS)
        let gpuMetrics = getGPUMetrics()
        systemMetrics.gpuUsagePercent = gpuMetrics.usage
        systemMetrics.gpuMemoryUsedBytes = gpuMetrics.memoryUsed
        systemMetrics.gpuMemoryTotalBytes = gpuMetrics.memoryTotal

        let powerMetrics = getPowerMetrics()
        systemMetrics.batteryLevel = powerMetrics.level
        systemMetrics.isCharging = powerMetrics.isCharging
        #elseif os(iOS)
        systemMetrics.batteryLevel = Double(UIDevice.current.batteryLevel)
        systemMetrics.isCharging = UIDevice.current.batteryState == .charging
        #endif

        systemMetrics.timestamp = Date()
    }

    /// Get available memory using vm_statistics64
    private func getAvailableMemory() -> UInt64 {
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) { statsPtr in
            statsPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return systemMetrics.totalMemoryBytes / 2 // Fallback
        }

        // Available = Free + Inactive + File-backed
        let freePages = UInt64(vmStats.free_count)
        let inactivePages = UInt64(vmStats.inactive_count)
        let fileBackedPages = UInt64(vmStats.external_page_count)

        return (freePages + inactivePages + fileBackedPages) * UInt64(pageSize)
    }

    /// Get thermal state from ProcessInfo
    private func getThermalState() -> ThermalState {
        let state = ProcessInfo.processInfo.thermalState
        switch state {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .nominal
        }
    }

    /// Get memory pressure level
    private func getMemoryPressure() -> MemoryPressureLevel {
        // Use Darwin memory pressure API
        var memPressure: Int32 = 0
        var size = MemoryLayout<Int32>.size
        sysctlbyname("kern.memorystatus_vm_pressure_level", &memPressure, &size, nil, 0)

        switch memPressure {
        case 1: return .warning
        case 2: return .critical
        default: return .nominal
        }
    }

    /// Get CPU usage across all cores
    private func getCPUUsage() -> Double {
        var cpuInfo: processor_info_array_t?
        var numCPUs: mach_msg_type_number_t = 0
        var numCPUInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let cpuInfo else { return 0 }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(numCPUInfo))
        }

        var totalUser: Int32 = 0
        var totalSystem: Int32 = 0
        var totalIdle: Int32 = 0

        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            totalUser += cpuInfo[offset + Int(CPU_STATE_USER)]
            totalSystem += cpuInfo[offset + Int(CPU_STATE_SYSTEM)]
            totalIdle += cpuInfo[offset + Int(CPU_STATE_IDLE)]
        }

        let total = totalUser + totalSystem + totalIdle
        guard total > 0 else { return 0 }

        return Double(totalUser + totalSystem) / Double(total) * 100.0
    }

    #if os(macOS)
    /// Get GPU metrics (usage and memory)
    /// Note: This uses IOKit which provides similar data to iStat Menus
    private func getGPUMetrics() -> (usage: Double, memoryUsed: UInt64, memoryTotal: UInt64) {
        // Try to get GPU utilization from IOKit
        // Apple Silicon GPUs expose metrics via IOAccelerator
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOAccelerator")

        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return (0, 0, 0)
        }
        defer { IOObjectRelease(iterator) }

        let service: io_object_t = IOIteratorNext(iterator)
        defer { if service != 0 { IOObjectRelease(service) } }

        guard service != 0 else { return (0, 0, 0) }

        // Get performance statistics
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let props = properties?.takeRetainedValue() as? [String: Any] else {
            return (0, 0, 0)
        }

        // Extract GPU utilization (varies by driver/hardware)
        // Common keys: "PerformanceStatistics", "Device Utilization %", "GPU Activity"
        if let perfStats = props["PerformanceStatistics"] as? [String: Any] {
            let usage = perfStats["Device Utilization %"] as? Double ?? 0
            let memUsed = perfStats["In Use System Memory"] as? UInt64 ?? 0
            let memTotal = perfStats["Allocated System Memory"] as? UInt64 ?? 0
            return (usage, memUsed, memTotal)
        }

        return (0, 0, 0)
    }

    /// Get power/battery metrics
    private func getPowerMetrics() -> (level: Double, isCharging: Bool) {
        let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]

        guard let firstSource = sources?.first else {
            return (1.0, true) // Assume plugged in if no battery
        }

        let description = IOPSGetPowerSourceDescription(snapshot, firstSource)?.takeUnretainedValue() as? [String: Any]

        let capacity = description?[kIOPSCurrentCapacityKey as String] as? Double ?? 100
        let maxCapacity = description?[kIOPSMaxCapacityKey as String] as? Double ?? 100
        let level = capacity / maxCapacity

        let powerSource = description?[kIOPSPowerSourceStateKey as String] as? String
        let isCharging = powerSource != kIOPSBatteryPowerValue

        return (level, isCharging)
    }
    #endif

    // MARK: - Allocation Calculation

    private func calculateInitialAllocation() {
        currentAllocation = calculateOptimalAllocation()
    }

    /// AI-powered allocation calculation based on current system state
    func calculateOptimalAllocation() -> ResourceAllocation {
        var allocation = ResourceAllocation()

        let totalMemory = systemMetrics.totalMemoryBytes
        let availableMemory = systemMetrics.availableMemoryBytes

        // Step 1: Calculate base memory allocation
        let reserveBytes = UInt64(configuration.reserveSystemMemoryGB * 1_073_741_824)
        let effectiveAvailable = availableMemory > reserveBytes
            ? availableMemory - reserveBytes
            : availableMemory / 2

        // Step 2: Apply thermal throttling
        var thermalMultiplier = 1.0
        switch systemMetrics.thermalState {
        case .nominal: thermalMultiplier = 1.0
        case .fair: thermalMultiplier = 0.85
        case .serious: thermalMultiplier = 0.6
        case .critical: thermalMultiplier = 0.3
        }

        // Step 3: Apply memory pressure factor
        var memoryMultiplier = 1.0
        switch systemMetrics.memoryPressure {
        case .nominal: memoryMultiplier = 1.0
        case .warning: memoryMultiplier = 0.7
        case .critical: memoryMultiplier = 0.4
        }

        // Step 4: Apply battery factor (if enabled and on battery)
        var batteryMultiplier = 1.0
        if configuration.enableBatteryAwareness && !systemMetrics.isCharging {
            batteryMultiplier = max(0.5, systemMetrics.batteryLevel)
        }

        // Step 5: Apply aggressiveness level
        let aggressivenessMultiplier = configuration.aggressivenessLevel.memoryMultiplier

        // Step 6: Calculate final allocation
        let combinedMultiplier = thermalMultiplier * memoryMultiplier * batteryMultiplier * aggressivenessMultiplier
        let maxAllocation = Double(effectiveAvailable) * configuration.maxModelMemoryPercent * combinedMultiplier

        allocation.maxModelMemoryBytes = UInt64(max(maxAllocation, Double(totalMemory) * configuration.minModelMemoryPercent))

        // Step 7: Calculate KV cache allocation
        allocation.kvCacheSizeBytes = UInt64(Double(allocation.maxModelMemoryBytes) * configuration.kvCacheMemoryPercent)

        // Step 8: Determine quantization based on available memory
        allocation.quantizationLevel = determineQuantization(availableGB: allocation.maxModelMemoryGB)

        // Step 9: Determine context length based on available KV cache
        allocation.recommendedContextLength = calculateContextLength(
            kvCacheBytes: allocation.kvCacheSizeBytes,
            quantization: allocation.quantizationLevel
        )

        // Step 10: Determine batch size based on available memory and thermals
        allocation.recommendedBatchSize = calculateBatchSize(
            availableMemory: allocation.maxModelMemoryBytes,
            thermalState: systemMetrics.thermalState
        )

        // Step 11: Determine throttle level
        allocation.throttleLevel = calculateThrottleLevel()

        // Step 12: Determine acceleration options
        allocation.useGPUAcceleration = configuration.enableGPUOffload && systemMetrics.thermalState != .critical
        allocation.useNeuralEngine = configuration.enableNeuralEngineOptimization && systemMetrics.thermalState != .critical

        // Step 13: Estimate tokens per second
        allocation.effectiveTokensPerSecond = estimateTokensPerSecond(allocation)

        return allocation
    }

    private func determineQuantization(availableGB: Double) -> QuantizationLevel {
        switch availableGB {
        case 0..<2: return .q2  // Emergency low-memory mode
        case 2..<4: return .q4
        case 4..<8: return .q4
        case 8..<16: return .q8
        case 16..<32: return .fp16
        default: return .fp16   // Don't recommend FP32 for inference
        }
    }

    private func calculateContextLength(kvCacheBytes: UInt64, quantization: QuantizationLevel) -> Int {
        // KV cache size = 2 * num_layers * num_heads * head_dim * context_length * bytes_per_element
        // For a 7B model: ~32 layers, 32 heads, 128 head_dim
        // Simplified: context_length ≈ kvCacheBytes / (num_layers * bytes_per_token)

        let bytesPerToken: Double = switch quantization {
        case .fp32: 32.0 * 128.0 * 4.0 * 2.0  // ~32KB per token
        case .fp16: 32.0 * 128.0 * 2.0 * 2.0  // ~16KB per token
        case .q8: 32.0 * 128.0 * 1.0 * 2.0    // ~8KB per token
        case .q4: 32.0 * 128.0 * 0.5 * 2.0    // ~4KB per token
        case .q2: 32.0 * 128.0 * 0.25 * 2.0   // ~2KB per token
        }

        let maxContext = Int(Double(kvCacheBytes) / bytesPerToken)
        return min(max(maxContext, 512), 131072)  // Clamp between 512 and 128K
    }

    private func calculateBatchSize(availableMemory: UInt64, thermalState: ThermalState) -> Int {
        var baseBatch = switch availableMemory {
        case 0..<(4 * 1_073_741_824): 1
        case (4 * 1_073_741_824)..<(8 * 1_073_741_824): 2
        case (8 * 1_073_741_824)..<(16 * 1_073_741_824): 4
        case (16 * 1_073_741_824)..<(32 * 1_073_741_824): 8
        default: 16
        }

        // Reduce batch size under thermal pressure
        if thermalState == .serious {
            baseBatch = max(1, baseBatch / 2)
        } else if thermalState == .critical {
            baseBatch = 1
        }

        return baseBatch
    }

    private func calculateThrottleLevel() -> ThrottleLevel {
        // Combine thermal, memory, and battery factors
        var score = 0

        switch systemMetrics.thermalState {
        case .nominal: score += 0
        case .fair: score += 1
        case .serious: score += 2
        case .critical: score += 4
        }

        switch systemMetrics.memoryPressure {
        case .nominal: score += 0
        case .warning: score += 1
        case .critical: score += 2
        }

        if !systemMetrics.isCharging && systemMetrics.batteryLevel < 0.2 {
            score += 2
        }

        return switch score {
        case 0: .none
        case 1: .light
        case 2: .moderate
        case 3...4: .heavy
        default: .severe
        }
    }

    private func estimateTokensPerSecond(_ allocation: ResourceAllocation) -> Double {
        // Rough estimation based on allocation parameters
        // Base rate depends on quantization
        var baseRate: Double = switch allocation.quantizationLevel {
        case .fp32: 5.0
        case .fp16: 15.0
        case .q8: 30.0
        case .q4: 50.0
        case .q2: 60.0
        }

        // Apply throttle multiplier
        baseRate *= allocation.throttleLevel.delayMultiplier

        // Apply acceleration bonuses
        if allocation.useGPUAcceleration {
            baseRate *= 1.5
        }
        if allocation.useNeuralEngine {
            baseRate *= 1.3
        }

        return baseRate
    }

}

// MARK: - Monitoring

extension DynamicResourceAllocator {
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        monitoringTask = Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(configuration.updateIntervalSeconds))
                } catch {
                    break
                }
                await collectMetricsAndAdjust()
            }
        }

        setupMemoryPressureMonitoring()

        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleThermalStateChange()
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
        memoryPressureSource?.cancel()
        memoryPressureSource = nil
    }

    func setupMemoryPressureMonitoring() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )

        memoryPressureSource?.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                await self?.handleMemoryPressure()
            }
        }

        memoryPressureSource?.resume()
    }

    func collectMetricsAndAdjust() async {
        updateAllSystemMetrics()

        let newAllocation = calculateOptimalAllocation()

        if shouldAdjustAllocation(from: currentAllocation, to: newAllocation) {
            let adjustment = ResourceAdjustment(
                reason: generateAdjustmentReason(),
                previous: currentAllocation,
                new: newAllocation,
                metrics: systemMetrics
            )

            adjustmentHistory.append(adjustment)
            if adjustmentHistory.count > 100 {
                adjustmentHistory.removeFirst()
            }

            currentAllocation = newAllocation
            lastAdjustmentReason = adjustment.reason

            NotificationCenter.default.post(
                name: .resourceAllocationDidChange,
                object: nil,
                userInfo: ["allocation": newAllocation]
            )
        }

        recommendations = generateRecommendations()
    }

    func shouldAdjustAllocation(from old: ResourceAllocation, to new: ResourceAllocation) -> Bool {
        let memoryChange = abs(Double(new.maxModelMemoryBytes) - Double(old.maxModelMemoryBytes))
        let memoryChangePercent = memoryChange / Double(old.maxModelMemoryBytes)
        if memoryChangePercent > 0.1 { return true }
        if new.throttleLevel != old.throttleLevel { return true }
        if new.quantizationLevel != old.quantizationLevel { return true }
        return false
    }

    func generateAdjustmentReason() -> String {
        var reasons: [String] = []

        if systemMetrics.thermalState != .nominal {
            reasons.append("thermal state: \(systemMetrics.thermalState.rawValue)")
        }
        if systemMetrics.memoryPressure != .nominal {
            reasons.append("memory pressure: \(systemMetrics.memoryPressure.rawValue)")
        }
        if !systemMetrics.isCharging && systemMetrics.batteryLevel < 0.5 {
            reasons.append("battery: \(Int(systemMetrics.batteryLevel * 100))%")
        }

        return reasons.isEmpty ? "Routine optimization" : "Adjusted for: " + reasons.joined(separator: ", ")
    }

    func handleThermalStateChange() async {
        await collectMetricsAndAdjust()
    }

    func handleMemoryPressure() async {
        systemMetrics.memoryPressure = getMemoryPressure()

        if systemMetrics.memoryPressure == .critical {
            var emergencyAllocation = currentAllocation
            emergencyAllocation.maxModelMemoryBytes /= 2
            emergencyAllocation.kvCacheSizeBytes /= 2
            emergencyAllocation.recommendedContextLength = min(emergencyAllocation.recommendedContextLength, 2048)
            emergencyAllocation.quantizationLevel = .q4

            let adjustment = ResourceAdjustment(
                reason: "Emergency: Critical memory pressure",
                previous: currentAllocation,
                new: emergencyAllocation,
                metrics: systemMetrics
            )
            adjustmentHistory.append(adjustment)
            currentAllocation = emergencyAllocation
            lastAdjustmentReason = adjustment.reason

            NotificationCenter.default.post(
                name: .resourceAllocationDidChange,
                object: nil,
                userInfo: ["allocation": emergencyAllocation, "emergency": true]
            )
        }
    }
}

// MARK: - Recommendations & Public API

extension DynamicResourceAllocator {
    func generateRecommendations() -> [ResourceRecommendation] {
        var recs: [ResourceRecommendation] = []

        if systemMetrics.thermalState == .serious || systemMetrics.thermalState == .critical {
            recs.append(ResourceRecommendation(
                title: "High Temperature Detected",
                description: "System is running hot. Consider reducing model size or waiting for cooling.",
                impact: .high,
                action: .waitForCooling
            ))
        }

        if systemMetrics.memoryPressure == .warning {
            recs.append(ResourceRecommendation(
                title: "Memory Pressure",
                description: "Available memory is low. Close unused applications for better performance.",
                impact: .medium,
                action: .closeOtherApps
            ))
        }

        if currentAllocation.recommendedContextLength < 4096 && systemMetrics.memoryPressure == .nominal {
            recs.append(ResourceRecommendation(
                title: "Context Length Limited",
                description: "More memory could enable longer context windows.",
                impact: .low,
                action: .reduceContextLength(to: currentAllocation.recommendedContextLength)
            ))
        }

        if !systemMetrics.isCharging && systemMetrics.batteryLevel < 0.2 {
            recs.append(ResourceRecommendation(
                title: "Low Battery",
                description: "Consider plugging in for sustained inference performance.",
                impact: .medium,
                action: .enableThrottling(level: .moderate)
            ))
        }

        return recs
    }

    /// Get optimal model size that can be loaded given current system state
    func getMaxRecommendedModelSizeGB() -> Double {
        currentAllocation.maxModelMemoryGB * 0.8
    }

    /// Check if a model of given size can be loaded
    func canLoadModel(sizeGB: Double) -> Bool {
        sizeGB <= currentAllocation.maxModelMemoryGB
    }

    /// Get recommended settings for a specific model size
    func getSettingsForModel(sizeGB: Double) -> ModelInferenceSettings {
        let canFit = sizeGB <= currentAllocation.maxModelMemoryGB

        return ModelInferenceSettings(
            canLoad: canFit,
            recommendedQuantization: canFit ? currentAllocation.quantizationLevel : .q4,
            recommendedContextLength: canFit ? currentAllocation.recommendedContextLength : 2048,
            recommendedBatchSize: canFit ? currentAllocation.recommendedBatchSize : 1,
            useGPU: canFit && currentAllocation.useGPUAcceleration,
            useNeuralEngine: canFit && currentAllocation.useNeuralEngine,
            estimatedTokensPerSecond: canFit ? currentAllocation.effectiveTokensPerSecond : 0
        )
    }

    /// Force recalculation of allocation
    func recalculateAllocation() async {
        await collectMetricsAndAdjust()
    }
}

// MARK: - Configuration

extension DynamicResourceAllocator {
    func updateConfiguration(_ config: Configuration) {
        configuration = config
        saveConfiguration()

        if config.enableDynamicAllocation && !isMonitoring {
            startMonitoring()
        } else if !config.enableDynamicAllocation && isMonitoring {
            stopMonitoring()
        }

        currentAllocation = calculateOptimalAllocation()
    }

    func loadConfiguration() {
        guard let data = UserDefaults.standard.data(forKey: "DynamicResourceAllocator.config") else { return }
        do {
            configuration = try JSONDecoder().decode(Configuration.self, from: data)
        } catch {
            logger.error("Failed to decode DynamicResourceAllocator configuration: \(error.localizedDescription)")
        }
    }

    func saveConfiguration() {
        do {
            let data = try JSONEncoder().encode(configuration)
            UserDefaults.standard.set(data, forKey: "DynamicResourceAllocator.config")
        } catch {
            logger.error("Failed to encode DynamicResourceAllocator configuration: \(error.localizedDescription)")
        }
    }
}

// Supporting types and notifications are defined in DynamicResourceAllocatorTypes.swift
