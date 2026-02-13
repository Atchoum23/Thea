# April 2026 Compliance Checklist

**Created:** January 30, 2026
**Deadline:** April 2026 (App Store requirement)
**Reminder:** Set for late April 2026

---

## Overview

Beginning **April 2026**, all watchOS apps submitted to App Store Connect must:
- Include 64-bit ARM64 support
- Be built with the **watchOS 26 SDK** (Xcode 26)

This file tracks the 5 remaining 2026-specific features requiring Xcode 26.

---

## Compliance Checklist

### 1. iOS 26 / Xcode 26 SDK Build ✅ DONE
**Priority:** CRITICAL (blocking App Store submission)
**Completed:** February 2026

All 4 platform targets build with 0 errors on Xcode 26:
- [x] Thea-macOS
- [x] Thea-iOS
- [x] Thea-watchOS
- [x] Thea-tvOS

---

### 2. Liquid Glass Design Audit ⏳
**Priority:** HIGH (user experience)
**Duration:** 2-3 days
**Status:** Requires visual testing on iOS 26 simulator — cannot be fully verified programmatically

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

### 3. Assistant Schema Conformance ✅ DONE
**Priority:** HIGH (Apple Intelligence integration)
**Completed:** February 13, 2026

**What was done:**
- [x] Created `TheaAssistantSchemas.swift` with 4 schema-conforming types
- [x] `TheaSearchIntent` → `@AppIntent(schema: .system.search)` — in-app search via Siri
- [x] `TheaKnowledgeEntryEntity` → `@AppEntity(schema: .journal.entry)` — knowledge entry entity
- [x] `TheaCreateEntryIntent` → `@AppIntent(schema: .journal.createEntry)` — create entries via Siri
- [x] `TheaSearchEntriesIntent` → `@AppIntent(schema: .journal.search)` — search entries via Siri
- [x] Existing 8 intents + 4 shortcuts preserved in `TheaAppIntents.swift`
- [x] All 4 platforms build with 0 errors

**Note:** The 12 Apple intent domains (books, browser, camera, etc.) don't have a direct "AI assistant" category. The `.system.search` and `.journal.*` schemas are the best fit for Thea's knowledge-base functionality. Testing with Apple Intelligence on-device should be done when hardware is available.

**Remaining:**
- [ ] Test with Apple Intelligence on device
- [ ] Verify Siri can understand natural language queries

---

### 4. SwiftData Migration Evaluation ⏳
**Priority:** MEDIUM (technical debt)
**Duration:** 1-2 days (research/decision)

**Current State:**
- App uses SwiftData (iOS 17+)
- CloudKit sync via `CloudKitService.swift`

**2026 Guidance:**
- SwiftData is production-ready on iOS 18+
- CloudKit integration requirements:
  - No unique constraints
  - All properties optional or have defaults
  - All relationships optional
- Core Data still preferred for complex data models
- Hybrid approach recommended: SwiftData for new features, Core Data for complex legacy

**Tasks:**
- [ ] Audit current data models for CloudKit compatibility
- [ ] Evaluate if SwiftData limitations affect Thea's data model
- [ ] Decision: Full SwiftData vs. hybrid approach
- [ ] Document decision rationale

**Reference:** [SwiftData CloudKit Sync](https://www.hackingwithswift.com/books/ios-swiftui/syncing-swiftdata-with-cloudkit)

---

### 5. Privacy Manifest Audit ✅ DONE
**Priority:** HIGH (App Store rejection risk)
**Completed:** February 13, 2026

**What was done:**
- [x] Updated `iOS/PrivacyInfo.xcprivacy` (was minimal, now comprehensive)
- [x] Created `macOS/PrivacyInfo.xcprivacy` (new)
- [x] Created `watchOS/PrivacyInfo.xcprivacy` (new)
- [x] Created `tvOS/PrivacyInfo.xcprivacy` (new)

**Collected Data Types declared:**
- [x] OtherUserContent — chat messages sent to AI providers (Anthropic, OpenAI, etc.)
- [x] DeviceID — identifierForVendor for CloudKit sync
- [x] Health — HealthKit data in coaching context (iOS/watchOS)
- [x] Fitness — activity data in coaching context (iOS/watchOS)
- [x] PreciseLocation — location context in AI conversations (iOS/macOS)

**Required API Reasons declared:**
- [x] UserDefaults (CA92.1 app-own + 1C8F.1 app-group)
- [x] FileTimestamp (C617.1 container + DDA9.1 display + 3B52.1 user-granted)
- [x] SystemBootTime (35F9.1 elapsed time measurement)
- [x] DiskSpace (E174.1 space check + 85F4.1 display to user)

**Notes:**
- No tracking (NSPrivacyTracking = false)
- No tracking domains
- No third-party analytics SDKs (Thea uses privacy-first local analytics)
- All collected data: not linked to identity, not used for tracking
- KeychainAccess and mlx-swift have their own bundled privacy manifests

**Remaining:**
- [ ] Verify Privacy Nutrition Labels in App Store Connect match manifest

---

## Timeline

| Week | Task | Status |
|------|------|--------|
| Feb 13, 2026 | Privacy Manifest Audit | ✅ |
| Feb 13, 2026 | Assistant Schema Conformance | ✅ |
| Feb 13, 2026 | Xcode 26 SDK Build (all platforms) | ✅ |
| April Week 3 | Liquid Glass audit (needs visual testing) | ⏳ |
| April Week 4 | SwiftData evaluation, final testing | ⏳ |
| April Week 4 | Submit to App Store Connect | ⏳ |

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

3. **Execute remaining sections' tasks (Blockers 2 and 4)**

4. **Update THEA_MASTER_ROADMAP.md when complete**

---

## Notes

- Foundation Models framework integration already complete (`OnDeviceAIService.swift`)
- App Intents already implemented (8 intents, 4 shortcuts + 4 schema-conforming types)
- 3 of 5 blockers completed, 2 remaining need visual testing / research
- Estimated remaining effort: ~3-4 days

---

*Last Updated: February 13, 2026*
