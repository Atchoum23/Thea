import Foundation

// MARK: - Media Automation Service for tvOS
// Native Sonarr/Radarr-like functionality ported from thea-tizen

// MARK: - Quality & Release Models

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
        case .dolbyVision: 180  // Pure DV - may not play on all devices
        case .dolbyVisionHDR: 200  // DV with HDR fallback - best compatibility
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
    case gold      // Premium P2P groups
    case silver    // Good P2P groups
    case bronze    // Scene groups
    case unknown   // Unknown groups
    case banned    // Low quality/fake groups

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

        // Apply group tier multiplier
        score = Int(Double(score) * groupTier.scoreMultiplier)

        // Bonus for seeders
        if let seeders, seeders > 10 { score += min(seeders / 10, 50) }

        return score
    }
}

// MARK: - Release Parser Service

final class ReleaseParserService: Sendable {
    static let shared = ReleaseParserService()

    // Premium P2P groups (gold tier)
    private let goldGroups = Set([
        "FraMeSToR", "BHDStudio", "HiFi", "FLUX", "DON", "EbP", "NCmt",
        "Geek", "hallowed", "CtrlHD", "TayTO", "ZQ", "playBD", "HQMUX",
        "decibeL", "PTer", "PmP", "SiCFoI", "SURFINBIRD"
    ])

    // Good P2P groups (silver tier)
    private let silverGroups = Set([
        "SPARKS", "GECKOS", "AMIABLE", "DRONES", "NTb", "TEPES",
        "EDITH", "SiGMA", "W4NK3R", "CMRG", "MZABI", "LEGi0N"
    ])

    // Banned/low quality groups
    private let bannedGroups = Set([
        "YIFY", "YTS", "EVO", "RARBG", "aXXo", "KORSUB", "HC", "MeGusta"
    ])

    private init() {}

    func parse(_ releaseName: String) -> ParsedRelease {
        let name = releaseName.trimmingCharacters(in: .whitespacesAndNewlines)

        return ParsedRelease(
            id: UUID().uuidString,
            rawName: name,
            title: extractTitle(from: name),
            year: extractYear(from: name),
            season: extractSeason(from: name),
            episode: extractEpisode(from: name),
            resolution: detectResolution(in: name),
            source: detectSource(in: name),
            codec: detectCodec(in: name),
            hdrFormat: detectHDR(in: name),
            audioCodec: detectAudio(in: name),
            releaseGroup: extractReleaseGroup(from: name),
            groupTier: determineGroupTier(from: name)
        )
    }

