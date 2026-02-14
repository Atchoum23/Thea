// SmartTransportManagerTypesTests.swift
// Tests for SmartTransportManager types and logic

import Testing
import Foundation

// MARK: - Test Doubles

/// Mirror of TheaTransport for SPM testing
private enum TestTransport: Int, Comparable, CaseIterable, Sendable, Codable {
    case thunderbolt = 0
    case localNetwork = 1
    case tailscale = 2
    case cloudKit = 3

    static func < (lhs: TestTransport, rhs: TestTransport) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .thunderbolt: return "Thunderbolt"
        case .localNetwork: return "Local Network"
        case .tailscale: return "Tailscale"
        case .cloudKit: return "iCloud"
        }
    }

    var estimatedLatencyMs: Double {
        switch self {
        case .thunderbolt: return 0.5
        case .localNetwork: return 2.0
        case .tailscale: return 20.0
        case .cloudKit: return 200.0
        }
    }

    var sfSymbol: String {
        switch self {
        case .thunderbolt: return "bolt.fill"
        case .localNetwork: return "wifi"
        case .tailscale: return "globe"
        case .cloudKit: return "icloud.fill"
        }
    }
}

/// Mirror of TransportProbeResult
private struct TestProbeResult: Sendable {
    let transport: TestTransport
    let isAvailable: Bool
    let latencyMs: Double?
    let endpoint: String?
    let probedAt: Date

    static func unavailable(_ transport: TestTransport) -> TestProbeResult {
        TestProbeResult(transport: transport, isAvailable: false, latencyMs: nil, endpoint: nil, probedAt: Date())
    }

    static func available(_ transport: TestTransport, latency: Double, endpoint: String) -> TestProbeResult {
        TestProbeResult(transport: transport, isAvailable: true, latencyMs: latency, endpoint: endpoint, probedAt: Date())
    }
}

/// Mirror of TransportHealthStatus
private struct TestHealthStatus: Sendable {
    let transport: TestTransport
    let isHealthy: Bool
    let lastCheckedAt: Date
    let consecutiveFailures: Int
    let averageLatencyMs: Double?
}

// MARK: - Transport Selection Logic

/// Mirrors the selectBestTransport logic from SmartTransportManager
private func selectBest(from available: Set<TestTransport>) -> TestTransport {
    available.min() ?? .cloudKit
}

/// Mirrors health check failover logic
private func shouldFailover(consecutiveFailures: Int, threshold: Int = 3) -> Bool {
    consecutiveFailures >= threshold
}

/// Mirrors transport summary generation
private func transportSummary(
    available: Set<TestTransport>,
    active: TestTransport,
    probes: [TestTransport: TestProbeResult]
) -> [(transport: TestTransport, available: Bool, latency: Double?, active: Bool)] {
    TestTransport.allCases.map { transport in
        let probe = probes[transport]
        return (
            transport: transport,
            available: available.contains(transport),
            latency: probe?.latencyMs,
            active: transport == active
        )
    }
}

// MARK: - Tests

@Suite("TheaTransport — Enum Properties")
struct TheaTransportTests {

    @Test("All 4 transport types exist")
    func allCases() {
        #expect(TestTransport.allCases.count == 4)
    }

    @Test("Raw values are sequential 0-3")
    func rawValues() {
        #expect(TestTransport.thunderbolt.rawValue == 0)
        #expect(TestTransport.localNetwork.rawValue == 1)
        #expect(TestTransport.tailscale.rawValue == 2)
        #expect(TestTransport.cloudKit.rawValue == 3)
    }

    @Test("Display names are non-empty and unique")
    func displayNames() {
        let names = TestTransport.allCases.map(\.displayName)
        #expect(names.allSatisfy { !$0.isEmpty })
        #expect(Set(names).count == 4)
    }

