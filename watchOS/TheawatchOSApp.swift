import SwiftUI

@main
struct TheawatchOSApp: App {
    var body: some Scene {
        WindowGroup {
            watchOSHomeView()
                .task {
                    // Initialize sync singletons (non-blocking)
                    _ = CloudKitService.shared
                    _ = PreferenceSyncEngine.shared
                }
        }
    }
}
