//
//  LocalModelRecommendationEngine+Hardware.swift
//  Thea
//
//  System hardware detection for AI-powered recommendations
//  Extracted from LocalModelRecommendationEngine.swift for better code organization
//

import Foundation
#if os(macOS)
import IOKit.ps
#elseif os(iOS) || os(watchOS) || os(tvOS)
import UIKit
#endif

// MARK: - System Hardware Detection (AI-Powered)

extension LocalModelRecommendationEngine {
    /// Detect and profile the system hardware for optimal model recommendations
    func detectSystemHardware() async {
        let memory = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(memory) / 1_073_741_824
        let cpuCores = ProcessInfo.processInfo.processorCount

        // Detect Apple Silicon chip type
        let chipType = detectAppleSiliconChip()

        // Estimate Neural Engine and GPU capabilities
        let neuralEngineCapability = estimateNeuralEngineCapability(chip: chipType)
        let gpuCores = estimateGPUCores(chip: chipType)

        systemProfile = SystemHardwareProfile(
            totalMemoryGB: memoryGB,
            cpuCores: cpuCores,
            chipType: chipType,
            gpuCores: gpuCores,
            neuralEngineCapability: neuralEngineCapability,
            thermalState: .nominal as LocalThermalState,
            batteryPowered: detectBatteryPower()
        )

        print("[LocalModelRecommendationEngine] System profile: \(memoryGB)GB RAM, \(chipType.rawValue), \(gpuCores) GPU cores, Neural Engine: \(neuralEngineCapability.rawValue)")
    }

    /// Apply AI-powered defaults based on detected system capabilities
    func applySystemAwareDefaults() async {
        guard configuration.autoAdjustToSystemCapabilities,
              let profile = systemProfile else { return }

        // Calculate optimal max model size based on available RAM
        // Reserve ~30% of RAM for system and ~20% for app overhead
        // Only ~50% of RAM should be used for model weights
        let effectiveRAM = profile.totalMemoryGB * 0.5

        let tier: Configuration.PerformanceTier
        let maxSize: Double

        switch profile.totalMemoryGB {
        case 0..<12:
            tier = .ultralight
            maxSize = min(effectiveRAM, 3.0)
        case 12..<24:
            tier = .light
            maxSize = min(effectiveRAM, 5.0)
        case 24..<48:
            tier = .standard
            maxSize = min(effectiveRAM, 10.0)
        case 48..<96:
            tier = .performance
            maxSize = min(effectiveRAM, 20.0)
        case 96..<192:
            tier = .extreme
            maxSize = min(effectiveRAM, 50.0)
        case 192..<384:
            // 192GB-384GB RAM systems (e.g., M2 Ultra, M3 Ultra, M4 Ultra with 192GB)
            tier = .unlimited
            maxSize = min(effectiveRAM, 150.0)
        case 384..<768:
            // 384GB-768GB RAM systems (future high-end workstations)
            tier = .unlimited
            maxSize = min(effectiveRAM, 300.0)
        default:
            // 768GB+ RAM systems (future extreme systems)
            tier = .unlimited
            maxSize = effectiveRAM // No cap - use all available
        }

        // Apply the calculated defaults if not manually overridden
        if configuration.performanceTier == .auto {
            configuration.maxModelSizeGB = maxSize
            print("[LocalModelRecommendationEngine] AI-selected tier: \(tier.displayName), max model size: \(String(format: "%.1f", maxSize))GB")
        } else {
            // User has manually selected a tier
            configuration.maxModelSizeGB = configuration.performanceTier.maxModelSizeGB
        }

        // Adjust quantization preference based on memory
        if profile.totalMemoryGB < 16 {
            configuration.preferredQuantization = "4bit"
        } else if profile.totalMemoryGB < 64 {
            configuration.preferredQuantization = "4bit" // Still prefer 4bit for efficiency
        } else {
            configuration.preferredQuantization = "8bit" // Can afford higher precision
        }

        saveConfiguration()
    }

