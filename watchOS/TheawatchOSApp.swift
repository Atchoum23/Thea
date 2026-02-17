import HealthKit
import os.log
import SwiftUI
import WatchKit
import WidgetKit

private let watchLogger = Logger(subsystem: "ai.thea.app.watch", category: "WatchApp")

// MARK: - Watch App Delegate

/// WKApplicationDelegate handles background refresh scheduling and complication updates.
/// Background task fires every ~15 minutes (system-scheduled, best-effort).
final class TheaWatchDelegate: NSObject, WKApplicationDelegate {

    func applicationDidFinishLaunching() {
        scheduleNextBackgroundRefresh()
        watchLogger.info("Watch app launched — background refresh scheduled")
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let refreshTask as WKApplicationRefreshBackgroundTask:
                Task {
                    await performBackgroundRefresh()
                    refreshTask.setTaskCompletedWithSnapshot(false)
                    scheduleNextBackgroundRefresh()
                }

            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                snapshotTask.setTaskCompleted(
                    restoringDefaultState: true,
                    estimatedSnapshotExpiration: .distantFuture,
                    userInfo: nil
                )

            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    // MARK: - Background Refresh Logic

    private func scheduleNextBackgroundRefresh() {
        // Request a background refresh in ~15 minutes
        let refreshDate = Date().addingTimeInterval(15 * 60)
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: refreshDate,
            userInfo: nil
        ) { error in
            if let error {
                watchLogger.error("Background refresh scheduling failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func performBackgroundRefresh() async {
        watchLogger.info("Background refresh started")

        // Read current status from app group shared by iPhone/Mac app
        let defaults = UserDefaults(suiteName: "group.app.theathe")

        // Write a timestamp so the complication knows when it was last refreshed
        defaults?.set(Date().timeIntervalSince1970, forKey: "watch.lastRefresh")

        // Trigger WidgetKit complication reload
        WidgetCenter.shared.reloadTimelines(ofKind: "app.thea.complication")

        watchLogger.info("Background refresh complete — complication timelines reloaded")
    }
}

// MARK: - Watch App Entry Point

@main
struct TheawatchOSApp: App {
    @WKApplicationDelegateAdaptor(TheaWatchDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            watchOSHomeView()
        }
    }
}
