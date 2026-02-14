//
//  TheaKeyboardConfiguration.swift
//  Thea
//
//  Configuration for Thea's AI-powered iOS/iPad keyboard.
//  Swiss French QWERTZUIOP layout with bilingual FR/UK support.
//
//  Copyright 2026. All rights reserved.
//

import Foundation

// MARK: - Keyboard Layout

/// Keyboard layout type
public enum KeyboardLayoutType: String, Codable, Sendable, CaseIterable {
    case swissFrench = "swiss_french"  // QWERTZUIOP - Primary
    case french = "french"              // AZERTY
    case english = "english"            // QWERTY
    case german = "german"              // QWERTZ

    public var displayName: String {
        switch self {
        case .swissFrench: "Swiss French (QWERTZUIOP)"
        case .french: "French (AZERTY)"
        case .english: "English (QWERTY)"
        case .german: "German (QWERTZ)"
        }
    }

    public var rows: [[KeyDefinition]] {
        switch self {
        case .swissFrench:
            return SwissFrenchLayout.rows
        case .french:
            return FrenchLayout.rows
        case .english:
            return EnglishLayout.rows
        case .german:
            return GermanLayout.rows
        }
    }
}

/// Definition of a single key
public struct KeyDefinition: Identifiable, Sendable {
    public let id: String
    public let primary: String
    public let shifted: String?
    public let alternates: [String]
    public let width: KeyWidth
    public let type: KeyType

    public enum KeyWidth: Sendable {
        case standard       // 1.0x
        case wide          // 1.25x
        case extraWide     // 1.5x
        case space         // Flexible
        case shift         // 2.0x
        case action        // 1.5x
    }

    public enum KeyType: Sendable {
        case character
        case shift
        case backspace
        case returnKey
        case space
        case switchLayout
        case emoji
        case dictation
        case globe
        case aiAction
    }

    public init(
        primary: String,
        shifted: String? = nil,
        alternates: [String] = [],
        width: KeyWidth = .standard,
        type: KeyType = .character
    ) {
        self.id = primary
        self.primary = primary
        self.shifted = shifted
        self.alternates = alternates
        self.width = width
        self.type = type
    }

    /// Create a special key
    public static func special(_ type: KeyType, label: String, width: KeyWidth = .standard) -> KeyDefinition {
        KeyDefinition(primary: label, width: width, type: type)
    }
}

// MARK: - Swiss French Layout (QWERTZUIOP)

