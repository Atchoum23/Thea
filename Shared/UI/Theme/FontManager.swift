//
//  FontManager.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: - Font Manager

/// Centralized font management system with dynamic scaling and family selection
@MainActor
@Observable
public final class FontManager {
    public static let shared = FontManager()

    private let defaults = UserDefaults.standard
    private let configKey = "FontManager.configuration"

    // MARK: - Configuration

    public var configuration: FontConfiguration {
        didSet {
            saveConfiguration()
            notifyFontChanged()
        }
    }

    // MARK: - Initialization

    private init() {
        if let data = defaults.data(forKey: configKey),
           let config = try? JSONDecoder().decode(FontConfiguration.self, from: data) {
            self.configuration = config
        } else {
            self.configuration = FontConfiguration()
        }
    }

    // MARK: - Persistence

    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            defaults.set(data, forKey: configKey)
        }
    }

    // MARK: - Notifications

    private func notifyFontChanged() {
        NotificationCenter.default.post(name: .fontConfigurationDidChange, object: nil)
    }

    // MARK: - Font Generation

    /// Get a font with the current configuration applied
    public func font(_ style: FontStyle) -> Font {
        let baseSize = style.baseSize
        let scaledSize = baseSize * configuration.scaleFactor

        switch configuration.fontFamily {
        case .system:
            return systemFont(size: scaledSize, weight: style.weight, design: configuration.fontDesign)
        case .monospaced:
            return .system(size: scaledSize, weight: style.weight, design: .monospaced)
        case .rounded:
            return .system(size: scaledSize, weight: style.weight, design: .rounded)
        case .serif:
            return .system(size: scaledSize, weight: style.weight, design: .serif)
        case .custom(let name):
            return .custom(name, size: scaledSize)
        }
    }

    /// Get a UIFont/NSFont with the current configuration applied
    #if os(macOS)
    public func platformFont(_ style: FontStyle) -> NSFont {
        let baseSize = style.baseSize
        let scaledSize = baseSize * configuration.scaleFactor

        switch configuration.fontFamily {
        case .system, .rounded, .serif:
            return NSFont.systemFont(ofSize: scaledSize, weight: style.nsWeight)
        case .monospaced:
            return NSFont.monospacedSystemFont(ofSize: scaledSize, weight: style.nsWeight)
        case .custom(let name):
            return NSFont(name: name, size: scaledSize) ?? NSFont.systemFont(ofSize: scaledSize)
        }
    }
    #else
    public func platformFont(_ style: FontStyle) -> UIFont {
        let baseSize = style.baseSize
        let scaledSize = baseSize * configuration.scaleFactor

        switch configuration.fontFamily {
        case .system, .rounded, .serif:
            return UIFont.systemFont(ofSize: scaledSize, weight: style.uiWeight)
        case .monospaced:
            return UIFont.monospacedSystemFont(ofSize: scaledSize, weight: style.uiWeight)
        case .custom(let name):
            return UIFont(name: name, size: scaledSize) ?? UIFont.systemFont(ofSize: scaledSize)
        }
    }
    #endif

    private func systemFont(size: CGFloat, weight: Font.Weight, design: FontDesign) -> Font {
        let swiftUIDesign: Font.Design
        switch design {
        case .default:
            swiftUIDesign = .default
        case .rounded:
            swiftUIDesign = .rounded
        case .serif:
            swiftUIDesign = .serif
        case .monospaced:
            swiftUIDesign = .monospaced
        }
        return .system(size: size, weight: weight, design: swiftUIDesign)
    }

    // MARK: - Available Fonts

    /// Get list of available system fonts
    #if os(macOS)
    public var availableFonts: [String] {
        NSFontManager.shared.availableFontFamilies.sorted()
    }
    #else
    public var availableFonts: [String] {
        UIFont.familyNames.sorted()
    }
    #endif

    // MARK: - Reset

    public func resetToDefaults() {
        configuration = FontConfiguration()
    }
}

// MARK: - Font Configuration

public struct FontConfiguration: Codable, Sendable, Equatable {
    /// Font family selection
    public var fontFamily: FontFamily = .system

    /// Font design (default, rounded, serif, monospaced)
    public var fontDesign: FontDesign = .default

    /// Scale factor (0.8 to 2.0)
    public var scaleFactor: CGFloat = 1.0

    /// Enable dynamic type scaling
    public var useDynamicType: Bool = true

