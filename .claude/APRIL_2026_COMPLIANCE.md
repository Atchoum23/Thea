# April 2026 Compliance Checklist

**Created:** January 30, 2026
**Deadline:** April 2026 (App Store requirement)
**Reminder:** Set for late April 2026
**Last Compliance Audit:** February 17, 2026

---

## Overview

Beginning **April 2026**, all watchOS apps submitted to App Store Connect must:
- Include 64-bit ARM64 support
- Be built with the **watchOS 26 SDK** (Xcode 26)

This file tracks the 5 remaining 2026-specific features requiring Xcode 26.

---

## Compliance Checklist

### 1. iOS 26 / Xcode 26 SDK Build ✅ VERIFIED
**Priority:** CRITICAL (blocking App Store submission)
**Status:** COMPLETE as of February 17, 2026

**Verified:**
- [x] Xcode 26.2 (Build 17C52) installed and active
- [x] Swift 6.2.3 (swiftlang-6.2.3.3.21)
- [x] All 4 platform targets have `deploymentTarget: "26.0"` in project.yml
- [x] ARM64-only builds (`ARCHS: arm64`, `ONLY_ACTIVE_ARCH: YES`)
- [x] All 4 schemes build with 0 errors (verified Feb 10, 2026 QA run)

**No action needed** — already building with Xcode 26.2 SDK.

---

### 2. Liquid Glass Design Audit ⏳
**Priority:** HIGH (user experience)
**Duration:** 2-3 days
**Status:** Handled by `mission-uxui.txt`

Apple's new **Liquid Glass** design system introduced in iOS 26:
- Adaptive material system with optical properties (refraction, reflection, lensing)
- Fluid dynamic animations
- Standard UIKit/SwiftUI components auto-adapt

**Tasks:**
- [ ] Audit all custom UI components for Liquid Glass compatibility
- [ ] Review custom views in:
  - [ ] `Shared/UI/Views/` (all custom views)
  - [ ] `Shared/UI/Components/` (reusable components)
  - [ ] Platform-specific views (macOS, iOS, watchOS, tvOS)
- [ ] Test visual appearance on iOS 26 simulator
- [ ] Explicitly adopt Liquid Glass for custom materials if needed
- [ ] Verify dark mode compatibility with Liquid Glass