/// Swiss French keyboard layout - QWERTZUIOP
public enum SwissFrenchLayout {
    public static let rows: [[KeyDefinition]] = [
        // Row 1: Numbers (with special characters when shifted)
        [
            KeyDefinition(primary: "1", shifted: "+", alternates: ["¹", "½", "⅓"]),
            KeyDefinition(primary: "2", shifted: "\"", alternates: ["²", "@"]),
            KeyDefinition(primary: "3", shifted: "*", alternates: ["³", "#"]),
            KeyDefinition(primary: "4", shifted: "ç", alternates: ["¼", "$"]),
            KeyDefinition(primary: "5", shifted: "%", alternates: ["‰", "€"]),
            KeyDefinition(primary: "6", shifted: "&", alternates: ["^"]),
            KeyDefinition(primary: "7", shifted: "/", alternates: ["÷"]),
            KeyDefinition(primary: "8", shifted: "(", alternates: ["["]),
            KeyDefinition(primary: "9", shifted: ")", alternates: ["]"]),
            KeyDefinition(primary: "0", shifted: "=", alternates: ["≠", "≈"])
        ],
        // Row 2: QWERTZUIOP
        [
            KeyDefinition(primary: "q", shifted: "Q", alternates: []),
            KeyDefinition(primary: "w", shifted: "W", alternates: []),
            KeyDefinition(primary: "e", shifted: "E", alternates: ["é", "è", "ê", "ë", "€"]),
            KeyDefinition(primary: "r", shifted: "R", alternates: ["®"]),
            KeyDefinition(primary: "t", shifted: "T", alternates: ["™"]),
            KeyDefinition(primary: "z", shifted: "Z", alternates: []),  // Swiss: Z instead of Y
            KeyDefinition(primary: "u", shifted: "U", alternates: ["ù", "û", "ü"]),
            KeyDefinition(primary: "i", shifted: "I", alternates: ["î", "ï", "í"]),
            KeyDefinition(primary: "o", shifted: "O", alternates: ["ô", "ö", "ò", "œ"]),
            KeyDefinition(primary: "p", shifted: "P", alternates: ["π"])
        ],
        // Row 3: ASDFGHJKL
        [
            KeyDefinition(primary: "a", shifted: "A", alternates: ["à", "â", "æ", "á"]),
            KeyDefinition(primary: "s", shifted: "S", alternates: ["ß", "$"]),
            KeyDefinition(primary: "d", shifted: "D", alternates: []),
            KeyDefinition(primary: "f", shifted: "F", alternates: []),
            KeyDefinition(primary: "g", shifted: "G", alternates: []),
            KeyDefinition(primary: "h", shifted: "H", alternates: []),
            KeyDefinition(primary: "j", shifted: "J", alternates: []),
            KeyDefinition(primary: "k", shifted: "K", alternates: []),
            KeyDefinition(primary: "l", shifted: "L", alternates: ["£"]),
            KeyDefinition(primary: "é", shifted: "É", alternates: ["è", "ê", "ë"])  // Swiss French specific
        ],
        // Row 4: Shift + YXCVBNM + Backspace
        [
            KeyDefinition.special(.shift, label: "⇧", width: .shift),
            KeyDefinition(primary: "y", shifted: "Y", alternates: ["¥"]),  // Swiss: Y instead of Z
            KeyDefinition(primary: "x", shifted: "X", alternates: ["×"]),
            KeyDefinition(primary: "c", shifted: "C", alternates: ["ç", "©"]),
            KeyDefinition(primary: "v", shifted: "V", alternates: []),
            KeyDefinition(primary: "b", shifted: "B", alternates: []),
            KeyDefinition(primary: "n", shifted: "N", alternates: ["ñ"]),
            KeyDefinition(primary: "m", shifted: "M", alternates: ["µ"]),
            KeyDefinition.special(.backspace, label: "⌫", width: .wide)
        ],
        // Row 5: Special keys + Space + AI
        [
            KeyDefinition.special(.switchLayout, label: "123", width: .wide),
            KeyDefinition.special(.globe, label: "🌐"),
            KeyDefinition.special(.emoji, label: "😊"),
            KeyDefinition.special(.space, label: "espace", width: .space),
            KeyDefinition.special(.aiAction, label: "✨", width: .action),  // AI Action key
            KeyDefinition.special(.returnKey, label: "⏎", width: .wide)
        ]
    ]
}

// MARK: - French Layout (AZERTY)

