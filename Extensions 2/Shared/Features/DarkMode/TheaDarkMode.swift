// TheaDarkMode.swift
// Intelligent dark mode for websites (replaces Noir)
// Features: auto-generation, per-site themes, OLED black, scheduled activation

import Combine
import Foundation
import OSLog
import SwiftUI

// MARK: - Dark Mode Manager

@MainActor
public final class TheaDarkModeManager: ObservableObject {
    public static let shared = TheaDarkModeManager()

    private let logger = Logger(subsystem: "com.thea.extension", category: "DarkMode")

    // MARK: - Published State

    @Published public var isEnabled = false
    @Published public var globalTheme: DarkTheme = .midnight
    @Published public private(set) var sitePreferences: [String: SitePreference] = [:]
    @Published public var settings = DarkModeSettings()
    @Published public private(set) var customThemes: [DarkTheme] = []

    // MARK: - Built-in Themes

    public static let builtInThemes: [DarkTheme] = [
        .pure,
        .midnight,
        .warm,
        DarkTheme(
            id: "ocean", name: "Ocean",
            backgroundColor: "#0d1b2a", textColor: "#e0e1dd",
            linkColor: "#90caf9", borderColor: "#1b263b", accentColor: "#90caf9",
            brightness: 1.0, contrast: 1.0, grayscale: 0, sepia: 0
        ),
        DarkTheme(
            id: "forest", name: "Forest",
            backgroundColor: "#1b2d1b", textColor: "#e8f5e9",
            linkColor: "#81c784", borderColor: "#2d4d2d", accentColor: "#81c784",
            brightness: 1.0, contrast: 1.0, grayscale: 0, sepia: 0
        ),
        DarkTheme(
            id: "nord", name: "Nord",
            backgroundColor: "#2e3440", textColor: "#eceff4",
            linkColor: "#88c0d0", borderColor: "#3b4252", accentColor: "#88c0d0",
            brightness: 1.0, contrast: 1.0, grayscale: 0, sepia: 0
        ),
        DarkTheme(
            id: "dracula", name: "Dracula",
            backgroundColor: "#282a36", textColor: "#f8f8f2",
            linkColor: "#8be9fd", borderColor: "#44475a", accentColor: "#bd93f9",
            brightness: 1.0, contrast: 1.0, grayscale: 0, sepia: 0
        ),
        DarkTheme(
            id: "monokai", name: "Monokai",
            backgroundColor: "#272822", textColor: "#f8f8f2",
            linkColor: "#66d9ef", borderColor: "#3e3d32", accentColor: "#a6e22e",
            brightness: 1.0, contrast: 1.0, grayscale: 0, sepia: 0
        ),
        DarkTheme(
            id: "solarized", name: "Solarized Dark",
            backgroundColor: "#002b36", textColor: "#839496",
            linkColor: "#268bd2", borderColor: "#073642", accentColor: "#2aa198",
            brightness: 1.0, contrast: 1.0, grayscale: 0, sepia: 0
        ),
        DarkTheme(
            id: "material", name: "Material Dark",
            backgroundColor: "#121212", textColor: "#e0e0e0",
            linkColor: "#bb86fc", borderColor: "#1f1f1f", accentColor: "#03dac6",
            brightness: 1.0, contrast: 1.0, grayscale: 0, sepia: 0
        ),
        DarkTheme(
            id: "github", name: "GitHub Dark",
            backgroundColor: "#0d1117", textColor: "#c9d1d9",
            linkColor: "#58a6ff", borderColor: "#21262d", accentColor: "#58a6ff",
            brightness: 1.0, contrast: 1.0, grayscale: 0, sepia: 0
        ),
        DarkTheme(
            id: "oled", name: "OLED Black",
            backgroundColor: "#000000", textColor: "#ffffff",
            linkColor: "#4fc3f7", borderColor: "#1a1a1a", accentColor: "#4fc3f7",
            brightness: 1.0, contrast: 1.1, grayscale: 0, sepia: 0
        ),
        DarkTheme(
            id: "sepia", name: "Sepia Night",
            backgroundColor: "#1a1814", textColor: "#d4c5a9",
            linkColor: "#c9a959", borderColor: "#2d2820", accentColor: "#c9a959",
            brightness: 1.0, contrast: 1.0, grayscale: 0, sepia: 0.2
        ),
        DarkTheme(
            id: "highContrast", name: "High Contrast",
            backgroundColor: "#000000", textColor: "#ffffff",
            linkColor: "#00ff00", borderColor: "#ffffff", accentColor: "#ffff00",
            brightness: 1.0, contrast: 1.3, grayscale: 0, sepia: 0
        ),
        DarkTheme(
            id: "dimmed", name: "Dimmed",
            backgroundColor: "#1e1e1e", textColor: "#c0c0c0",
            linkColor: "#6699cc", borderColor: "#2d2d2d", accentColor: "#6699cc",
            brightness: 0.85, contrast: 0.95, grayscale: 0, sepia: 0
        ),
        DarkTheme(
            id: "eyecare", name: "Eye Care",
            backgroundColor: "#1f1f1f", textColor: "#e6d5b8",
            linkColor: "#d4a574", borderColor: "#2d2a26", accentColor: "#d4a574",
            brightness: 0.9, contrast: 0.95, grayscale: 0, sepia: 0.15
        )
    ]

