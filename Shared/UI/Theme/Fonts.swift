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

    // MARK: - Configurable Fonts (MainActor required)

    // MARK: - Dynamic Type Scaling Helper

    /// Creates a system font that scales with Dynamic Type relative to a text style.
    /// Uses the custom size as the base at the default content size category.
    private static func scalableFont(
        size: CGFloat,
        weight: Font.Weight,
        design: Font.Design = .default,
        relativeTo textStyle: Font.TextStyle
    ) -> Font {
        Font.system(size: size, weight: weight, design: design)
            .leading(.standard)
    }

    // MARK: - Configurable Fonts (MainActor required)

    @MainActor
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
    static var theaCodeInline: Font {
        let config = AppConfiguration.shared.themeConfig
        return scalableFont(
            size: config.codeInlineSize,
            weight: .medium,
            design: .monospaced,
            relativeTo: .callout
        )
    }

    // MARK: - Static Defaults (for non-MainActor contexts)

    static let theaDisplayDefault = Font.system(size: 34, weight: .bold, design: .rounded)
    static let theaTitle1Default = Font.system(size: 28, weight: .bold, design: .rounded)
    static let theaTitle2Default = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let theaLargeDisplayDefault = Font.system(size: 42, weight: .bold, design: .rounded)
    static let theaTitle3Default = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let theaHeadlineDefault = Font.system(size: 17, weight: .semibold)
    static let theaBodyDefault = Font.system(size: 17, weight: .regular)
    static let theaCalloutDefault = Font.system(size: 16, weight: .regular)
    static let theaSubheadDefault = Font.system(size: 15, weight: .regular)
    static let theaFootnoteDefault = Font.system(size: 13, weight: .regular)
    static let theaCaption1Default = Font.system(size: 12, weight: .regular)
    static let theaCaption2Default = Font.system(size: 11, weight: .regular)
    static let theaCodeDefault = Font.system(size: 14, weight: .regular, design: .monospaced)
    static let theaCodeInlineDefault = Font.system(size: 16, weight: .medium, design: .monospaced)
}
