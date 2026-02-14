# Thea "Living Inside the OS" - Complete Implementation Plan

> **Goal**: Transform Thea into a system-level intelligence layer with maximum **Omniscience**, **Omnipotence**, and **Omnipresence** across all Apple platforms (iOS, macOS, watchOS, tvOS, visionOS).

---

## Executive Summary

Thea will become a "living" intelligence layer that:
- **Sees everything**: Apps, files, clipboard, notifications, network, input, health, location
- **Controls everything**: Execute commands, control apps, modify settings, automate workflows
- **Is everywhere**: Menu bar, widgets, Siri, hotkeys, Dynamic Island, Lock Screen, Services menu

---

## Phase Overview & Progress

| Phase | Description | Status | Progress |
|-------|-------------|--------|----------|
| 1 | Foundation & Unified Context Engine | ✅ COMPLETE | 100% |
| 2 | App Extension Targets (12+ extensions) | ✅ COMPLETE | 100% |
| 3 | Deep System Awareness - macOS | ✅ COMPLETE | 100% |
| 4 | Deep System Awareness - iOS | 🔄 IN PROGRESS | 60% |
| 5 | System UI Omnipresence | ⏳ PENDING | 0% |
| 6 | Cross-Device Intelligence | ⏳ PENDING | 0% |
| 7 | System Control (Omnipotence) | ⏳ PENDING | 0% |
| 8 | Advanced Features | ⏳ PENDING | 0% |

---

## Phase 1: Foundation & Unified Context Engine ✅

### Completed Components
- **UnifiedContextEngine** (`Shared/Context/UnifiedContextEngine.swift`)
  - Central hub for all context data
  - Real-time context aggregation
  - Context change notifications

- **ContextProviders** (`Shared/Context/Providers/`)
  - `LocationContextProvider.swift` - GPS, geofencing, significant location changes
  - `TemporalContextProvider.swift` - Time-based context, calendar awareness
  - `DeviceContextProvider.swift` - Battery, connectivity, device state
  - `AppContextProvider.swift` - Foreground app, app usage patterns
  - `UserContextProvider.swift` - User preferences, behavior patterns

- **ContextMemory** (`Shared/Context/ContextMemory.swift`)
  - Persistent context storage
  - Historical context queries
  - Pattern detection

### Key Technical Decisions
- Used `@MainActor` for UI-bound context updates
- Implemented `Sendable` conformance for thread-safe data passing
- App Groups (`group.app.thea`) for cross-extension data sharing

---

## Phase 2: App Extension Targets ✅

### Created Extensions (12 total)

| Extension | Bundle ID | Platform | Purpose |
|-----------|-----------|----------|---------|
| ShareExtension | `app.thea.ios.share` | iOS | Receive shared content |
| WidgetExtension | `app.thea.ios.widget` | iOS/macOS | Home screen widgets |
| KeyboardExtension | `app.thea.ios.keyboard` | iOS | Custom keyboard |
| NotificationServiceExtension | `app.thea.ios.notification` | iOS | Rich notifications |
| FinderSyncExtension | `app.thea.macos.finder` | macOS | Finder integration |
| SafariExtension | `app.thea.*.safari` | iOS/macOS | Browser integration |
| FocusFilterExtension | `app.thea.ios.focusfilter` | iOS | Focus mode integration |
| CredentialsExtension | `app.thea.ios.credentials` | iOS | Password autofill |
| QuickLookExtension | `app.thea.macos.quicklook` | macOS | File previews |
| IntentsExtension | `app.thea.ios.intents` | iOS | Siri/Shortcuts |

