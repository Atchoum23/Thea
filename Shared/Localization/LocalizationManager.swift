// LocalizationManager.swift
// Comprehensive internationalization and localization system

import Combine
import Foundation
import OSLog

// MARK: - Localization Manager

/// Manages app localization, translations, and locale-specific formatting
@MainActor
public final class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()

    private let logger = Logger(subsystem: "com.thea.app", category: "Localization")

    // MARK: - Published State

    @Published public private(set) var currentLocale: Locale
    @Published public private(set) var currentLanguage: Language
    @Published public private(set) var supportedLanguages: [Language] = []
    @Published public private(set) var isRTL: Bool = false
    @Published public private(set) var loadedBundles: [String: Bundle] = [:]

    // MARK: - Formatters

    public private(set) var dateFormatter: DateFormatter
    public private(set) var timeFormatter: DateFormatter
    public private(set) var numberFormatter: NumberFormatter
    public private(set) var currencyFormatter: NumberFormatter
    public private(set) var percentFormatter: NumberFormatter
    public private(set) var measurementFormatter: MeasurementFormatter
    public private(set) var listFormatter: ListFormatter
    public private(set) var relativeFormatter: RelativeDateTimeFormatter

    // MARK: - String Tables

    private var stringTables: [String: [String: String]] = [:]

    // MARK: - Initialization

    private init() {
        currentLocale = Locale.current
        currentLanguage = Language(code: Locale.current.language.languageCode?.identifier ?? "en")

        // Initialize formatters
        dateFormatter = DateFormatter()
        timeFormatter = DateFormatter()
        numberFormatter = NumberFormatter()
        currencyFormatter = NumberFormatter()
        percentFormatter = NumberFormatter()
        measurementFormatter = MeasurementFormatter()
        listFormatter = ListFormatter()
        relativeFormatter = RelativeDateTimeFormatter()

        setupFormatters()
        loadSupportedLanguages()
        detectLayoutDirection()
    }

    // MARK: - Setup

    private func setupFormatters() {
        dateFormatter.locale = currentLocale
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        timeFormatter.locale = currentLocale
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        numberFormatter.locale = currentLocale
        numberFormatter.numberStyle = .decimal

        currencyFormatter.locale = currentLocale
        currencyFormatter.numberStyle = .currency

        percentFormatter.locale = currentLocale
        percentFormatter.numberStyle = .percent
        percentFormatter.maximumFractionDigits = 1

        measurementFormatter.locale = currentLocale
        measurementFormatter.unitOptions = .naturalScale

        listFormatter.locale = currentLocale

        relativeFormatter.locale = currentLocale
        relativeFormatter.unitsStyle = .full
    }

    private func loadSupportedLanguages() {
        supportedLanguages = [
            Language(code: "en", name: "English", nativeName: "English", isRTL: false),
            Language(code: "es", name: "Spanish", nativeName: "Español", isRTL: false),
            Language(code: "fr", name: "French", nativeName: "Français", isRTL: false),
            Language(code: "de", name: "German", nativeName: "Deutsch", isRTL: false),
            Language(code: "it", name: "Italian", nativeName: "Italiano", isRTL: false),
            Language(code: "pt", name: "Portuguese", nativeName: "Português", isRTL: false),
            Language(code: "pt-BR", name: "Portuguese (Brazil)", nativeName: "Português (Brasil)", isRTL: false),
            Language(code: "zh-Hans", name: "Chinese (Simplified)", nativeName: "简体中文", isRTL: false),
            Language(code: "zh-Hant", name: "Chinese (Traditional)", nativeName: "繁體中文", isRTL: false),
            Language(code: "ja", name: "Japanese", nativeName: "日本語", isRTL: false),
            Language(code: "ko", name: "Korean", nativeName: "한국어", isRTL: false),
            Language(code: "ar", name: "Arabic", nativeName: "العربية", isRTL: true),
            Language(code: "he", name: "Hebrew", nativeName: "עברית", isRTL: true),
            Language(code: "ru", name: "Russian", nativeName: "Русский", isRTL: false),
            Language(code: "uk", name: "Ukrainian", nativeName: "Українська", isRTL: false),
            Language(code: "pl", name: "Polish", nativeName: "Polski", isRTL: false),
            Language(code: "nl", name: "Dutch", nativeName: "Nederlands", isRTL: false),
            Language(code: "sv", name: "Swedish", nativeName: "Svenska", isRTL: false),
            Language(code: "da", name: "Danish", nativeName: "Dansk", isRTL: false),
            Language(code: "fi", name: "Finnish", nativeName: "Suomi", isRTL: false),
            Language(code: "no", name: "Norwegian", nativeName: "Norsk", isRTL: false),
            Language(code: "tr", name: "Turkish", nativeName: "Türkçe", isRTL: false),
            Language(code: "th", name: "Thai", nativeName: "ไทย", isRTL: false),
            Language(code: "vi", name: "Vietnamese", nativeName: "Tiếng Việt", isRTL: false),
            Language(code: "id", name: "Indonesian", nativeName: "Bahasa Indonesia", isRTL: false),
            Language(code: "ms", name: "Malay", nativeName: "Bahasa Melayu", isRTL: false),
            Language(code: "hi", name: "Hindi", nativeName: "हिन्दी", isRTL: false),
            Language(code: "bn", name: "Bengali", nativeName: "বাংলা", isRTL: false)
        ]
    }

    private func detectLayoutDirection() {
        let language = Locale.Language(identifier: currentLanguage.code)
        isRTL = language.characterDirection == .rightToLeft
    }

    // MARK: - Language Switching

    /// Change the app language
    public func setLanguage(_ language: Language) {
        guard supportedLanguages.contains(where: { $0.code == language.code }) else {
            logger.warning("Unsupported language: \(language.code)")
            return
        }

        currentLanguage = language
        currentLocale = Locale(identifier: language.code)
        isRTL = language.isRTL

        setupFormatters()
        loadStringTable(for: language.code)

        // Persist preference
        UserDefaults.standard.set([language.code], forKey: "AppleLanguages")
        UserDefaults.standard.set(language.code, forKey: "thea.preferredLanguage")

        // Post notification for UI updates
        NotificationCenter.default.post(name: .languageDidChange, object: language)

        logger.info("Language changed to: \(language.code)")
    }

    /// Get system preferred language
    public func getSystemLanguage() -> Language {
        let preferredLanguages = Locale.preferredLanguages
        if let firstPreferred = preferredLanguages.first {
            let code = String(firstPreferred.prefix(2))
            if let language = supportedLanguages.first(where: { $0.code.hasPrefix(code) }) {
                return language
            }
        }
        return Language(code: "en")
    }

    // MARK: - String Loading

    /// Load string table for a language
    private func loadStringTable(for languageCode: String) {
        // Load from bundle
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path)
        {
            loadedBundles[languageCode] = bundle
        }

        // Also load from JSON files for dynamic content
        if let url = Bundle.main.url(forResource: "Strings_\(languageCode)", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let strings = try? JSONDecoder().decode([String: String].self, from: data)
        {
            stringTables[languageCode] = strings
        }
    }

    // MARK: - String Localization

    /// Get localized string
    public func localize(_ key: String, table: String? = nil, comment _: String = "") -> String {
        // Try loaded string tables first
        if let strings = stringTables[currentLanguage.code],
           let value = strings[key]
        {
            return value
        }

        // Fall back to bundle
        if let bundle = loadedBundles[currentLanguage.code] {
            let value = bundle.localizedString(forKey: key, value: nil, table: table)
            if value != key {
                return value
            }
        }

        // Fall back to main bundle
        return Bundle.main.localizedString(forKey: key, value: key, table: table)
    }

    /// Get localized string with arguments
    public func localizeFormatted(_ key: String, arguments: CVarArg...) -> String {
        let format = localize(key)
        return String(format: format, arguments: arguments)
    }

    /// Get localized string with named parameters
    public func localize(_ key: String, parameters: [String: String]) -> String {
        var result = localize(key, table: nil)
        for (param, value) in parameters {
            result = result.replacingOccurrences(of: "{\(param)}", with: value)
        }
        return result
    }

    // MARK: - Pluralization

    /// Get pluralized string
    public func pluralize(_ key: String, count: Int) -> String {
        let pluralKey = getPluralKey(for: count)
        let fullKey = "\(key).\(pluralKey)"
        return localizeFormatted(fullKey, arguments: count)
    }

    private func getPluralKey(for count: Int) -> String {
        // CLDR plural rules
        let language = currentLanguage.code

        switch language {
        case "ar":
            // Arabic has 6 plural forms
            if count == 0 { return "zero" }
            if count == 1 { return "one" }
            if count == 2 { return "two" }
            if (3 ... 10).contains(count % 100) { return "few" }
            if (11 ... 99).contains(count % 100) { return "many" }
            return "other"

        case "ru", "uk", "pl":
            // Slavic languages
            let mod10 = count % 10
            let mod100 = count % 100

            if mod10 == 1, mod100 != 11 { return "one" }
            if (2 ... 4).contains(mod10), !(12 ... 14).contains(mod100) { return "few" }
            return "many"

        case "ja", "ko", "zh-Hans", "zh-Hant", "vi", "th":
            // No plural forms
            return "other"

        default:
            // Most European languages
            if count == 1 { return "one" }
            return "other"
        }
    }

    // MARK: - Formatting

    /// Format date
    public func formatDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        dateFormatter.dateStyle = style
        return dateFormatter.string(from: date)
    }

    /// Format time
    public func formatTime(_ date: Date, style: DateFormatter.Style = .short) -> String {
        timeFormatter.timeStyle = style
        return timeFormatter.string(from: date)
    }

    /// Format date and time
    public func formatDateTime(_ date: Date, dateStyle: DateFormatter.Style = .medium, timeStyle: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.locale = currentLocale
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: date)
    }

    /// Format relative time
    public func formatRelativeTime(_ date: Date) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    /// Format number
    public func formatNumber(_ number: NSNumber) -> String {
        numberFormatter.string(from: number) ?? "\(number)"
    }

    /// Format number with decimal places
    public func formatNumber(_ number: Double, decimalPlaces: Int = 2) -> String {
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.maximumFractionDigits = decimalPlaces
        return numberFormatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    /// Format currency
    public func formatCurrency(_ amount: Double, currencyCode: String? = nil) -> String {
        if let code = currencyCode {
            currencyFormatter.currencyCode = code
        }
        return currencyFormatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    /// Format percentage
    public func formatPercent(_ value: Double) -> String {
        percentFormatter.string(from: NSNumber(value: value)) ?? "\(value * 100)%"
    }

    /// Format measurement
    public func formatMeasurement(_ measurement: Measurement<some Unit>) -> String {
        measurementFormatter.string(from: measurement)
    }

    /// Format list
    public func formatList(_ items: [String]) -> String {
        listFormatter.string(from: items) ?? items.joined(separator: ", ")
    }

    /// Format file size
    public func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    /// Format duration
    public func formatDuration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute, .second]
        return formatter.string(from: seconds) ?? "\(Int(seconds))s"
    }

    // MARK: - Accessibility

    /// Get accessible description for a value
    public func accessibleDescription(for value: Any) -> String {
        switch value {
        case let number as NSNumber:
            let formatter = NumberFormatter()
            formatter.numberStyle = .spellOut
            formatter.locale = currentLocale
            return formatter.string(from: number) ?? "\(number)"

        case let date as Date:
            let formatter = DateFormatter()
            formatter.locale = currentLocale
            formatter.dateStyle = .full
            formatter.timeStyle = .full
            return formatter.string(from: date)

        default:
            return String(describing: value)
        }
    }

    // MARK: - Dynamic Strings

    /// Register dynamic string (for remote/server translations)
    public func registerString(key: String, value: String, language: String) {
        if stringTables[language] == nil {
            stringTables[language] = [:]
        }
        stringTables[language]?[key] = value
    }

    /// Load remote translations
    public func loadRemoteTranslations(from url: URL) async throws {
        let (data, _) = try await URLSession.shared.data(from: url)
        let translations = try JSONDecoder().decode([String: [String: String]].self, from: data)

        for (language, strings) in translations {
            if stringTables[language] == nil {
                stringTables[language] = [:]
            }
            stringTables[language]?.merge(strings) { _, new in new }
        }

        logger.info("Loaded remote translations for \(translations.count) languages")
    }
}