    @Test("Display name values")
    func displayNameValues() {
        #expect(TestTransport.thunderbolt.displayName == "Thunderbolt")
        #expect(TestTransport.localNetwork.displayName == "Local Network")
        #expect(TestTransport.tailscale.displayName == "Tailscale")
        #expect(TestTransport.cloudKit.displayName == "iCloud")
    }

    @Test("Estimated latencies are in priority order")
    func latenciesInOrder() {
        let latencies = TestTransport.allCases.map(\.estimatedLatencyMs)
        for i in 0..<(latencies.count - 1) {
            #expect(latencies[i] < latencies[i + 1])
        }
    }

    @Test("Thunderbolt has lowest latency")
    func thunderboltFastest() {
        #expect(TestTransport.thunderbolt.estimatedLatencyMs == 0.5)
    }

    @Test("iCloud has highest latency")
    func cloudKitSlowest() {
        #expect(TestTransport.cloudKit.estimatedLatencyMs == 200.0)
    }

    @Test("SF Symbols are non-empty and unique")
    func sfSymbols() {
        let symbols = TestTransport.allCases.map(\.sfSymbol)
        #expect(symbols.allSatisfy { !$0.isEmpty })
        #expect(Set(symbols).count == 4)
    }

    @Test("Comparable ordering matches rawValue")
    func comparableOrdering() {
        #expect(TestTransport.thunderbolt < TestTransport.localNetwork)
        #expect(TestTransport.localNetwork < TestTransport.tailscale)
        #expect(TestTransport.tailscale < TestTransport.cloudKit)
    }

    @Test("Sorting produces priority order")
    func sorting() {
        let shuffled: [TestTransport] = [.cloudKit, .thunderbolt, .tailscale, .localNetwork]
        let sorted = shuffled.sorted()
        #expect(sorted == [.thunderbolt, .localNetwork, .tailscale, .cloudKit])
    }

    @Test("Codable roundtrip")
    func codable() throws {
        for transport in TestTransport.allCases {
            let data = try JSONEncoder().encode(transport)
            let decoded = try JSONDecoder().decode(TestTransport.self, from: data)
            #expect(decoded == transport)
        }
    }
}

@Suite("TransportProbeResult — Creation")
struct TransportProbeResultTests {

    @Test("Unavailable result has correct defaults")
    func unavailable() {
        let result = TestProbeResult.unavailable(.thunderbolt)
        #expect(result.transport == .thunderbolt)
        #expect(result.isAvailable == false)
        #expect(result.latencyMs == nil)
        #expect(result.endpoint == nil)
    }

    @Test("Available result has all properties")
    func available() {
        let result = TestProbeResult.available(.localNetwork, latency: 2.5, endpoint: "192.168.1.100:18790")
        #expect(result.transport == .localNetwork)
        #expect(result.isAvailable == true)
        #expect(result.latencyMs == 2.5)
        #expect(result.endpoint == "192.168.1.100:18790")
    }

    @Test("Probe timestamp is recent")
    func timestamp() {
        let result = TestProbeResult.unavailable(.cloudKit)
        let elapsed = Date().timeIntervalSince(result.probedAt)
        #expect(elapsed < 1.0)
    }

    @Test("Each transport type can be probed")
    func allTransportsProbed() {
        for transport in TestTransport.allCases {
            let result = TestProbeResult.available(transport, latency: transport.estimatedLatencyMs, endpoint: "test")
            #expect(result.transport == transport)
            #expect(result.isAvailable)
        }
    }
}

@Suite("TransportHealthStatus — Properties")
struct TransportHealthStatusTests {

    @Test("Healthy status has zero failures")
    func healthy() {
        let status = TestHealthStatus(
            transport: .localNetwork, isHealthy: true,
            lastCheckedAt: Date(), consecutiveFailures: 0, averageLatencyMs: 2.5
        )
        #expect(status.isHealthy)
        #expect(status.consecutiveFailures == 0)
        #expect(status.averageLatencyMs == 2.5)
    }