**Reference:** [Apple Liquid Glass Documentation](https://developer.apple.com/design/human-interface-guidelines/materials)

---

### 3. Assistant Schema Conformance ✅ ASSESSED
**Priority:** HIGH (Apple Intelligence integration)
**Status:** COMPLETE — all applicable schemas implemented

**Assessment (February 17, 2026):**

**Already Implemented (TheaAssistantSchemas.swift):**
- [x] `TheaSearchIntent` → `@AppIntent(schema: .system.search)` — system-wide search
- [x] `TheaCreateEntryIntent` → `@AppIntent(schema: .journal.createEntry)` — knowledge base creation
- [x] `TheaSearchEntriesIntent` → `@AppIntent(schema: .journal.search)` — knowledge base search
- [x] `TheaKnowledgeEntryEntity` → `@AppEntity(schema: .journal.entry)` — entity definition

**Core Intents (TheaAppIntents.swift) — No Schema Required:**
The 8 core intents (AskThea, QuickChat, SummarizeText, CreateProject, StartFocusSession,
LogHealthData, ControlHomeDevice, GetDailySummary) do NOT have matching Apple schemas.
Available schema domains (system, journal, books, browser, photos, camera, whiteboard,
files, presentation, mail, word processor, reader) don't cover AI chat, summarization,
focus timer, health logging, or smart home control.

These intents correctly implement plain `AppIntent` protocol and work with Siri/Shortcuts
without schema conformance. AssistantSchema is optional — it improves Apple Intelligence
discoverability but is not required for App Store submission.

**Additional Intents Already Implemented:**
- TheaControls.swift: 5 iOS Control Center intents (iOS 18+)
- SiriShortcuts.swift: 8 Siri-specific intents
- ShortcutsService.swift: 5 automation intents
- FocusFilterExtension: TheaFocusFilter intent
- IntentHandler.swift: 3 legacy Intents framework handlers

**Reference:** [App Intents for Apple Intelligence](https://developer.apple.com/documentation/appintents/integrating-actions-with-siri-and-apple-intelligence)

---

### 4. SwiftData Migration Evaluation ✅ ASSESSED
**Priority:** MEDIUM (technical debt)
**Status:** COMPLETE — full SwiftData, no migration needed

**Assessment (February 17, 2026):**

**Current State:**
- [x] **100% SwiftData** — 23 `@Model` classes, zero Core Data remnants
- [x] **No NSManagedObject** classes found anywhere in codebase
- [x] **No Core Data imports** (except SQLite3 for schema pre-flight checks)
- [x] CloudKit explicitly disabled (`cloudKitDatabase: .none`) — sync via CloudKitService

**23 SwiftData Models:**
- Core: Conversation, Message, Project, AIProviderConfig, IndexedFile
- Financial: FinancialAccount, FinancialTransaction
- Tracking: HealthSnapshot, DailyScreenTimeRecord, DailyInputStatistics,
  BrowsingRecord, LocationVisitRecord, LifeInsight, WindowState
- Clipboard: TheaClipEntry, TheaClipPinboard, TheaClipPinboardEntry
- Prompt Engineering: UserPromptPreference, CodeErrorRecord, CodeCorrection,
  PromptTemplate, CodeFewShotExample
- Productivity: TheaTask, TheaHabit, TheaHabitEntry

**CloudKit Readiness:**
- [x] All non-optional properties have defaults
- [x] All relationships are optional
- [x] No non-UUID unique constraints
- [x] External storage used for large binary data (images)
- [x] Enums stored as raw strings

**Decision: Full SwiftData** — already fully migrated, no hybrid approach needed.

**ModelContainer Setup:**
- Schema registered in `ModelContainerFactory.swift`
- SQLite pre-flight check in `TheamacOSApp.init()` for migration safety
- App group container: `group.app.theathe`
- In-memory fallback for testing

**Reference:** [SwiftData CloudKit Sync](https://www.hackingwithswift.com/books/ios-swiftui/syncing-swiftdata-with-cloudkit)

---

### 5. Privacy Manifest Audit ✅ COMPLETE
**Priority:** HIGH (App Store rejection risk)
**Status:** COMPLETE as of February 17, 2026

**Completed Tasks:**
- [x] PrivacyInfo.xcprivacy exists in all 4 platform directories (macOS/, iOS/, watchOS/, tvOS/)
- [x] All manifests updated with comprehensive, platform-appropriate declarations
- [x] NSPrivacyTracking = false (no ad tracking)
- [x] NSPrivacyTrackingDomains = empty (API providers are not tracking domains)

**Collected Data Types Declared:**

| Data Type | macOS | iOS | watchOS | tvOS |
|-----------|-------|-----|---------|------|
| OtherUserContent (AI chat) | ✅ | ✅ | ✅ | ✅ |
| DeviceID (CloudKit sync) | ✅ | ✅ | — | — |
| Health (HealthKit coaching) | ✅ | ✅ | ✅ | — |
| Fitness (activity coaching) | ✅ | ✅ | ✅ | — |
| PreciseLocation (AI context) | ✅ | ✅ | — | — |

**Accessed API Types Declared:**

| API Category | Reason Codes | macOS | iOS | watchOS | tvOS |
|--------------|-------------|-------|-----|---------|------|
| UserDefaults | CA92.1 + 1C8F.1 | ✅ | ✅ | ✅ | ✅ |
| FileTimestamp | C617.1 + DDA9.1 + 3B52.1 | ✅ | ✅ | C617.1 only | C617.1 only |
| SystemBootTime | 35F9.1 | ✅ | ✅ | — | — |
| DiskSpace | E174.1 + 85F4.1 | ✅ | ✅ | — | — |

**Third-party SDKs:** KeychainAccess (keychain storage), mlx-swift (local inference),
no analytics SDKs. These are bundled as Swift packages and their own privacy manifests
are included in their respective package bundles.

**Reference:** [Apple Privacy Manifest](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)

---

## Timeline

| Week | Task | Status |
|------|------|--------|
| Feb 17, 2026 | Privacy Manifest audit + update | ✅ |
| Feb 17, 2026 | Assistant Schema assessment | ✅ |
| Feb 17, 2026 | SwiftData evaluation | ✅ |
| Feb 17, 2026 | Xcode 26 SDK verification | ✅ |
| TBD | Liquid Glass design audit | ⏳ (mission-uxui.txt) |
| TBD | Submit to App Store Connect | ⏳ |

---

## Reminder Actions

When you return to this file in late April 2026:

1. **Run this command first:**
   ```bash
   cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
   xcodegen generate && swift build && swift test
   ```

2. **Check Xcode version:**
   ```bash
   xcodebuild -version
   ```

3. **Execute each section's tasks in order**

4. **Update THEA_MASTER_ROADMAP.md when complete**

---

## Notes

- Foundation Models framework integration already complete (`OnDeviceAIService.swift`)
- App Intents already implemented (8 intents, 4 shortcuts, 3 AssistantSchema intents)
- SwiftData fully adopted (23 models, zero Core Data)
- Privacy Manifests comprehensive and consistent across all 4 platforms
- Xcode 26.2 / Swift 6.2.3 already active
- Remaining item: Liquid Glass design audit (handled by mission-uxui.txt)
- Estimated remaining effort: ~2-3 days (Liquid Glass only)

---

*Last Updated: February 17, 2026*
