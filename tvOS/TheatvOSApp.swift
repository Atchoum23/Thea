import SwiftUI

@main
struct TheatvOSApp: App {
    @StateObject private var healthMonitor = HealthMonitorService.shared
    @StateObject private var traktService = TraktService.shared
    @StateObject private var streamingService = StreamingAvailabilityService.shared
    @StateObject private var mediaService = MediaAutomationService.shared

    var body: some Scene {
        WindowGroup {
            TVEnhancedHomeView()
                .environmentObject(healthMonitor)
                .environmentObject(traktService)
                .environmentObject(streamingService)
                .environmentObject(mediaService)
                .task {
                    // Start background services
                    healthMonitor.startMonitoring(interval: 120)

                    // Refresh Trakt data if authenticated
                    if traktService.isAuthenticated {
                        await traktService.refreshAll()
                    }
                }
        }
    }
}
