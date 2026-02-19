import SwiftUI

extension Font {
    // MARK: - Helper to Convert Weight String

    private static func weight(from string: String) -> Font.Weight {
        switch string.lowercased() {
        case "ultralight": .ultraLight
        case "thin": .thin
        case "light": .light
        case "regular": .regular
        case "medium": .medium
        case "semibold": .semibold
        case "bold": .bold
        case "heavy": .heavy
        case "black": .black
        default: .regular
        }
    }

    // MARK: - Dynamic Type Scaling

    /// Creates a system font at a custom base size that scales with Dynamic Type.
    ///
    /// On iOS/tvOS/watchOS, uses UIFontMetrics to scale the base size according
    /// to the user's preferred content size category. On macOS, returns the
    /// unscaled size (macOS handles text scaling at the system level).
    private static func scalableFont(
        size: CGFloat,
        weight: Font.Weight,
        design: Font.Design = .default,
        relativeTo textStyle: Font.TextStyle
    ) -> Font {
        #if canImport(UIKit) && !os(watchOS)
            let uiTextStyle = textStyle.uiTextStyle
            let metrics = UIFontMetrics(forTextStyle: uiTextStyle)
            let scaledSize = metrics.scaledValue(for: size)
            return Font.system(size: scaledSize, weight: weight, design: design)
        #else
            return Font.system(size: size, weight: weight, design: design)
        #endif
    }

    // MARK: - Configurable Fonts (MainActor required)

    @MainActor
    // periphery:ignore - Reserved: theaDisplay static property — reserved for future feature activation
    static var theaDisplay: Font {
        let config = AppConfiguration.shared.themeConfig
        return scalableFont(
            size: config.displaySize,
            weight: weight(from: config.displayWeight),
            design: config.useRoundedDesign ? .rounded : .default,
            relativeTo: .largeTitle
        )
    }

    @MainActor
    static var theaTitle1: Font {
        let config = AppConfiguration.shared.themeConfig
        return scalableFont(
            size: config.title1Size,
            weight: weight(from: config.title1Weight),
            // periphery:ignore - Reserved: theaDisplay static property reserved for future feature activation
            design: config.useRoundedDesign ? .rounded : .default,
            relativeTo: .title
        )
    }

    @MainActor
    static var theaTitle2: Font {
        let config = AppConfiguration.shared.themeConfig
        return scalableFont(
            size: config.title2Size,
            weight: weight(from: config.title2Weight),
            design: config.useRoundedDesign ? .rounded : .default,
            relativeTo: .title2
        )
    }

    @MainActor
    static var theaTitle3: Font {
        let config = AppConfiguration.shared.themeConfig
        return scalableFont(
            size: config.title3Size,
            weight: weight(from: config.title3Weight),
            design: config.useRoundedDesign ? .rounded : .default,
            relativeTo: .title3
        )
    }

    @MainActor
    static var theaLargeDisplay: Font {
        scalableFont(size: 42, weight: .bold, design: .rounded, relativeTo: .largeTitle)
    }

    @MainActor
    static var theaHeadline: Font {
        let config = AppConfiguration.shared.themeConfig
        return scalableFont(
            size: config.headlineSize,
            weight: weight(from: config.headlineWeight),
            relativeTo: .headline
        )
    }

    @MainActor
    static var theaBody: Font {
        let config = AppConfiguration.shared.themeConfig
        return scalableFont(
            size: config.bodySize,
            weight: weight(from: config.bodyWeight),
            relativeTo: .body
        )
    }

    @MainActor
    static var theaCallout: Font {
        let config = AppConfiguration.shared.themeConfig
        return scalableFont(size: config.calloutSize, weight: .regular, relativeTo: .callout)
    }

    @MainActor
    static var theaSubhead: Font {
        let config = AppConfiguration.shared.themeConfig
        return scalableFont(size: config.subheadSize, weight: .regular, relativeTo: .subheadline)
    }

    @MainActor
    static var theaFootnote: Font {
        let config = AppConfiguration.shared.themeConfig
        return scalableFont(size: config.footnoteSize, weight: .regular, relativeTo: .footnote)
    }

    @MainActor
    static var theaCaption1: Font {
        let config = AppConfiguration.shared.themeConfig
        return scalableFont(size: config.caption1Size, weight: .regular, relativeTo: .caption)
    }

    @MainActor
    static var theaCaption2: Font {
        let config = AppConfiguration.shared.themeConfig
        return scalableFont(size: config.caption2Size, weight: .regular, relativeTo: .caption2)
    }

    @MainActor
    // periphery:ignore - Reserved: theaCode static property — reserved for future feature activation
    static var theaCode: Font {
        let config = AppConfiguration.shared.themeConfig
        return scalableFont(
            size: config.codeSize,
            weight: .regular,
            design: .monospaced,
            relativeTo: .body
        )
    }