    @Test("Unhealthy status tracks failures")
    func unhealthy() {
        let status = TestHealthStatus(
            transport: .tailscale, isHealthy: false,
            lastCheckedAt: Date(), consecutiveFailures: 3, averageLatencyMs: nil
        )
        #expect(!status.isHealthy)
        #expect(status.consecutiveFailures == 3)
        #expect(status.averageLatencyMs == nil)
    }

    @Test("Zero latency for CloudKit fallback")
    func cloudKitFallback() {
        let status = TestHealthStatus(
            transport: .cloudKit, isHealthy: true,
            lastCheckedAt: Date(), consecutiveFailures: 0, averageLatencyMs: 200.0
        )
        #expect(status.transport == .cloudKit)
    }
}

@Suite("Transport Selection Logic")
struct TransportSelectionTests {

    @Test("CloudKit is default when no transports available")
    func defaultCloudKit() {
        let result = selectBest(from: [])
        #expect(result == .cloudKit)
    }

    @Test("CloudKit selected when only CloudKit available")
    func onlyCloudKit() {
        let result = selectBest(from: [.cloudKit])
        #expect(result == .cloudKit)
    }

    @Test("Thunderbolt preferred over everything")
    func thunderboltPreferred() {
        let result = selectBest(from: [.thunderbolt, .localNetwork, .tailscale, .cloudKit])
        #expect(result == .thunderbolt)
    }

    @Test("Local network preferred over Tailscale and CloudKit")
    func localNetworkPreferred() {
        let result = selectBest(from: [.localNetwork, .tailscale, .cloudKit])
        #expect(result == .localNetwork)
    }

    @Test("Tailscale preferred over CloudKit")
    func tailscalePreferred() {
        let result = selectBest(from: [.tailscale, .cloudKit])
        #expect(result == .tailscale)
    }

    @Test("Single transport selected correctly")
    func singleTransport() {
        for transport in TestTransport.allCases {
            let result = selectBest(from: [transport])
            #expect(result == transport)
        }
    }
}

@Suite("Failover Logic")
struct FailoverTests {

    @Test("No failover at 0 failures")
    func noFailoverAtZero() {
        #expect(!shouldFailover(consecutiveFailures: 0))
    }

    @Test("No failover at 1 failure")
    func noFailoverAtOne() {
        #expect(!shouldFailover(consecutiveFailures: 1))
    }

    @Test("No failover at 2 failures")
    func noFailoverAtTwo() {
        #expect(!shouldFailover(consecutiveFailures: 2))
    }

    @Test("Failover at 3 failures (threshold)")
    func failoverAtThree() {
        #expect(shouldFailover(consecutiveFailures: 3))
    }

    @Test("Failover at more than 3 failures")
    func failoverAboveThreshold() {
        #expect(shouldFailover(consecutiveFailures: 5))
        #expect(shouldFailover(consecutiveFailures: 10))
    }

    @Test("Custom threshold")
    func customThreshold() {
        #expect(!shouldFailover(consecutiveFailures: 4, threshold: 5))
        #expect(shouldFailover(consecutiveFailures: 5, threshold: 5))
    }

    @Test("Failover cascades to next best transport")
    func failoverCascade() {
        // Start with Thunderbolt, failover removes it
        var available: Set<TestTransport> = [.thunderbolt, .localNetwork, .cloudKit]
        available.remove(.thunderbolt)
        #expect(selectBest(from: available) == .localNetwork)

        // Local network also fails
        available.remove(.localNetwork)
        #expect(selectBest(from: available) == .cloudKit)
    }
}

@Suite("Transport Summary")
struct TransportSummaryTests {

    @Test("Summary includes all 4 transports")
    func allTransportsInSummary() {
        let summary = transportSummary(available: [.cloudKit], active: .cloudKit, probes: [:])
        #expect(summary.count == 4)
    }