    func detectAppleSiliconChip() -> AppleSiliconChip {
        #if os(macOS)
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var brand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
        // Convert C string to Swift String using modern API (avoids deprecated init(cString:))
        let cpuBrand: String
        if let nullIndex = brand.firstIndex(of: 0) {
            cpuBrand = String(decoding: brand[..<nullIndex].map { UInt8(bitPattern: $0) }, as: UTF8.self).lowercased()
        } else {
            cpuBrand = String(decoding: brand.map { UInt8(bitPattern: $0) }, as: UTF8.self).lowercased()
        }

        if cpuBrand.contains("m4 ultra") { return .m4Ultra }
        if cpuBrand.contains("m4 max") { return .m4Max }
        if cpuBrand.contains("m4 pro") { return .m4Pro }
        if cpuBrand.contains("m4") { return .m4 }
        if cpuBrand.contains("m3 ultra") { return .m3Ultra }
        if cpuBrand.contains("m3 max") { return .m3Max }
        if cpuBrand.contains("m3 pro") { return .m3Pro }
        if cpuBrand.contains("m3") { return .m3 }
        if cpuBrand.contains("m2 ultra") { return .m2Ultra }
        if cpuBrand.contains("m2 max") { return .m2Max }
        if cpuBrand.contains("m2 pro") { return .m2Pro }
        if cpuBrand.contains("m2") { return .m2 }
        if cpuBrand.contains("m1 ultra") { return .m1Ultra }
        if cpuBrand.contains("m1 max") { return .m1Max }
        if cpuBrand.contains("m1 pro") { return .m1Pro }
        if cpuBrand.contains("m1") { return .m1 }
        return .unknown
        #elseif os(iOS)
        return detectIOSChip()
        #elseif os(watchOS)
        return .unknown // watchOS chips are different (S-series)
        #elseif os(tvOS)
        return detectTVOSChip()
        #else
        return .unknown
        #endif
    }

    #if os(iOS)
    func detectIOSChip() -> AppleSiliconChip {
        // Detect A-series and M-series chips in iPads/iPhones via RAM + cores
        let memoryGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        let cores = ProcessInfo.processInfo.processorCount

        // iPad Pro M4 (2024): 8GB-16GB RAM, 9-10 cores
        // iPad Pro M2 (2022): 8GB-16GB RAM, 8 cores
        // iPad Pro M1 (2021): 8GB-16GB RAM, 8 cores
        // iPhone 16 Pro: A18 Pro, 8GB RAM, 6 cores
        // iPhone 15 Pro: A17 Pro, 8GB RAM, 6 cores

        if memoryGB >= 12 && cores >= 9 { return .m4 }
        if memoryGB >= 8 && cores >= 8 { return .m2 }
        if memoryGB >= 6 && cores >= 6 { return .a17Pro }
        if memoryGB >= 6 { return .a16 }
        return .unknown
    }
    #endif

    #if os(tvOS)
    func detectTVOSChip() -> AppleSiliconChip {
        // Apple TV chips
        let cores = ProcessInfo.processInfo.processorCount
        if cores >= 6 { return .a15 }
        return .unknown
    }
    #endif

    func estimateNeuralEngineCapability(chip: AppleSiliconChip) -> NeuralEngineCapability {
        switch chip {
        case .m4Ultra, .m4Max, .m4Pro, .m4, .a18Pro, .a18:
            .generation5 // 38 TOPS (M4), 35 TOPS (A18)
        case .m3Ultra, .m3Max, .m3Pro, .m3, .a17Pro:
            .generation4 // 18 TOPS (M3), 35 TOPS (A17 Pro)
        case .m2Ultra, .m2Max, .m2Pro, .m2, .a16:
            .generation3 // 15.8 TOPS
        case .m1Ultra, .m1Max, .m1Pro, .m1, .a15:
            .generation2 // 11 TOPS (M1), 15.8 TOPS (A15)
        case .a14:
            .generation2 // 11 TOPS
        case .s9, .s10:
            .generation4 // S9/S10 have capable Neural Engines
        case .unknown:
            .unknown
        }
    }

    func estimateGPUCores(chip: AppleSiliconChip) -> Int {
        switch chip {
        // M-series (Mac)
        case .m4Ultra: 80
        case .m4Max: 40
        case .m4Pro: 20
        case .m4: 10
        case .m3Ultra: 76
        case .m3Max: 40
        case .m3Pro: 18
        case .m3: 10
        case .m2Ultra: 76
        case .m2Max: 38
        case .m2Pro: 19
        case .m2: 10
        case .m1Ultra: 64
        case .m1Max: 32
        case .m1Pro: 16
        case .m1: 8
        // A-series (iPhone/iPad)
        case .a18Pro: 6
        case .a18: 5
        case .a17Pro: 6
        case .a16: 5
        case .a15: 5
        case .a14: 4
        // S-series (Watch)
        case .s9, .s10: 4
        case .unknown: 4
        }
    }

    func detectBatteryPower() -> Bool {
        #if os(macOS)
        // Check if running on battery
        let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        guard let firstSource = sources?.first else { return false }
        let description = IOPSGetPowerSourceDescription(snapshot, firstSource)?.takeUnretainedValue() as? [String: Any]
        return description?[kIOPSPowerSourceStateKey as String] as? String == kIOPSBatteryPowerValue
        #elseif os(iOS) || os(watchOS)
        // iOS/watchOS devices are always battery-powered unless plugged in
        // UIDevice.current.batteryState requires monitoring
        return true // Conservative assumption
        #elseif os(tvOS)
        return false // Apple TV is always plugged in
        #else
        return true
        #endif
    }
}