### Extension Locations
```
Extensions/
├── ShareExtension/
│   ├── ShareViewController.swift
│   ├── Info.plist
│   └── ShareExtension.entitlements
├── WidgetExtension/
│   ├── TheaWidgets.swift
│   ├── Info.plist
│   └── WidgetExtension.entitlements
├── KeyboardExtension/
│   ├── KeyboardViewController.swift
│   ├── Info.plist
│   └── KeyboardExtension.entitlements
├── NotificationServiceExtension/
│   ├── NotificationService.swift
│   ├── Info.plist
│   └── NotificationServiceExtension.entitlements
├── FinderSyncExtension/
│   ├── FinderSync.swift
│   ├── Info.plist
│   └── FinderSyncExtension.entitlements
├── SafariExtension/
│   ├── SafariWebExtensionHandler.swift
│   ├── Info.plist
│   ├── SafariExtension.entitlements
│   └── Resources/
│       ├── manifest.json
│       ├── background.js
│       ├── content.js
│       ├── content.css
│       └── popup/
│           ├── popup.html
│           └── popup.js
├── FocusFilterExtension/
│   ├── FocusFilterExtension.swift
│   ├── Info.plist
│   └── FocusFilterExtension.entitlements
├── CredentialsExtension/
│   ├── CredentialProviderViewController.swift
│   ├── Info.plist
│   └── CredentialsExtension.entitlements
├── QuickLookExtension/
│   ├── PreviewViewController.swift
│   ├── Info.plist
│   └── QuickLookExtension.entitlements
├── IntentsExtension/
│   ├── IntentHandler.swift
│   ├── Info.plist
│   └── IntentsExtension.entitlements
└── SpotlightImporter/ (integrated into main app)
```

---

## Phase 3: Deep System Awareness - macOS ✅

### Created Observers

| Observer | File | Purpose |
|----------|------|---------|
| AccessibilityObserver | `Shared/Platforms/macOS/AccessibilityObserver.swift` | Window focus, text selection, UI elements |
| FileSystemObserver | `Shared/Platforms/macOS/FileSystemObserver.swift` | FSEvents file monitoring, project detection |
| ProcessObserver | `Shared/Platforms/macOS/ProcessObserver.swift` | Process launch/terminate, CPU/memory |
| NetworkObserver | `Shared/Platforms/macOS/NetworkObserver.swift` | Network state via NWPathMonitor |
| MediaObserver | `Shared/Platforms/macOS/MediaObserver.swift` | Now Playing info |
| ClipboardObserver | `Shared/Platforms/macOS/ClipboardObserver.swift` | Clipboard history |
| DisplayObserver | `Shared/Platforms/macOS/DisplayObserver.swift` | Display configuration |
| PowerObserver | `Shared/Platforms/macOS/PowerObserver.swift` | Battery, power state |
| ServicesHandler | `Shared/Platforms/macOS/ServicesHandler.swift` | macOS Services menu |
| MacSystemObserver | `Shared/Platforms/macOS/MacSystemObserver.swift` | Unified coordinator |

### Services Menu Integration (Info.plist)
Added NSServices entries for:
- "Ask Thea about Selection" (⌘T)
- "Summarize with Thea" (⌘S)
- "Translate with Thea"
- "Add to Thea Memory"
- "Explain Code with Thea"

### Key Data Models
```swift
// MacSystemSnapshot - aggregated system state
public struct MacSystemSnapshot: Equatable, Sendable {
    let focusedApp: String?
    let focusedAppBundleID: String?
    let focusedWindow: String?
    let selectedText: String?
    let runningProcesses: Int
    let topProcesses: [ProcessInfo]
    let networkState: NetworkState
    let networkMetrics: NetworkMetrics
    let nowPlaying: NowPlayingInfo?
    let playbackState: PlaybackState
    let displays: [DisplayInfo]
    let mainDisplay: DisplayInfo?
    let powerState: PowerState
    let recentClipboardItems: [ClipboardItem]
    let recentFileEvents: [FileSystemEvent]
    let activeProjectType: ProjectType?
}
```

---

## Phase 4: Deep System Awareness - iOS 🔄

### Completed Components

| Component | File | Status |
|-----------|------|--------|
| ScreenTimeObserver | `Shared/Platforms/iOS/ScreenTimeObserver.swift` | ✅ |
| PhotoIntelligenceProvider | `Shared/Platforms/iOS/PhotoIntelligenceProvider.swift` | ✅ |
| MotionContextProvider | `Shared/Platforms/iOS/MotionContextProvider.swift` | ✅ |

### Remaining Components

| Component | Purpose | Status |
|-----------|---------|--------|
| HealthKitProvider | Health data integration | ⏳ |
| NotificationObserver | Notification patterns | ⏳ |
| iOSSystemObserver | Unified iOS coordinator | ⏳ |

---

## Phase 5: System UI Omnipresence ⏳

### Planned Components

#### macOS
- [ ] Menu Bar App with popover
- [ ] Global keyboard shortcuts (⌘⇧Space)
- [ ] Spotlight-like quick prompt
- [ ] Notification Center widget

