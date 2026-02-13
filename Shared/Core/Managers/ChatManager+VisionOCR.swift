import Foundation
import os.log

#if canImport(AppKit)
    import AppKit
#elseif canImport(UIKit)
    import UIKit
#endif

private let ocrLogger = Logger(subsystem: "ai.thea.app", category: "ChatManager+VisionOCR")

// MARK: - Vision OCR for Image Attachments

extension ChatManager {

    // MARK: - Device Context for AI

    /// Builds a device-aware context supplement for the system prompt.
    /// Tells the AI which device the user is currently on and which devices are in the ecosystem.
    func buildDeviceContextPrompt() -> String {
        let current = DeviceRegistry.shared.currentDevice
        let allDevices = DeviceRegistry.shared.registeredDevices
        let onlineDevices = DeviceRegistry.shared.onlineDevices

        var lines: [String] = []
        lines.append("DEVICE CONTEXT:")
        lines.append("- Current device: \(current.name) (\(current.type.displayName), \(current.osVersion))")

        if current.capabilities.supportsLocalModels {
            lines.append("- This device supports local AI models")
        }

        #if os(macOS)
        let totalRAM = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)
        lines.append("- RAM: \(totalRAM) GB")
        #endif

        if allDevices.count > 1 {
            let others = allDevices.filter { $0.id != current.id }
            let otherNames = others.map { device in
                let status = onlineDevices.contains { $0.id == device.id } ? "online" : "offline"
                return "\(device.name) (\(device.type.displayName), \(status))"
            }
            lines.append("- Other devices in ecosystem: \(otherNames.joined(separator: ", "))")
        }

        lines.append("- User prompts from this conversation may originate from different devices (check message context).")

        return lines.joined(separator: "\n")
    }

    #if os(macOS) || os(iOS)
    /// Extracts text from image parts in a multimodal message using VisionOCR.
    func extractOCRFromImageParts(_ parts: [ContentPart]) async -> [String] {
        var ocrTexts: [String] = []
        for part in parts {
            if case let .image(imageData) = part.type {
                guard let cgImage = Self.cgImageFromData(imageData) else { continue }
                do {
                    let text = try await VisionOCR.shared.extractAllText(from: cgImage)
                    if !text.isEmpty {
                        ocrTexts.append(text)
                    }
                } catch {
                    ocrLogger.debug("VisionOCR failed for image attachment: \(error.localizedDescription)")
                }
            }
        }
        return ocrTexts
    }

    static func cgImageFromData(_ data: Data) -> CGImage? {
        #if canImport(AppKit)
        guard let nsImage = NSImage(data: data), let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return cgImage
        #elseif canImport(UIKit)
        guard let uiImage = UIImage(data: data), let cgImage = uiImage.cgImage else {
            return nil
        }
        return cgImage
        #else
        return nil
        #endif
    }
    #endif
}