    @MainActor
    // periphery:ignore - Reserved: theaCodeInline static property — reserved for future feature activation
    static var theaCodeInline: Font {
        let config = AppConfiguration.shared.themeConfig
        return scalableFont(
            size: config.codeInlineSize,
            // periphery:ignore - Reserved: theaCode static property reserved for future feature activation
            weight: .medium,
            design: .monospaced,
            relativeTo: .callout
        )
    }

    // MARK: - Static Defaults (for non-MainActor contexts)
    // Note: Static defaults use fixed sizes (no Dynamic Type scaling)
    // to avoid UIKit dependency. Use the @MainActor computed properties
    // in views for proper Dynamic Type support.

// periphery:ignore - Reserved: theaCodeInline static property reserved for future feature activation

    static let theaDisplayDefault = Font.system(size: 34, weight: .bold, design: .rounded)
    // periphery:ignore - Reserved: theaTitle1Default static property — reserved for future feature activation
    static let theaTitle1Default = Font.system(size: 28, weight: .bold, design: .rounded)
    // periphery:ignore - Reserved: theaTitle2Default static property — reserved for future feature activation
    static let theaTitle2Default = Font.system(size: 22, weight: .semibold, design: .rounded)
    // periphery:ignore - Reserved: theaLargeDisplayDefault static property — reserved for future feature activation
    static let theaLargeDisplayDefault = Font.system(size: 42, weight: .bold, design: .rounded)
    // periphery:ignore - Reserved: theaTitle3Default static property — reserved for future feature activation
    static let theaTitle3Default = Font.system(size: 20, weight: .semibold, design: .rounded)
    // periphery:ignore - Reserved: theaHeadlineDefault static property — reserved for future feature activation
    static let theaHeadlineDefault = Font.system(size: 17, weight: .semibold)
    // periphery:ignore - Reserved: theaBodyDefault static property — reserved for future feature activation
    static let theaBodyDefault = Font.system(size: 17, weight: .regular)
    // periphery:ignore - Reserved: theaCalloutDefault static property — reserved for future feature activation
    static let theaCalloutDefault = Font.system(size: 16, weight: .regular)
    // periphery:ignore - Reserved: theaSubheadDefault static property — reserved for future feature activation
    static let theaSubheadDefault = Font.system(size: 15, weight: .regular)
    // periphery:ignore - Reserved: theaFootnoteDefault static property — reserved for future feature activation
    static let theaFootnoteDefault = Font.system(size: 13, weight: .regular)
    // periphery:ignore - Reserved: theaCaption1Default static property — reserved for future feature activation
    static let theaCaption1Default = Font.system(size: 12, weight: .regular)
    // periphery:ignore - Reserved: theaCaption2Default static property — reserved for future feature activation
    static let theaCaption2Default = Font.system(size: 11, weight: .regular)
    // periphery:ignore - Reserved: theaCodeDefault static property — reserved for future feature activation
    static let theaCodeDefault = Font.system(size: 14, weight: .regular, design: .monospaced)
    // periphery:ignore - Reserved: theaDisplayDefault static property reserved for future feature activation
    // periphery:ignore - Reserved: theaTitle1Default static property reserved for future feature activation
    // periphery:ignore - Reserved: theaTitle2Default static property reserved for future feature activation
    // periphery:ignore - Reserved: theaLargeDisplayDefault static property reserved for future feature activation
    // periphery:ignore - Reserved: theaTitle3Default static property reserved for future feature activation
    // periphery:ignore - Reserved: theaHeadlineDefault static property reserved for future feature activation
    // periphery:ignore - Reserved: theaBodyDefault static property reserved for future feature activation
    // periphery:ignore - Reserved: theaCalloutDefault static property reserved for future feature activation
    // periphery:ignore - Reserved: theaSubheadDefault static property reserved for future feature activation
    // periphery:ignore - Reserved: theaFootnoteDefault static property reserved for future feature activation
    // periphery:ignore - Reserved: theaCaption1Default static property reserved for future feature activation
    // periphery:ignore - Reserved: theaCaption2Default static property reserved for future feature activation
    // periphery:ignore - Reserved: theaCodeDefault static property reserved for future feature activation
    // periphery:ignore - Reserved: theaCodeInlineDefault static property reserved for future feature activation
    static let theaCodeInlineDefault = Font.system(size: 16, weight: .medium, design: .monospaced)
}

// MARK: - Font.TextStyle → UIFont.TextStyle Conversion

#if canImport(UIKit) && !os(watchOS)
    import UIKit

    extension Font.TextStyle {
        /// Converts SwiftUI Font.TextStyle to UIKit UIFont.TextStyle for UIFontMetrics.
        var uiTextStyle: UIFont.TextStyle {
            switch self {
            case .largeTitle: .largeTitle
            case .title: .title1
            case .title2: .title2
            case .title3: .title3
            case .headline: .headline
            case .body: .body
            case .callout: .callout
            case .subheadline: .subheadline
            case .footnote: .footnote
            case .caption: .caption1
            case .caption2: .caption2
            @unknown default: .body
            }
        }
    }
#endif