#### iOS
- [ ] Dynamic Island integration (Live Activities)
- [ ] Lock Screen widgets
- [ ] Control Center widget
- [ ] Interactive notifications

#### All Platforms
- [ ] Siri Shortcuts integration
- [ ] App Intents for system-wide actions

---

## Phase 6: Cross-Device Intelligence ⏳

### Planned Features
- [ ] Handoff support (NSUserActivity)
- [ ] Universal Clipboard integration
- [ ] CloudKit sync for context
- [ ] Device-to-device communication
- [ ] Shared memory across devices

---

## Phase 7: System Control (Omnipotence) ⏳

### Planned Capabilities

#### macOS
- [ ] AppleScript/JXA execution
- [ ] Accessibility API control
- [ ] System Preferences automation
- [ ] File system operations

#### iOS
- [ ] Shortcuts automation
- [ ] URL scheme launching
- [ ] Share sheet integration

---

## Phase 8: Advanced Features ⏳

### Planned Features
- [ ] On-device ML for context understanding
- [ ] Predictive assistance
- [ ] Workflow automation
- [ ] Natural language commands
- [ ] Proactive suggestions

---

## Errors Encountered & Fixes

### 1. KeyboardViewController Missing Type
**Error**: `Cannot find type 'KeyboardView' in scope`
**File**: `Extensions/KeyboardExtension/KeyboardViewController.swift`
**Fix**: Removed unused `private var keyboardView: KeyboardView!` variable

### 2. NotificationService Sendable Warnings
**Error**: Swift 6 concurrency warnings about Sendable closures
**File**: `Extensions/NotificationServiceExtension/NotificationService.swift`
**Fix**:
```swift
@preconcurrency import UserNotifications
// Changed closure to:
@escaping @Sendable (UNNotificationContent) -> Void
// Wrapped calls in:
DispatchQueue.main.async { ... }
```

### 3. FocusFilterExtension Static Property Errors
**Error**: `Static property 'typeDisplayRepresentation' is not concurrency-safe`
**File**: `Extensions/FocusFilterExtension/FocusFilterExtension.swift`
**Fix**: Changed `static var` to `static let` for all AppEnum properties:
```swift
static let typeDisplayRepresentation: TypeDisplayRepresentation = "Assistance Level"
static let caseDisplayRepresentations: [AssistanceLevel: DisplayRepresentation] = [...]
```

### 4. INSearchForMessagesIntent API Change
**Error**: `Value of type 'INSearchForMessagesIntent' has no member 'searchTerm'`
**File**: `Extensions/IntentsExtension/IntentHandler.swift`
**Fix**: Used `intent.senders?.first?.displayName` instead

### 5. QuickLookExtension Concurrency Crossing
**Error**: `Passing closure as a 'sending' parameter risks causing data races`
**File**: `Extensions/QuickLookExtension/PreviewViewController.swift`
**Fix**: Made method `nonisolated` and used `DispatchQueue.main.async`:
```swift
nonisolated func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping @Sendable (Error?) -> Void) {
    do {
        let data = try Data(contentsOf: url)
        DispatchQueue.main.async { [weak self] in
            self?.handlePreviewOfFile(data: data, url: url, completionHandler: handler)
        }
    } catch {
        DispatchQueue.main.async { handler(error) }
    }
}
```

### 6. SpotlightImporter CSImportExtensionRequestHandler
**Error**: `Cannot find type 'CSImportExtensionRequestHandler' in scope`
**Resolution**: Removed as separate extension target; integrated Spotlight indexing into main app using `CSSearchableIndex` API

### 7. Database Lock Error
**Error**: `database is locked - Possibly two concurrent builds running`
**Resolution**: Killed lingering xcodebuild processes with `pkill -9 xcodebuild`

### 8. ProcessInfo Missing Equatable
**Error**: Compiler error about ProcessInfo not conforming to Equatable
**File**: `Shared/Platforms/macOS/ProcessObserver.swift`
**Fix**: Added Equatable conformance with custom `==` implementation

### 9. ClipboardItem Missing Equatable
**Error**: Compiler error in MacSystemSnapshot
**File**: `Shared/Platforms/macOS/ClipboardObserver.swift`
**Fix**: Added `Equatable` to struct declaration

---

## Key Lessons Learned