    /// Line spacing multiplier
    public var lineSpacingMultiplier: CGFloat = 1.0

    /// Letter spacing adjustment
    public var letterSpacing: CGFloat = 0.0

    public init(
        fontFamily: FontFamily = .system,
        fontDesign: FontDesign = .default,
        scaleFactor: CGFloat = 1.0,
        useDynamicType: Bool = true,
        lineSpacingMultiplier: CGFloat = 1.0,
        letterSpacing: CGFloat = 0.0
    ) {
        self.fontFamily = fontFamily
        self.fontDesign = fontDesign
        self.scaleFactor = Swift.min(2.0, Swift.max(0.8, scaleFactor))
        self.useDynamicType = useDynamicType
        self.lineSpacingMultiplier = lineSpacingMultiplier
        self.letterSpacing = letterSpacing
    }
}

// MARK: - Font Family

public enum FontFamily: Codable, Sendable, Equatable, Hashable {
    case system
    case monospaced
    case rounded
    case serif
    case custom(String)

    public var displayName: String {
        switch self {
        case .system: return "System Default"
        case .monospaced: return "Monospaced"
        case .rounded: return "Rounded"
        case .serif: return "Serif"
        case .custom(let name): return name
        }
    }

    public static var builtInFamilies: [FontFamily] {
        [.system, .monospaced, .rounded, .serif]
    }
}

// MARK: - Font Design

public enum FontDesign: String, Codable, Sendable, CaseIterable {
    case `default` = "default"
    case rounded = "rounded"
    case serif = "serif"
    case monospaced = "monospaced"

    public var displayName: String {
        switch self {
        case .default: return "Default"
        case .rounded: return "Rounded"
        case .serif: return "Serif"
        case .monospaced: return "Monospaced"
        }
    }
}

// MARK: - Font Style

public enum FontStyle: String, CaseIterable, Sendable {
    case largeTitle
    case title
    case title2
    case title3
    case headline
    case subheadline
    case body
    case callout
    case footnote
    case caption
    case caption2
    case code
    case codeInline

    public var baseSize: CGFloat {
        switch self {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline: return 17
        case .subheadline: return 15
        case .body: return 17
        case .callout: return 16
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        case .code: return 14
        case .codeInline: return 16
        }
    }

    public var weight: Font.Weight {
        switch self {
        case .largeTitle: return .bold
        case .title: return .bold
        case .title2: return .semibold
        case .title3: return .semibold
        case .headline: return .semibold
        case .subheadline: return .regular
        case .body: return .regular
        case .callout: return .regular
        case .footnote: return .regular
        case .caption: return .regular
        case .caption2: return .regular
        case .code: return .regular
        case .codeInline: return .medium
        }
    }

    #if os(macOS)
    public var nsWeight: NSFont.Weight {
        switch self {
        case .largeTitle, .title: return .bold
        case .title2, .title3, .headline: return .semibold
        case .codeInline: return .medium
        default: return .regular
        }
    }
    #else
    public var uiWeight: UIFont.Weight {
        switch self {
        case .largeTitle, .title: return .bold
        case .title2, .title3, .headline: return .semibold
        case .codeInline: return .medium
        default: return .regular
        }
    }
    #endif

    public var displayName: String {
        switch self {
        case .largeTitle: return "Large Title"
        case .title: return "Title"
        case .title2: return "Title 2"
        case .title3: return "Title 3"
        case .headline: return "Headline"
        case .subheadline: return "Subheadline"
        case .body: return "Body"
        case .callout: return "Callout"
        case .footnote: return "Footnote"
        case .caption: return "Caption"
        case .caption2: return "Caption 2"
        case .code: return "Code"
        case .codeInline: return "Inline Code"
        }
    }
}

// MARK: - Notification Extension

public extension Notification.Name {
    static let fontConfigurationDidChange = Notification.Name("fontConfigurationDidChange")
}

// MARK: - View Extension

public extension View {
    /// Apply themed font from FontManager
    func themedFont(_ style: FontStyle) -> some View {
        self.font(FontManager.shared.font(style))
    }
}

// MARK: - Environment Key

private struct FontManagerKey: @preconcurrency EnvironmentKey {
    @MainActor static var defaultValue: FontManager { FontManager.shared }
}

public extension EnvironmentValues {
    @MainActor
    var fontManager: FontManager {
        get { self[FontManagerKey.self] }
        set { self[FontManagerKey.self] = newValue }
    }
}
