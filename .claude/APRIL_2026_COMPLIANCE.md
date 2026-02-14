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

### 1. iOS 26 / Xcode 26 SDK Build ⏳
**Priority:** CRITICAL (blocking App Store submission)
**Duration:** 1-2 days

**Tasks:**
- [ ] Download and install Xcode 26 when available
- [ ] Build all 4 platform targets with Xcode 26:
  - [ ] Thea-macOS
  - [ ] Thea-iOS
  - [ ] Thea-watchOS
  - [ ] Thea-tvOS
- [ ] Test ARM64 compatibility on:
  - [ ] Apple Watch Series 9/10
  - [ ] Apple Watch Ultra 2
- [ ] Resolve any deprecation warnings
- [ ] Update minimum deployment targets if needed

**Verification:**
```bash
xcodebuild -project Thea.xcodeproj -scheme Thea-watchOS -sdk watchos26.0 build
```

---

### 2. Liquid Glass Design Audit ⏳
**Priority:** HIGH (user experience)
**Duration:** 2-3 days

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

### 3. Assistant Schema Conformance ⏳
**Priority:** HIGH (Apple Intelligence integration)
**Duration:** 3-4 days

Per Apple 2026 guidance: *"Apps without intents feel invisible in an AI-first OS"*

**Current State:**
- 8 App Intents implemented in `Shared/AppIntents/TheaAppIntents.swift`
- TheaShortcuts provider with 4 app shortcuts

**Tasks:**
- [ ] Conform existing intents to **Assistant Schemas**:
  - [ ] AskTheaIntent → conform to assistant messaging schema
  - [ ] SummarizeTextIntent → conform to assistant content schema
  - [ ] StartFocusSessionIntent → conform to assistant productivity schema
- [ ] Add **entity definitions** for semantic understanding:
  - [ ] ConversationEntity
  - [ ] ProjectEntity
  - [ ] KnowledgeItemEntity
- [ ] Expose additional core actions as intents:
  - [ ] SearchConversationsIntent
  - [ ] SearchKnowledgeIntent
  - [ ] TogglePrivacyModeIntent
- [ ] Test with Apple Intelligence on device
- [ ] Verify Siri can understand natural language queries

**Reference:** [App Intents for Apple Intelligence](https://developer.apple.com/documentation/appintents/integrating-actions-with-siri-and-apple-intelligence)

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

### 5. Privacy Manifest Audit ⏳
**Priority:** HIGH (App Store rejection risk)
**Duration:** 1 day

**Background:**
- Required since May 2024
- 12% rejection rate for violations (as of 2025)
- 2025 update: Specific third-party recipient disclosure required

**Tasks:**
- [ ] Create/update `PrivacyInfo.xcprivacy` file
- [ ] Declare all data types collected:
  - [ ] User identifiers
  - [ ] Device identifiers
  - [ ] Location data
  - [ ] Health data
  - [ ] Usage data
- [ ] Justify API usage with specific reason codes:
  - [ ] File timestamp APIs
  - [ ] System boot time APIs
  - [ ] Disk space APIs
  - [ ] User defaults APIs
- [ ] Disclose third-party SDKs with data access:
  - [ ] KeychainAccess
  - [ ] mlx-swift
  - [ ] OpenAI SDK
  - [ ] Any analytics SDKs
- [ ] Verify Privacy Nutrition Labels match manifest

**Reference:** [Apple Privacy Manifest](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)

---

## Timeline

| Week | Task | Status |
|------|------|--------|
| April Week 1 | Install Xcode 26, initial build test | ⏳ |
| April Week 2 | Fix build errors, Privacy Manifest | ⏳ |
| April Week 3 | Liquid Glass audit, Assistant Schemas | ⏳ |
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

3. **Execute each section's tasks in order**

4. **Update THEA_MASTER_ROADMAP.md when complete**

---

## Notes

- Foundation Models framework integration already complete (`OnDeviceAIService.swift`)
- App Intents already implemented (8 intents, 4 shortcuts)
- These 5 items are polish/compliance, not new features
- Estimated total effort: ~1-2 weeks

---

*Last Updated: January 30, 2026*