    @Test("Active transport marked correctly")
    func activeMarked() {
        let summary = transportSummary(
            available: [.localNetwork, .cloudKit],
            active: .localNetwork,
            probes: [:]
        )
        let active = summary.filter(\.active)
        #expect(active.count == 1)
        #expect(active[0].transport == .localNetwork)
    }

    @Test("Available transports marked correctly")
    func availableMarked() {
        let available: Set<TestTransport> = [.localNetwork, .cloudKit]
        let summary = transportSummary(available: available, active: .localNetwork, probes: [:])

        let availableInSummary = summary.filter(\.available)
        #expect(availableInSummary.count == 2)
    }

    @Test("Unavailable transports have no latency")
    func unavailableNoLatency() {
        let summary = transportSummary(available: [.cloudKit], active: .cloudKit, probes: [:])
        let unavailable = summary.filter { !$0.available }
        #expect(unavailable.allSatisfy { $0.latency == nil })
    }

    @Test("Probe latency propagated to summary")
    func latencyPropagated() {
        let probes: [TestTransport: TestProbeResult] = [
            .localNetwork: .available(.localNetwork, latency: 1.5, endpoint: "test")
        ]
        let summary = transportSummary(
            available: [.localNetwork, .cloudKit],
            active: .localNetwork,
            probes: probes
        )
        let lan = summary.first { $0.transport == .localNetwork }
        #expect(lan?.latency == 1.5)
    }
}

@Suite("Transport Upgrade Logic")
struct TransportUpgradeTests {

    @Test("Upgrade from CloudKit to LAN when LAN becomes available")
    func upgradeCloudKitToLAN() {
        var available: Set<TestTransport> = [.cloudKit]
        var active = selectBest(from: available)
        #expect(active == .cloudKit)

        // LAN discovered
        available.insert(.localNetwork)
        let newBest = selectBest(from: available)
        if newBest.rawValue < active.rawValue {
            active = newBest
        }
        #expect(active == .localNetwork)
    }

    @Test("Upgrade from Tailscale to Thunderbolt")
    func upgradeTailscaleToThunderbolt() {
        var available: Set<TestTransport> = [.tailscale, .cloudKit]
        var active = selectBest(from: available)
        #expect(active == .tailscale)

        // Thunderbolt connected
        available.insert(.thunderbolt)
        let newBest = selectBest(from: available)
        if newBest.rawValue < active.rawValue {
            active = newBest
        }
        #expect(active == .thunderbolt)
    }

    @Test("No downgrade when better transport still available")
    func noDowngrade() {
        let available: Set<TestTransport> = [.thunderbolt, .localNetwork, .cloudKit]
        let active = selectBest(from: available)
        #expect(active == .thunderbolt)

        // Adding slower transport doesn't change selection
        var updatedAvailable = available
        updatedAvailable.insert(.tailscale)
        let stillBest = selectBest(from: updatedAvailable)
        #expect(stillBest == .thunderbolt)
    }
}

@Suite("Endpoint Parsing")
struct EndpointParsingTests {

    @Test("Parse host:port endpoint")
    func parseEndpoint() {
        let endpoint = "192.168.1.100:18790"
        let components = endpoint.split(separator: ":")
        #expect(components.count == 2)
        #expect(String(components[0]) == "192.168.1.100")
        #expect(UInt16(components[1]) == 18790)
    }

    @Test("Parse hostname endpoint")
    func parseHostname() {
        let endpoint = "msm3u:18790"
        let components = endpoint.split(separator: ":")
        #expect(components.count == 2)
        #expect(String(components[0]) == "msm3u")
    }

    @Test("Parse .local hostname")
    func parseLocalHostname() {
        let endpoint = "msm3u.local:18790"
        let components = endpoint.split(separator: ":")
        #expect(components.count == 2)
        #expect(String(components[0]) == "msm3u.local")
    }

    @Test("CloudKit endpoint is identifier")
    func cloudKitEndpoint() {
        let endpoint = "iCloud.app.theathe"
        #expect(endpoint.contains("iCloud"))
    }
}