    private func extractTitle(from name: String) -> String {
        // Remove common patterns to extract title
        var title = name
            .replacingOccurrences(of: "\\.", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "_", with: " ")

        // Remove year and everything after
        if let range = title.range(of: #"\s+(19|20)\d{2}\s+"#, options: .regularExpression) {
            title = String(title[..<range.lowerBound])
        }

        // Remove S01E01 patterns
        if let range = title.range(of: #"\s+S\d+E\d+"#, options: [.regularExpression, .caseInsensitive]) {
            title = String(title[..<range.lowerBound])
        }

        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractYear(from name: String) -> Int? {
        if let match = name.range(of: #"(19|20)\d{2}"#, options: .regularExpression) {
            return Int(name[match])
        }
        return nil
    }

    private func extractSeason(from name: String) -> Int? {
        if let match = name.range(of: #"S(\d{1,2})"#, options: [.regularExpression, .caseInsensitive]),
           let numMatch = name.range(of: #"\d{1,2}"#, options: .regularExpression, range: match) {
            return Int(name[numMatch])
        }
        return nil
    }

    private func extractEpisode(from name: String) -> Int? {
        if let match = name.range(of: #"E(\d{1,3})"#, options: [.regularExpression, .caseInsensitive]),
           let numMatch = name.range(of: #"\d{1,3}"#, options: .regularExpression, range: match) {
            return Int(name[numMatch])
        }
        return nil
    }

    private func detectResolution(in name: String) -> Resolution {
        let upper = name.uppercased()
        if upper.contains("2160P") || upper.contains("4K") || upper.contains("UHD") { return .uhd2160 }
        if upper.contains("1080P") || upper.contains("1080I") { return .fullHD1080 }
        if upper.contains("720P") { return .hd720 }
        if upper.contains("480P") || upper.contains("SD") { return .sd480 }
        return .unknown
    }

    private func detectSource(in name: String) -> VideoSource {
        let upper = name.uppercased()
        if upper.contains("REMUX") { return .remux }
        if upper.contains("BLURAY") || upper.contains("BLU-RAY") || upper.contains("BDRIP") { return .bluray }
        if upper.contains("WEB-DL") || upper.contains("WEBDL") { return .webDL }
        if upper.contains("WEBRIP") || upper.contains("WEB-RIP") { return .webRip }
        if upper.contains("HDTV") { return .hdtv }
        if upper.contains("SCREENER") || upper.contains("SCR") { return .screener }
        if upper.contains("TELESYNC") || upper.contains(" TS ") { return .telesync }
        if upper.contains("CAM") || upper.contains("HDCAM") { return .cam }
        return .unknown
    }

    private func detectCodec(in name: String) -> VideoCodec {
        let upper = name.uppercased()
        if upper.contains("AV1") { return .av1 }
        if upper.contains("X265") || upper.contains("H265") || upper.contains("HEVC") { return .hevc }
        if upper.contains("X264") || upper.contains("H264") || upper.contains("AVC") { return .x264 }
        if upper.contains("XVID") || upper.contains("DIVX") { return .xvid }
        return .unknown
    }

    private func detectHDR(in name: String) -> HDRFormat {
        let upper = name.uppercased()
        // Check for DV+HDR combo first (best compatibility)
        if (upper.contains("DV") || upper.contains("DOVI") || upper.contains("DOLBY.VISION")) &&
           (upper.contains("HDR") || upper.contains("HDR10")) {
            return .dolbyVisionHDR
        }
        if upper.contains("DV") || upper.contains("DOVI") || upper.contains("DOLBY.VISION") { return .dolbyVision }
        if upper.contains("HDR10+") || upper.contains("HDR10PLUS") { return .hdr10Plus }
        if upper.contains("HDR10") || upper.contains("HDR") { return .hdr10 }
        if upper.contains("HLG") { return .hlg }
        return .none
    }

    private func detectAudio(in name: String) -> AudioCodec {
        let upper = name.uppercased()
        if upper.contains("ATMOS") { return .atmos }
        if upper.contains("TRUEHD") || upper.contains("TRUE-HD") { return .trueHD }
        if upper.contains("DTS-X") || upper.contains("DTSX") { return .dtsX }
        if upper.contains("DTS-HD") || upper.contains("DTSHD") { return .dtsHD }
        if upper.contains("DTS") { return .dts }
        if upper.contains("EAC3") || upper.contains("E-AC-3") || upper.contains("DD+") || upper.contains("DDP") { return .eac3 }
        if upper.contains("AC3") || upper.contains("DD5") || upper.contains("DOLBY.DIGITAL") { return .ac3 }
        if upper.contains("AAC") { return .aac }
        return .unknown
    }

    private func extractReleaseGroup(from name: String) -> String? {
        // Group is usually after the last dash or in brackets
        if let match = name.range(of: #"-([A-Za-z0-9]+)(?:\.[a-z]{2,4})?$"#, options: .regularExpression) {
            let group = String(name[match]).replacingOccurrences(of: "-", with: "")
            if let dotIndex = group.lastIndex(of: ".") {
                return String(group[..<dotIndex])
            }
            return group
        }
        return nil
    }

    private func determineGroupTier(from name: String) -> ReleaseGroupTier {
        guard let group = extractReleaseGroup(from: name) else { return .unknown }
        let upperGroup = group.uppercased()

        if bannedGroups.contains(where: { upperGroup.contains($0.uppercased()) }) { return .banned }
        if goldGroups.contains(where: { upperGroup.contains($0.uppercased()) }) { return .gold }
        if silverGroups.contains(where: { upperGroup.contains($0.uppercased()) }) { return .silver }

        // Scene groups usually have specific naming patterns
        if name.range(of: #"-(SPARKS|GECKOS|AMIABLE)"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return .bronze
        }

        return .unknown
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

    func isAcceptable(_ release: ParsedRelease) -> Bool {
        guard release.resolution >= minResolution else { return false }
        guard release.source.score >= minSource.score else { return false }
        guard release.groupTier != .banned else { return false }
        return true
    }

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

// MARK: - Media Automation Service

@MainActor
final class MediaAutomationService: ObservableObject {
    static let shared = MediaAutomationService()

    @Published private(set) var downloadQueue: [DownloadQueueItem] = []
    @Published private(set) var wantedItems: [WantedItem] = []
    @Published private(set) var recentActivity: [ActivityLogEntry] = []
    @Published private(set) var isMonitoring = false
    @Published var selectedProfile: QualityProfile = QualityProfile.presets[0]

    private let parser = ReleaseParserService.shared
    private var monitoringTask: Task<Void, Never>?

    struct WantedItem: Codable, Identifiable, Sendable {
        let id: String
        let title: String
        let type: ContentType
        var season: Int?
        var episode: Int?
        let traktID: Int?
        let tmdbID: Int?
        let addedAt: Date
        var searchCount: Int
        var lastSearched: Date?
    }

    struct ActivityLogEntry: Codable, Identifiable, Sendable {
        let id: String
        let timestamp: Date
        let type: ActivityType
        let title: String
        let details: String

        enum ActivityType: String, Codable, Sendable {
            case grabbed
            case imported
            case upgraded
            case failed
            case searched
            case added
            case removed
        }
    }

    private init() {
        loadState()
    }

    // MARK: - Queue Management

    func addToQueue(release: ParsedRelease, title: String) {
        let item = DownloadQueueItem(
            id: UUID().uuidString,
            title: title,
            release: release,
            status: .queued,
            progress: 0,
            addedAt: Date(),
            retryCount: 0
        )
        downloadQueue.append(item)
        logActivity(.grabbed, title: title, details: "Added \(release.rawName) to queue")
        saveState()
    }

    func removeFromQueue(id: String) {
        if let item = downloadQueue.first(where: { $0.id == id }) {
            logActivity(.removed, title: item.title, details: "Removed from queue")
        }
        downloadQueue.removeAll { $0.id == id }
        saveState()
    }

    func retryDownload(id: String) {
        if let index = downloadQueue.firstIndex(where: { $0.id == id }) {
            downloadQueue[index].status = .queued
            downloadQueue[index].retryCount += 1
            downloadQueue[index].error = nil
            saveState()
        }
    }

    // MARK: - Wanted Items

    func addWanted(title: String, type: ContentType, traktID: Int? = nil, tmdbID: Int? = nil) {
        let item = WantedItem(
            id: UUID().uuidString,
            title: title,
            type: type,
            traktID: traktID,
            tmdbID: tmdbID,
            addedAt: Date(),
            searchCount: 0
        )
        wantedItems.append(item)
        logActivity(.added, title: title, details: "Added to wanted list")
        saveState()
    }

    func removeWanted(id: String) {
        if let item = wantedItems.first(where: { $0.id == id }) {
            logActivity(.removed, title: item.title, details: "Removed from wanted list")
        }
        wantedItems.removeAll { $0.id == id }
        saveState()
    }

    // MARK: - Release Evaluation

    func evaluateRelease(_ releaseName: String) -> (release: ParsedRelease, acceptable: Bool, score: Int) {
        let release = parser.parse(releaseName)
        let acceptable = selectedProfile.isAcceptable(release)
        return (release, acceptable, release.qualityScore)
    }

    func rankReleases(_ releases: [String]) -> [ParsedRelease] {
        releases
            .map { parser.parse($0) }
            .filter { selectedProfile.isAcceptable($0) }
            .sorted { $0.qualityScore > $1.qualityScore }
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        monitoringTask = Task {
            while !Task.isCancelled {
                await checkForNewReleases()
                try? await Task.sleep(for: .minutes(15))
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    private func checkForNewReleases() async {
        // In production, this would:
        // 1. Check RSS feeds from indexers
        // 2. Search for wanted items
        // 3. Evaluate and grab matching releases

        for var item in wantedItems {
            item.searchCount += 1
            item.lastSearched = Date()
            logActivity(.searched, title: item.title, details: "Automatic search #\(item.searchCount)")
        }
    }

    // MARK: - Activity Logging

    private func logActivity(_ type: ActivityLogEntry.ActivityType, title: String, details: String) {
        let entry = ActivityLogEntry(
            id: UUID().uuidString,
            timestamp: Date(),
            type: type,
            title: title,
            details: details
        )
        recentActivity.insert(entry, at: 0)

        // Keep only last 100 entries
        if recentActivity.count > 100 {
            recentActivity = Array(recentActivity.prefix(100))
        }
    }

    // MARK: - Persistence

    private func loadState() {
        // Load from UserDefaults or file storage
        if let data = UserDefaults.standard.data(forKey: "MediaAutomationState"),
           let state = try? JSONDecoder().decode(AutomationState.self, from: data) {
            downloadQueue = state.queue
            wantedItems = state.wanted
            recentActivity = state.activity
        }
    }

    private func saveState() {
        let state = AutomationState(queue: downloadQueue, wanted: wantedItems, activity: recentActivity)
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: "MediaAutomationState")
        }
    }

    private struct AutomationState: Codable {
        let queue: [DownloadQueueItem]
        let wanted: [WantedItem]
        let activity: [ActivityLogEntry]
    }
}
