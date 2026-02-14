import Foundation

// MARK: - Release Parser Service

final class ReleaseParserService: Sendable {
    static let shared = ReleaseParserService()

    private let goldGroups = Set([
        "FraMeSToR", "BHDStudio", "HiFi", "FLUX", "DON", "EbP", "NCmt",
        "Geek", "hallowed", "CtrlHD", "TayTO", "ZQ", "playBD", "HQMUX",
        "decibeL", "PTer", "PmP", "SiCFoI", "SURFINBIRD"
    ])

    private let silverGroups = Set([
        "SPARKS", "GECKOS", "AMIABLE", "DRONES", "NTb", "TEPES",
        "EDITH", "SiGMA", "W4NK3R", "CMRG", "MZABI", "LEGi0N"
    ])

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
        var title = name
            .replacingOccurrences(of: "\\.", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "_", with: " ")

        if let range = title.range(of: #"\s+(19|20)\d{2}\s+"#, options: .regularExpression) {
            title = String(title[..<range.lowerBound])
        }

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

        if name.range(of: #"-(SPARKS|GECKOS|AMIABLE)"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return .bronze
        }

        return .unknown
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
                try? await Task.sleep(for: .seconds(15 * 60))
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    private func checkForNewReleases() async {
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

        if recentActivity.count > 100 {
            recentActivity = Array(recentActivity.prefix(100))
        }
    }

    // MARK: - Persistence

    private func loadState() {
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