### 1. Swift 6 Concurrency
- **Always use `@preconcurrency import`** for frameworks with non-Sendable types
- **Prefer `static let` over `static var`** for immutable static properties
- **Use `nonisolated`** for protocol methods that need to be called from any context
- **Wrap callbacks in `DispatchQueue.main.async`** when crossing isolation boundaries

### 2. Extension Development
- **App Groups are essential** for data sharing between extensions
- **Darwin notifications** work for inter-process communication
- **Each extension needs its own bundle ID and entitlements**
- **SpotlightImporter doesn't have a modern Swift API** - use CSSearchableIndex instead

### 3. Actor-Based Design
- **Actors prevent data races** but require `await` for access
- **Mix actors with @MainActor classes** carefully
- **Use `nonisolated(unsafe)`** sparingly for callbacks that can't be async

### 4. macOS Specifics
- **Accessibility requires user permission** - check with `AXIsProcessTrusted()`
- **FSEvents is efficient** for file system monitoring
- **IOKit provides battery info** without special entitlements
- **NWPathMonitor** works without Network Extension entitlements

### 5. Build System
- **XcodeGen (`project.yml`)** manages all targets
- **Run `xcodegen generate`** after modifying project.yml
- **Kill zombie xcodebuild processes** if database locks occur

---

## File Structure Summary

```
Thea/
├── Shared/
│   ├── Context/
│   │   ├── UnifiedContextEngine.swift
│   │   ├── ContextMemory.swift
│   │   └── Providers/
│   │       ├── LocationContextProvider.swift
│   │       ├── TemporalContextProvider.swift
│   │       ├── DeviceContextProvider.swift
│   │       ├── AppContextProvider.swift
│   │       └── UserContextProvider.swift
│   ├── Platforms/
│   │   ├── macOS/
│   │   │   ├── AccessibilityObserver.swift
│   │   │   ├── FileSystemObserver.swift
│   │   │   ├── ProcessObserver.swift
│   │   │   ├── NetworkObserver.swift
│   │   │   ├── MediaObserver.swift
│   │   │   ├── ClipboardObserver.swift
│   │   │   ├── DisplayObserver.swift
│   │   │   ├── PowerObserver.swift
│   │   │   ├── ServicesHandler.swift
│   │   │   └── MacSystemObserver.swift
│   │   └── iOS/
│   │       ├── ScreenTimeObserver.swift
│   │       ├── PhotoIntelligenceProvider.swift
│   │       └── MotionContextProvider.swift
│   └── Resources/
│       └── Info.plist (with NSServices)
├── Extensions/
│   ├── ShareExtension/
│   ├── WidgetExtension/
│   ├── KeyboardExtension/
│   ├── NotificationServiceExtension/
│   ├── FinderSyncExtension/
│   ├── SafariExtension/
│   ├── FocusFilterExtension/
│   ├── CredentialsExtension/
│   ├── QuickLookExtension/
│   └── IntentsExtension/
├── project.yml (XcodeGen configuration)
└── IMPLEMENTATION_PLAN.md (this file)
```

---

## Build Commands

```bash
# Generate Xcode project
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
xcodegen generate

# Build macOS
xcodebuild -project Thea.xcodeproj -scheme Thea-macOS -destination 'platform=macOS' build

# Build iOS
xcodebuild -project Thea.xcodeproj -scheme Thea-iOS -destination 'generic/platform=iOS' build

# Kill stuck builds
pkill -9 xcodebuild
```

---

## Next Steps (Resume From Here)

1. **Complete Phase 4**: Create remaining iOS observers
   - HealthKitProvider
   - NotificationObserver
   - iOSSystemObserver (unified coordinator)

2. **Build iOS target** to verify Phase 4 components

3. **Start Phase 5**: System UI Omnipresence
   - Menu bar app (macOS)
   - Dynamic Island / Live Activities (iOS)
   - Global hotkeys

4. **Continue through Phases 6-8**

5. **Final verification**: Build all targets with zero errors/warnings

---

## Version History

| Date | Version | Changes |
|------|---------|---------|
| 2026-01-27 | 0.1 | Initial plan created |
| 2026-01-27 | 0.2 | Phase 1 completed |
| 2026-01-27 | 0.3 | Phase 2 completed (12 extensions) |
| 2026-01-27 | 0.4 | Phase 3 completed (macOS observers) |
| 2026-01-27 | 0.5 | Phase 4 in progress (iOS observers) |

---

*Last Updated: 2026-01-27*