public enum FrenchLayout {
    public static let rows: [[KeyDefinition]] = [
        // Row 1: Numbers
        [
            KeyDefinition(primary: "1", shifted: "&"),
            KeyDefinition(primary: "2", shifted: "é", alternates: ["~"]),
            KeyDefinition(primary: "3", shifted: "\"", alternates: ["#"]),
            KeyDefinition(primary: "4", shifted: "'", alternates: ["{"]),
            KeyDefinition(primary: "5", shifted: "(", alternates: ["["]),
            KeyDefinition(primary: "6", shifted: "-", alternates: ["|"]),
            KeyDefinition(primary: "7", shifted: "è", alternates: ["`"]),
            KeyDefinition(primary: "8", shifted: "_", alternates: ["\\"]),
            KeyDefinition(primary: "9", shifted: "ç", alternates: ["^"]),
            KeyDefinition(primary: "0", shifted: "à", alternates: ["@"])
        ],
        // Row 2: AZERTYUIOP
        [
            KeyDefinition(primary: "a", shifted: "A", alternates: ["à", "â", "æ"]),
            KeyDefinition(primary: "z", shifted: "Z", alternates: []),
            KeyDefinition(primary: "e", shifted: "E", alternates: ["é", "è", "ê", "ë", "€"]),
            KeyDefinition(primary: "r", shifted: "R", alternates: []),
            KeyDefinition(primary: "t", shifted: "T", alternates: []),
            KeyDefinition(primary: "y", shifted: "Y", alternates: []),
            KeyDefinition(primary: "u", shifted: "U", alternates: ["ù", "û", "ü"]),
            KeyDefinition(primary: "i", shifted: "I", alternates: ["î", "ï"]),
            KeyDefinition(primary: "o", shifted: "O", alternates: ["ô", "œ"]),
            KeyDefinition(primary: "p", shifted: "P", alternates: [])
        ],
        // Row 3: QSDFGHJKLM
        [
            KeyDefinition(primary: "q", shifted: "Q", alternates: []),
            KeyDefinition(primary: "s", shifted: "S", alternates: []),
            KeyDefinition(primary: "d", shifted: "D", alternates: []),
            KeyDefinition(primary: "f", shifted: "F", alternates: []),
            KeyDefinition(primary: "g", shifted: "G", alternates: []),
            KeyDefinition(primary: "h", shifted: "H", alternates: []),
            KeyDefinition(primary: "j", shifted: "J", alternates: []),
            KeyDefinition(primary: "k", shifted: "K", alternates: []),
            KeyDefinition(primary: "l", shifted: "L", alternates: []),
            KeyDefinition(primary: "m", shifted: "M", alternates: [])
        ],
        // Row 4: Shift + WXCVBN + Backspace
        [
            KeyDefinition.special(.shift, label: "⇧", width: .shift),
            KeyDefinition(primary: "w", shifted: "W", alternates: []),
            KeyDefinition(primary: "x", shifted: "X", alternates: []),
            KeyDefinition(primary: "c", shifted: "C", alternates: ["ç"]),
            KeyDefinition(primary: "v", shifted: "V", alternates: []),
            KeyDefinition(primary: "b", shifted: "B", alternates: []),
            KeyDefinition(primary: "n", shifted: "N", alternates: []),
            KeyDefinition.special(.backspace, label: "⌫", width: .wide)
        ],
        // Row 5: Special keys
        [
            KeyDefinition.special(.switchLayout, label: "123", width: .wide),
            KeyDefinition.special(.globe, label: "🌐"),
            KeyDefinition.special(.emoji, label: "😊"),
            KeyDefinition.special(.space, label: "espace", width: .space),
            KeyDefinition.special(.aiAction, label: "✨", width: .action),
            KeyDefinition.special(.returnKey, label: "⏎", width: .wide)
        ]
    ]
}

// MARK: - English Layout (QWERTY)

public enum EnglishLayout {
    public static let rows: [[KeyDefinition]] = [
        // Row 1
        [
            KeyDefinition(primary: "q", shifted: "Q"),
            KeyDefinition(primary: "w", shifted: "W"),
            KeyDefinition(primary: "e", shifted: "E"),
            KeyDefinition(primary: "r", shifted: "R"),
            KeyDefinition(primary: "t", shifted: "T"),
            KeyDefinition(primary: "y", shifted: "Y"),
            KeyDefinition(primary: "u", shifted: "U"),
            KeyDefinition(primary: "i", shifted: "I"),
            KeyDefinition(primary: "o", shifted: "O"),
            KeyDefinition(primary: "p", shifted: "P")
        ],
        // Row 2
        [
            KeyDefinition(primary: "a", shifted: "A"),
            KeyDefinition(primary: "s", shifted: "S"),
            KeyDefinition(primary: "d", shifted: "D"),
            KeyDefinition(primary: "f", shifted: "F"),
            KeyDefinition(primary: "g", shifted: "G"),
            KeyDefinition(primary: "h", shifted: "H"),
            KeyDefinition(primary: "j", shifted: "J"),
            KeyDefinition(primary: "k", shifted: "K"),
            KeyDefinition(primary: "l", shifted: "L")
        ],
        // Row 3
        [
            KeyDefinition.special(.shift, label: "⇧", width: .shift),
            KeyDefinition(primary: "z", shifted: "Z"),
            KeyDefinition(primary: "x", shifted: "X"),
            KeyDefinition(primary: "c", shifted: "C"),
            KeyDefinition(primary: "v", shifted: "V"),
            KeyDefinition(primary: "b", shifted: "B"),
            KeyDefinition(primary: "n", shifted: "N"),
            KeyDefinition(primary: "m", shifted: "M"),
            KeyDefinition.special(.backspace, label: "⌫", width: .wide)
        ],
        // Row 4
        [
            KeyDefinition.special(.switchLayout, label: "123", width: .wide),
            KeyDefinition.special(.globe, label: "🌐"),
            KeyDefinition.special(.emoji, label: "😊"),
            KeyDefinition.special(.space, label: "space", width: .space),
            KeyDefinition.special(.aiAction, label: "✨", width: .action),
            KeyDefinition.special(.returnKey, label: "return", width: .wide)
        ]
    ]
}