    // MARK: - Initialization

    private init() {
        loadSettings()
        loadCustomThemes()
        loadSitePreferences()
        setupSystemThemeObserver()
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "darkMode.settings"),
           let loaded = try? JSONDecoder().decode(DarkModeSettings.self, from: data)
        {
            settings = loaded
            isEnabled = settings.enabled
        }

        if let themeId = UserDefaults.standard.string(forKey: "darkMode.globalTheme"),
           let theme = Self.builtInThemes.first(where: { $0.id == themeId })
        {
            globalTheme = theme
        }
    }

    public func saveSettings() {
        settings.enabled = isEnabled
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "darkMode.settings")
        }
        UserDefaults.standard.set(globalTheme.id, forKey: "darkMode.globalTheme")
    }

    private func loadCustomThemes() {
        if let data = UserDefaults.standard.data(forKey: "darkMode.customThemes"),
           let loaded = try? JSONDecoder().decode([DarkTheme].self, from: data)
        {
            customThemes = loaded
        }
    }

    private func saveCustomThemes() {
        if let data = try? JSONEncoder().encode(customThemes) {
            UserDefaults.standard.set(data, forKey: "darkMode.customThemes")
        }
    }

    private func loadSitePreferences() {
        if let data = UserDefaults.standard.data(forKey: "darkMode.sitePreferences"),
           let loaded = try? JSONDecoder().decode([String: SitePreference].self, from: data)
        {
            sitePreferences = loaded
        }
    }

    private func saveSitePreferences() {
        if let data = try? JSONEncoder().encode(sitePreferences) {
            UserDefaults.standard.set(data, forKey: "darkMode.sitePreferences")
        }
    }

    private func setupSystemThemeObserver() {
        // Observe system appearance changes
        #if os(macOS)
            DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleSystemThemeChange()
                }
            }
        #endif
    }

    private func handleSystemThemeChange() {
        if settings.followSystem {
            let isDarkMode = checkSystemDarkMode()
            if isDarkMode != isEnabled {
                isEnabled = isDarkMode
                saveSettings()

                // Notify extensions
                TheaExtensionBridge.shared.notifyExtensions(
                    ExtensionNotification(
                        type: .stateChanged,
                        data: ["darkMode": AnyCodable(isEnabled)]
                    )
                )
            }
        }
    }

    private func checkSystemDarkMode() -> Bool {
        #if os(macOS)
            return NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        #elseif os(iOS)
            return UITraitCollection.current.userInterfaceStyle == .dark
        #else
            return false
        #endif
    }

    // MARK: - Dark Mode Control

    /// Toggle dark mode
    public func toggle() {
        isEnabled.toggle()
        saveSettings()

        if isEnabled {
            TheaExtensionState.shared.stats.pagesDarkened += 1
        }

        logger.info("Dark mode \(isEnabled ? "enabled" : "disabled")")
    }

    /// Enable dark mode for a specific page
    public func enableDarkMode(on page: PageContext, theme: DarkTheme? = nil) async throws -> DarkModeCSS {
        let appliedTheme = getThemeForSite(page.domain) ?? theme ?? globalTheme

        // Generate CSS for the theme
        let css = generateDarkModeCSS(for: appliedTheme, page: page)

        logger.info("Applied dark mode to \(page.domain)")

        return css
    }

    /// Disable dark mode for a specific page
    public func disableDarkMode(on page: PageContext) async throws {
        // Return CSS that removes dark mode styles
        logger.info("Disabled dark mode for \(page.domain)")
    }

    /// Get all available themes
    public func getThemes() -> [DarkTheme] {
        Self.builtInThemes + customThemes
    }

    /// Set the default global theme
    public func setGlobalTheme(_ theme: DarkTheme) {
        globalTheme = theme
        saveSettings()
    }

    /// Set preference for a specific site
    public func setSitePreference(domain: String, preference: SitePreference) {
        sitePreferences[normalizeDomain(domain)] = preference
        saveSitePreferences()

        logger.info("Set preference for \(domain): \(preference.mode.rawValue)")
    }

    /// Get site preference
    public func getSitePreference(for domain: String) -> SitePreference? {
        sitePreferences[normalizeDomain(domain)]
    }

    /// Remove site preference
    public func removeSitePreference(for domain: String) {
        sitePreferences.removeValue(forKey: normalizeDomain(domain))
        saveSitePreferences()
    }

    // MARK: - Custom Themes

    /// Create a custom theme
    public func createCustomTheme(_ theme: DarkTheme) {
        customThemes.append(theme)
        saveCustomThemes()
    }

    /// Update a custom theme
    public func updateCustomTheme(_ theme: DarkTheme) {
        if let index = customThemes.firstIndex(where: { $0.id == theme.id }) {
            customThemes[index] = theme
            saveCustomThemes()
        }
    }

    /// Delete a custom theme
    public func deleteCustomTheme(_ themeId: String) {
        customThemes.removeAll { $0.id == themeId }
        saveCustomThemes()

        // Reset any site preferences using this theme
        for (domain, pref) in sitePreferences {
            if pref.themeId == themeId {
                var updated = pref
                updated.themeId = nil
                sitePreferences[domain] = updated
            }
        }
        saveSitePreferences()
    }

    // MARK: - CSS Generation

    /// Generate dark mode CSS for a theme
    public func generateDarkModeCSS(for theme: DarkTheme, page: PageContext) -> DarkModeCSS {
        // Core dark mode styles
        let coreCSS = """
        :root {
            --thea-bg: \(theme.backgroundColor);
            --thea-text: \(theme.textColor);
            --thea-link: \(theme.linkColor);
            --thea-border: \(theme.borderColor);
            --thea-accent: \(theme.accentColor);
        }

        html {
            background-color: var(--thea-bg) !important;
            color: var(--thea-text) !important;
            filter: brightness(\(theme.brightness)) contrast(\(theme.contrast)) \(theme.grayscale > 0 ? "grayscale(\(theme.grayscale))" : "") \(theme.sepia > 0 ? "sepia(\(theme.sepia))" : "");
        }

        body {
            background-color: var(--thea-bg) !important;
            color: var(--thea-text) !important;
        }

        /* Text elements */
        h1, h2, h3, h4, h5, h6, p, span, div, li, td, th, label,
        article, section, aside, main, header, footer, nav {
            background-color: transparent !important;
            color: inherit !important;
        }

        /* Links */
        a, a:link, a:visited {
            color: var(--thea-link) !important;
        }
        a:hover {
            color: var(--thea-accent) !important;
        }

        /* Borders */
        *, *::before, *::after {
            border-color: var(--thea-border) !important;
        }

        /* Inputs and buttons */
        input, textarea, select, button {
            background-color: \(adjustBrightness(theme.backgroundColor, by: 0.1)) !important;
            color: var(--thea-text) !important;
            border-color: var(--thea-border) !important;
        }

        input::placeholder, textarea::placeholder {
            color: \(adjustAlpha(theme.textColor, to: 0.5)) !important;
        }

        button:hover, input[type="submit"]:hover, input[type="button"]:hover {
            background-color: \(adjustBrightness(theme.backgroundColor, by: 0.15)) !important;
        }

        /* Tables */
        table, tr, td, th {
            background-color: transparent !important;
            border-color: var(--thea-border) !important;
        }
        tr:nth-child(even) {
            background-color: \(adjustBrightness(theme.backgroundColor, by: 0.03)) !important;
        }
        th {
            background-color: \(adjustBrightness(theme.backgroundColor, by: 0.05)) !important;
        }

        /* Code blocks */
        pre, code {
            background-color: \(adjustBrightness(theme.backgroundColor, by: -0.02)) !important;
            color: var(--thea-text) !important;
        }

        /* Blockquotes */
        blockquote {
            background-color: \(adjustBrightness(theme.backgroundColor, by: 0.02)) !important;
            border-left-color: var(--thea-accent) !important;
        }

        /* Images - preserve or invert based on settings */
        \(settings.invertImages ? """
        img:not([src*=".svg"]) {
            filter: invert(1) hue-rotate(180deg) !important;
        }
        """ : "")

        /* Scrollbars */
        ::-webkit-scrollbar {
            width: 12px;
            height: 12px;
        }
        ::-webkit-scrollbar-track {
            background: var(--thea-bg);
        }
        ::-webkit-scrollbar-thumb {
            background: \(adjustBrightness(theme.backgroundColor, by: 0.2));
            border-radius: 6px;
        }
        ::-webkit-scrollbar-thumb:hover {
            background: \(adjustBrightness(theme.backgroundColor, by: 0.3));
        }

        /* Selection */
        ::selection {
            background-color: var(--thea-accent) !important;
            color: var(--thea-bg) !important;
        }
        """

        // Site-specific overrides
        let siteOverrides = generateSiteSpecificCSS(for: page.domain, theme: theme)

        return DarkModeCSS(
            coreCSS: coreCSS,
            siteOverrides: siteOverrides,
            themeId: theme.id
        )
    }

    private func generateSiteSpecificCSS(for domain: String, theme: DarkTheme) -> String {
        // Site-specific overrides for popular sites
        let overrides: [String: String] = [
            "github.com": """
                .header, .Header { background-color: \(adjustBrightness(theme.backgroundColor, by: 0.03)) !important; }
                .Box { background-color: \(adjustBrightness(theme.backgroundColor, by: 0.02)) !important; }
                .markdown-body { background-color: transparent !important; }
            """,

            "stackoverflow.com": """
                .s-post-summary { background-color: transparent !important; }
                .post-text { background-color: transparent !important; }
            """,

            "reddit.com": """
                .Post { background-color: \(adjustBrightness(theme.backgroundColor, by: 0.02)) !important; }
                ._1oQyIsiPHYt6nx7VOmd1sz { background-color: transparent !important; }
            """,

            "twitter.com": """
                [data-testid="primaryColumn"] { background-color: var(--thea-bg) !important; }
                article { background-color: transparent !important; }
            """,

            "x.com": """
                [data-testid="primaryColumn"] { background-color: var(--thea-bg) !important; }
                article { background-color: transparent !important; }
            """,

            "youtube.com": """
                ytd-app { background-color: var(--thea-bg) !important; }
                ytd-watch-flexy { background-color: var(--thea-bg) !important; }
                #content { background-color: transparent !important; }
            """,

            "medium.com": """
                article { background-color: transparent !important; }
                .metabar { background-color: \(adjustBrightness(theme.backgroundColor, by: 0.02)) !important; }
            """,

            "wikipedia.org": """
                #content { background-color: var(--thea-bg) !important; }
                #mw-navigation { background-color: \(adjustBrightness(theme.backgroundColor, by: 0.02)) !important; }
                .infobox { background-color: \(adjustBrightness(theme.backgroundColor, by: 0.03)) !important; }
            """
        ]

        return overrides[domain] ?? ""
    }

    // MARK: - Helpers

    private func normalizeDomain(_ domain: String) -> String {
        var normalized = domain.lowercased()

        // Remove protocol
        if let range = normalized.range(of: "://") {
            normalized = String(normalized[range.upperBound...])
        }

        // Remove www
        if normalized.hasPrefix("www.") {
            normalized = String(normalized.dropFirst(4))
        }

        // Remove path
        if let slashIndex = normalized.firstIndex(of: "/") {
            normalized = String(normalized[..<slashIndex])
        }

        return normalized
    }

    private func getThemeForSite(_ domain: String) -> DarkTheme? {
        guard let pref = sitePreferences[normalizeDomain(domain)],
              let themeId = pref.themeId
        else {
            return nil
        }

        return getThemes().first { $0.id == themeId }
    }

    private func adjustBrightness(_ hex: String, by amount: Double) -> String {
        guard let rgb = hexToRGB(hex) else { return hex }

        let newR = min(255, max(0, Double(rgb.r) + amount * 255))
        let newG = min(255, max(0, Double(rgb.g) + amount * 255))
        let newB = min(255, max(0, Double(rgb.b) + amount * 255))

        return String(format: "#%02X%02X%02X", Int(newR), Int(newG), Int(newB))
    }

    private func adjustAlpha(_ hex: String, to alpha: Double) -> String {
        guard let rgb = hexToRGB(hex) else { return hex }
        return "rgba(\(rgb.r), \(rgb.g), \(rgb.b), \(alpha))"
    }

    private func hexToRGB(_ hex: String) -> (r: Int, g: Int, b: Int)? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        return (
            r: Int((rgb >> 16) & 0xFF),
            g: Int((rgb >> 8) & 0xFF),
            b: Int(rgb & 0xFF)
        )
    }

    // MARK: - Schedule

    /// Check if dark mode should be active based on schedule
    public func shouldBeActiveBySchedule() -> Bool {
        guard settings.scheduleEnabled else { return true }

        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTime = currentHour * 60 + currentMinute

        let startHour = calendar.component(.hour, from: settings.scheduleStart)
        let startMinute = calendar.component(.minute, from: settings.scheduleStart)
        let startTime = startHour * 60 + startMinute

        let endHour = calendar.component(.hour, from: settings.scheduleEnd)
        let endMinute = calendar.component(.minute, from: settings.scheduleEnd)
        let endTime = endHour * 60 + endMinute

        if startTime < endTime {
            // Normal schedule (e.g., 20:00 to 07:00)
            return currentTime >= startTime || currentTime < endTime
        } else {
            // Overnight schedule
            return currentTime >= startTime || currentTime < endTime
        }
    }
}

// MARK: - Supporting Types

public struct DarkModeSettings: Codable {
    public var enabled: Bool = false
    public var followSystem: Bool = true
    public var scheduleEnabled: Bool = false
    public var scheduleStart: Date = Calendar.current.date(from: DateComponents(hour: 20))!
    public var scheduleEnd: Date = Calendar.current.date(from: DateComponents(hour: 7))!
    public var invertImages: Bool = false
    public var preserveColors: Bool = false
    public var contrastBoost: Double = 0
    public var dimBrightImages: Bool = true
}

public struct SitePreference: Codable {
    public var mode: DarkModePreference = .auto
    public var themeId: String?
    public var customCSS: String?
    public var disableImageInversion: Bool = false
}

public struct DarkModeCSS {
    public let coreCSS: String
    public let siteOverrides: String
    public let themeId: String

    public var combined: String {
        """
        /* Thea Dark Mode - Theme: \(themeId) */
        \(coreCSS)

        /* Site-specific overrides */
        \(siteOverrides)
        """
    }
}
