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
           let config = try? JSONDecoder().decode(FontConfiguration.self, from: data)
        {
            configuration = config
        } else {
            configuration = FontConfiguration()
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
        case let .custom(name):
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
            case let .custom(name):
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
            case let .custom(name):
                return UIFont(name: name, size: scaledSize) ?? UIFont.systemFont(ofSize: scaledSize)
            }
        }
    #endif

    private func systemFont(size: CGFloat, weight: Font.Weight, design: FontDesign) -> Font {
        let swiftUIDesign: Font.Design = switch design {
        case .default:
            .default
        case .rounded:
            .rounded
        case .serif:
            .serif
        case .monospaced:
            .monospaced
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
        case .system: "System Default"
        case .monospaced: "Monospaced"
        case .rounded: "Rounded"
        case .serif: "Serif"
        case let .custom(name): name
        }
    }

    public static var builtInFamilies: [FontFamily] {
        [.system, .monospaced, .rounded, .serif]
    }
}

// MARK: - Font Design

public enum FontDesign: String, Codable, Sendable, CaseIterable {
    case `default`
    case rounded
    case serif
    case monospaced

    public var displayName: String {
        switch self {
        case .default: "Default"
        case .rounded: "Rounded"
        case .serif: "Serif"
        case .monospaced: "Monospaced"
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
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline: 17
        case .subheadline: 15
        case .body: 17
        case .callout: 16
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        case .code: 14
        case .codeInline: 16
        }
    }

    public var weight: Font.Weight {
        switch self {
        case .largeTitle: .bold
        case .title: .bold
        case .title2: .semibold
        case .title3: .semibold
        case .headline: .semibold
        case .subheadline: .regular
        case .body: .regular
        case .callout: .regular
        case .footnote: .regular
        case .caption: .regular
        case .caption2: .regular
        case .code: .regular
        case .codeInline: .medium
        }
    }

    #if os(macOS)
        public var nsWeight: NSFont.Weight {
            switch self {
            case .largeTitle, .title: .bold
            case .title2, .title3, .headline: .semibold
            case .codeInline: .medium
            default: .regular
            }
        }
    #else
        public var uiWeight: UIFont.Weight {
            switch self {
            case .largeTitle, .title: .bold
            case .title2, .title3, .headline: .semibold
            case .codeInline: .medium
            default: .regular
            }
        }
    #endif

    public var displayName: String {
        switch self {
        case .largeTitle: "Large Title"
        case .title: "Title"
        case .title2: "Title 2"
        case .title3: "Title 3"
        case .headline: "Headline"
        case .subheadline: "Subheadline"
        case .body: "Body"
        case .callout: "Callout"
        case .footnote: "Footnote"
        case .caption: "Caption"
        case .caption2: "Caption 2"
        case .code: "Code"
        case .codeInline: "Inline Code"
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
        font(FontManager.shared.font(style))
    }
}