// MARK: - German Layout (QWERTZ)

public enum GermanLayout {
    public static let rows: [[KeyDefinition]] = [
        // Row 1
        [
            KeyDefinition(primary: "q", shifted: "Q"),
            KeyDefinition(primary: "w", shifted: "W"),
            KeyDefinition(primary: "e", shifted: "E", alternates: ["é", "è", "ê"]),
            KeyDefinition(primary: "r", shifted: "R"),
            KeyDefinition(primary: "t", shifted: "T"),
            KeyDefinition(primary: "z", shifted: "Z"),
            KeyDefinition(primary: "u", shifted: "U", alternates: ["ü"]),
            KeyDefinition(primary: "i", shifted: "I"),
            KeyDefinition(primary: "o", shifted: "O", alternates: ["ö"]),
            KeyDefinition(primary: "p", shifted: "P")
        ],
        // Row 2
        [
            KeyDefinition(primary: "a", shifted: "A", alternates: ["ä"]),
            KeyDefinition(primary: "s", shifted: "S", alternates: ["ß"]),
            KeyDefinition(primary: "d", shifted: "D"),
            KeyDefinition(primary: "f", shifted: "F"),
            KeyDefinition(primary: "g", shifted: "G"),
            KeyDefinition(primary: "h", shifted: "H"),
            KeyDefinition(primary: "j", shifted: "J"),
            KeyDefinition(primary: "k", shifted: "K"),
            KeyDefinition(primary: "l", shifted: "L"),
            KeyDefinition(primary: "ü", shifted: "Ü")
        ],
        // Row 3
        [
            KeyDefinition.special(.shift, label: "⇧", width: .shift),
            KeyDefinition(primary: "y", shifted: "Y"),
            KeyDefinition(primary: "x", shifted: "X"),
            KeyDefinition(primary: "c", shifted: "C"),
            KeyDefinition(primary: "v", shifted: "V"),
            KeyDefinition(primary: "b", shifted: "B"),
            KeyDefinition(primary: "n", shifted: "N"),
            KeyDefinition(primary: "m", shifted: "M"),
            KeyDefinition.special(.backspace, label: "⌫", width: .wide)
        ],
        // Row 4
        [
            KeyDefinition.special(.switchLayout, label: "123", width: .wide),
            KeyDefinition.special(.globe, label: "🌐"),
            KeyDefinition.special(.emoji, label: "😊"),
            KeyDefinition.special(.space, label: "Leerzeichen", width: .space),
            KeyDefinition.special(.aiAction, label: "✨", width: .action),
            KeyDefinition.special(.returnKey, label: "⏎", width: .wide)
        ]
    ]
}

// MARK: - Keyboard Configuration

/// Configuration for the Thea keyboard
public struct TheaKeyboardConfiguration: Codable, Sendable {
    /// Primary keyboard layout
    public var primaryLayout: KeyboardLayoutType

    /// Secondary layout for quick switching
    public var secondaryLayout: KeyboardLayoutType?

