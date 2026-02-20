import Foundation

// MARK: - Quality & Release Models for Media Automation

/// Video resolution
enum Resolution: String, Codable, Comparable, Sendable, CaseIterable {
    case unknown = "Unknown"
    case sd480 = "480p"
    case hd720 = "720p"
    case fullHD1080 = "1080p"
    case uhd2160 = "2160p"

    static func < (lhs: Resolution, rhs: Resolution) -> Bool {
        let order: [Resolution] = [.unknown, .sd480, .hd720, .fullHD1080, .uhd2160]
        guard let lhsIdx = order.firstIndex(of: lhs),
              let rhsIdx = order.firstIndex(of: rhs) else { return false }
        return lhsIdx < rhsIdx
    }

    var score: Int {
        switch self {
        case .unknown: 0
        case .sd480: 100
        case .hd720: 200
        case .fullHD1080: 400
        case .uhd2160: 800
        }
    }
}

/// Video source type
enum VideoSource: String, Codable, Sendable, CaseIterable {
    case unknown = "Unknown"
    case cam = "CAM"
    case telesync = "TS"
    case telecine = "TC"
    case screener = "SCR"
    case hdtv = "HDTV"
    case webRip = "WEBRip"
    case webDL = "WEB-DL"
    case bluray = "BluRay"
    case remux = "Remux"

    var score: Int {
        switch self {
        case .unknown: 0
        case .cam: -500
        case .telesync: -400
        case .telecine: -300
        case .screener: -200
        case .hdtv: 100
        case .webRip: 200
        case .webDL: 350
        case .bluray: 500
        case .remux: 700
        }
    }
}

/// Video codec
enum VideoCodec: String, Codable, Sendable, CaseIterable {
    case unknown = "Unknown"
    case xvid = "XviD"
    case x264 = "x264"
    case x265 = "x265"
    case hevc = "HEVC"
    case av1 = "AV1"

    var score: Int {
        switch self {
        case .unknown: 0
        case .xvid: 50
        case .x264: 100
        case .x265, .hevc: 150
        case .av1: 200
        }
    }
}

/// HDR format
enum HDRFormat: String, Codable, Sendable, CaseIterable {
    case none = "SDR"
    case hdr10 = "HDR10"
    case hdr10Plus = "HDR10+"
    case dolbyVision = "Dolby Vision"
    case dolbyVisionHDR = "DV+HDR"
    case hlg = "HLG"

    var score: Int {
        switch self {
        case .none: 0
        case .hlg: 50
        case .hdr10: 100
        case .hdr10Plus: 150
        case .dolbyVision: 180
        case .dolbyVisionHDR: 200
        }
    }

    /// Samsung TVs can't play pure Dolby Vision
    var samsungCompatible: Bool {
        self != .dolbyVision
    }

    /// Apple TV 4K supports all HDR formats
    var appleTVCompatible: Bool {
        true
    }
}

/// Audio codec
enum AudioCodec: String, Codable, Sendable, CaseIterable {
    case unknown = "Unknown"
    case aac = "AAC"
    case ac3 = "AC3"
    case eac3 = "E-AC3"
    case dts = "DTS"
    case dtsHD = "DTS-HD"
    case dtsX = "DTS:X"
    case trueHD = "TrueHD"
    case atmos = "Atmos"

    var score: Int {
        switch self {
        case .unknown: 0
        case .aac: 50
        case .ac3: 100
        case .eac3: 150
        case .dts: 150
        case .dtsHD: 200
        case .dtsX: 250
        case .trueHD: 250
        case .atmos: 300
        }
    }
}

/// Release group quality tier
enum ReleaseGroupTier: String, Codable, Sendable {
    case gold
    case silver
    case bronze
    case unknown
    case banned

    var scoreMultiplier: Double {
        switch self {
        case .gold: 1.2
        case .silver: 1.1
        case .bronze: 1.0
        case .unknown: 0.9
        case .banned: 0.1
        }
    }
}

/// Parsed release information
struct ParsedRelease: Codable, Identifiable, Sendable {
    let id: String
    let rawName: String
    let title: String
    var year: Int?
    var season: Int?
    var episode: Int?
    let resolution: Resolution
    let source: VideoSource
    let codec: VideoCodec
    let hdrFormat: HDRFormat
    let audioCodec: AudioCodec
    var releaseGroup: String?
    var groupTier: ReleaseGroupTier
    var size: Int64?
    var seeders: Int?
    var indexer: String?

    /// Calculate quality score
    var qualityScore: Int {
        var score = resolution.score + source.score + codec.score + hdrFormat.score + audioCodec.score
        score = Int(Double(score) * groupTier.scoreMultiplier)
        if let seeders, seeders > 10 { score += min(seeders / 10, 50) }
        return score
    }
}

// MARK: - Quality Profile

struct QualityProfile: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let description: String
    let minResolution: Resolution
    let preferredResolution: Resolution
    let minSource: VideoSource
    let preferHDR: Bool
    let preferAtmos: Bool
    let cutoffScore: Int
    let minGroupTier: ReleaseGroupTier

    /// Pre-configured profiles based on TRaSH Guides
    static let presets: [QualityProfile] = [
        QualityProfile(
            id: "trash-4k-appletv",
            name: "TRaSH 4K (Apple TV)",
            description: "Optimized for Apple TV 4K - all HDR formats supported",
            minResolution: .fullHD1080,
            preferredResolution: .uhd2160,
            minSource: .webDL,
            preferHDR: true,
            preferAtmos: true,
            cutoffScore: 1200,
            minGroupTier: .bronze
        ),
        QualityProfile(
            id: "trash-1080p",
            name: "TRaSH 1080p",
            description: "High quality 1080p releases",
            minResolution: .hd720,
            preferredResolution: .fullHD1080,
            minSource: .webDL,
            preferHDR: false,
            preferAtmos: false,
            cutoffScore: 700,
            minGroupTier: .bronze
        ),
        QualityProfile(
            id: "space-saver",
            name: "Space Saver",
            description: "Smaller file sizes, good quality",
            minResolution: .hd720,
            preferredResolution: .fullHD1080,
            minSource: .webRip,
            preferHDR: false,
            preferAtmos: false,
            cutoffScore: 500,
            minGroupTier: .unknown
        ),
        QualityProfile(
            id: "anime",
            name: "Anime",
            description: "Optimized for anime releases",
            minResolution: .hd720,
            preferredResolution: .fullHD1080,
            minSource: .webDL,
            preferHDR: false,
            preferAtmos: false,
            cutoffScore: 600,
            minGroupTier: .unknown
        )
    ]

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    func isAcceptable(_ release: ParsedRelease) -> Bool {
        guard release.resolution >= minResolution else { return false }
        guard release.source.score >= minSource.score else { return false }
        guard release.groupTier != .banned else { return false }
        return true
    }

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    func isUpgrade(from current: ParsedRelease?, to new: ParsedRelease) -> Bool {
        guard let current else { return isAcceptable(new) }
        return new.qualityScore > current.qualityScore && isAcceptable(new)
    }
}

// MARK: - Download Queue Item

struct DownloadQueueItem: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let release: ParsedRelease
    var status: DownloadStatus
    var progress: Double
    var eta: TimeInterval?
    var speed: Int64?
    var addedAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var error: String?
    var retryCount: Int

    enum DownloadStatus: String, Codable, Sendable {
        case queued
        case downloading
        case paused
        case seeding
        case completed
        case failed
        case importing
    }
}