// MARK: - Types

public struct Language: Identifiable, Equatable, Codable {
    public let id: String
    public let code: String
    public let name: String
    public let nativeName: String
    public let isRTL: Bool

    public init(code: String, name: String = "", nativeName: String = "", isRTL: Bool = false) {
        id = code
        self.code = code
        self.name = name.isEmpty ? code : name
        self.nativeName = nativeName.isEmpty ? name : nativeName
        self.isRTL = isRTL
    }
}

public struct PluralRule {
    public let zero: String?
    public let one: String
    public let two: String?
    public let few: String?
    public let many: String?
    public let other: String
}

// MARK: - Notifications

public extension Notification.Name {
    static let languageDidChange = Notification.Name("thea.languageDidChange")
}

// MARK: - String Extension

@MainActor
public extension String {
    /// Localize this string
    var localized: String {
        LocalizationManager.shared.localize(self)
    }

    /// Localize with arguments
    func localized(_ arguments: CVarArg...) -> String {
        LocalizationManager.shared.localizeFormatted(self, arguments: arguments)
    }

    /// Localize with parameters
    func localized(with parameters: [String: String]) -> String {
        LocalizationManager.shared.localize(self, parameters: parameters)
    }

    /// Pluralize with count
    func pluralized(_ count: Int) -> String {
        LocalizationManager.shared.pluralize(self, count: count)
    }
}

// MARK: - SwiftUI Helpers

import SwiftUI

public struct LocalizedText: View {
    let key: String
    let arguments: [CVarArg]

    public init(_ key: String, _ arguments: CVarArg...) {
        self.key = key
        self.arguments = arguments
    }

    public var body: some View {
        if arguments.isEmpty {
            Text(key.localized)
        } else {
            Text(String(format: key.localized, arguments: arguments))
        }
    }
}

public extension View {
    /// Apply RTL layout if needed
    func respectsLayoutDirection() -> some View {
        environment(\.layoutDirection, LocalizationManager.shared.isRTL ? .rightToLeft : .leftToRight)
    }
}