    /// Primary language for predictions and autocorrect
    public var primaryLanguage: KeyboardLanguage

    /// Secondary language for bilingual support
    public var secondaryLanguage: KeyboardLanguage?

    /// Whether bilingual mode is active
    public var bilingualModeEnabled: Bool

    /// AI features configuration
    public var aiFeatures: AIFeaturesConfig

    /// Haptic feedback settings
    public var haptics: HapticsConfig

    /// Appearance settings
    public var appearance: AppearanceConfig

    public init(
        primaryLayout: KeyboardLayoutType = .swissFrench,
        secondaryLayout: KeyboardLayoutType? = .english,
        primaryLanguage: KeyboardLanguage = .french,
        secondaryLanguage: KeyboardLanguage? = .english,
        bilingualModeEnabled: Bool = true,
        aiFeatures: AIFeaturesConfig = AIFeaturesConfig(),
        haptics: HapticsConfig = HapticsConfig(),
        appearance: AppearanceConfig = AppearanceConfig()
    ) {
        self.primaryLayout = primaryLayout
        self.secondaryLayout = secondaryLayout
        self.primaryLanguage = primaryLanguage
        self.secondaryLanguage = secondaryLanguage
        self.bilingualModeEnabled = bilingualModeEnabled
        self.aiFeatures = aiFeatures
        self.haptics = haptics
        self.appearance = appearance
    }
}

/// Supported keyboard languages
public enum KeyboardLanguage: String, Codable, Sendable, CaseIterable {
    case english = "en"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case spanish = "es"

    public var displayName: String {
        switch self {
        case .english: "English"
        case .french: "Français"
        case .german: "Deutsch"
        case .italian: "Italiano"
        case .spanish: "Español"
        }
    }

    public var locale: Locale {
        Locale(identifier: rawValue)
    }
}

/// AI features configuration
public struct AIFeaturesConfig: Codable, Sendable {
    /// Enable AI-powered text predictions
    public var predictionsEnabled: Bool = true

    /// Enable smart autocorrect
    public var autocorrectEnabled: Bool = true

    /// Enable context-aware suggestions
    public var contextAwareEnabled: Bool = true

    /// Enable AI text transformation (rewrite, summarize, etc.)
    public var textTransformEnabled: Bool = true

    /// Enable smart replies
    public var smartRepliesEnabled: Bool = true

    /// Enable grammar checking
    public var grammarCheckEnabled: Bool = true

    /// Enable translation suggestions
    public var translationEnabled: Bool = true

    /// Maximum predictions to show
    public var maxPredictions: Int = 3

    public init() {}
}

/// Haptics configuration
public struct HapticsConfig: Codable, Sendable {
    /// Enable haptic feedback on key press
    public var keyPressEnabled: Bool = true

    /// Haptic intensity (0.0 - 1.0)
    public var intensity: Double = 0.5

    /// Enable audio feedback
    public var audioEnabled: Bool = false

    public init() {}
}

/// Appearance configuration
public struct AppearanceConfig: Codable, Sendable {
    /// Keyboard theme
    public var theme: KeyboardTheme = .system

    /// Key corner radius
    public var keyCornerRadius: Double = 5.0

    /// Show key borders
    public var showKeyBorders: Bool = true

    /// Key font size
    public var fontSize: KeyFontSize = .medium

    /// Show key alternates popup on long press
    public var showAlternatesPopup: Bool = true

    public init() {}
}

/// Keyboard theme
public enum KeyboardTheme: String, Codable, Sendable, CaseIterable {
    case system
    case light
    case dark
    case theaAccent  // Uses Thea's brand colors

    public var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        case .theaAccent: "Thea Accent"
        }
    }
}

/// Key font size
public enum KeyFontSize: String, Codable, Sendable, CaseIterable {
    case small
    case medium
    case large
    case extraLarge

    public var pointSize: Double {
        switch self {
        case .small: 18
        case .medium: 22
        case .large: 26
        case .extraLarge: 30
        }
    }
}
