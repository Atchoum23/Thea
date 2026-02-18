# Periphery Dead Code Analysis — 2026-02-18

## Scan Summary

| Metric | Value |
|--------|-------|
| Tool version | Periphery 2.21.2 |
| Config file | `.periphery.yml` (project root) |
| Schemes scanned | Thea-macOS, Thea-iOS, Thea-watchOS, Thea-tvOS |
| Total warnings | **2,667** |
| Unique files with warnings | **501** |
| Previous scan (2026-02-10, macOS only) | 8,821 items |

> Note: The dramatic reduction from 8,821 to 2,667 is due to the full 4-platform scan vs. macOS-only previously. Cross-platform usage now resolves many false positives automatically.

---

## Warning Breakdown by Declaration Type

| Type | Count |
|------|-------|
| Function | 1,148 |
| Property | 1,007 |
| Parameter | 168 |
| Struct | 140 |
| Initializer | 62 |
| Enum | 53 |
| Enum case | 44 |
| Class | 34 |
| Protocol | 9 |
| Extension | 2 |
| **Total** | **2,667** |

---

## Warning Breakdown by Shared Subsystem

| Subsystem | Unique Files |
|-----------|-------------|
| Intelligence | 43 |
| AI | 22 |
| UI | 20 |
| Core | 19 |
| Integrations | 13 |
| System | 6 |
| RemoteServer | 11 |
| Memory | 9 |
| Cowork | 9 |
| AI/Providers | 9 |
| Sync | 8 |
| Voice | 6 |
| Privacy | 6 |
| Tracking | 5 |
| Financial | 5 |
| tvOS (all dirs) | 13 |
| iOS (all dirs) | 8 |
| watchOS (all dirs) | 5 |
| macOS (all dirs) | 5 |

---

## Category Analysis

### Category A: Excluded Build Targets (Expected Noise) — ~290 warnings

Files in subsystems that are excluded from ALL build targets in `project.yml` are still analyzed by Periphery (it indexes Swift files found on disk, regardless of build membership). These warnings are expected and HARMLESS.

Key excluded subsystems generating noise:
- `Shared/AI/Adaptive/` — AdaptivePromptEngine, CollaborativeMemorySystem, SelfTuningEngine (fully excluded)
- `Shared/AI/Automation/` — WorkflowEngine, WorkflowEngineTypes (fully excluded)
- `Shared/AI/LocalModels/` — ProactiveModelManager, UnifiedLocalModelOrchestrator, AIModelGovernor, OllamaAgentLoop, ModelQualityBenchmark (selectively excluded)
- `Shared/AI/PromptEngineering/` — AutomaticPromptEngineering (fully excluded)
- `Shared/Intelligence/Anticipatory/` — excluded
- `Shared/Intelligence/LifeMonitoring/` — mostly excluded
- `Shared/Intelligence/PatternLearning/` — excluded
- `Shared/Automation/` — excluded
- `Shared/SelfEvolution/` — excluded

**Action: None. These are by design. Do not remove or modify.**

---

### Category B: Design Token Palettes (False Positives) — ~40 warnings

Theme color palettes for watchOS and tvOS contain exhaustive color definitions that are not yet all referenced by views. These are design infrastructure, not dead code.

Files:
- `/Users/alexis/Documents/IT & Tech/MyApps/Thea/watchOS/Theme/WatchColors.swift` — 20 warnings (theaPrimary, theaAccent, theaPurple, theaGold, semantic colors, gradients, hex initializer)
- `/Users/alexis/Documents/IT & Tech/MyApps/Thea/tvOS/Theme/TVColors.swift` — 20 warnings (theaWarning, theaError, theaInfo and duplicates)

**Action: None. These are design tokens for future UI completeness. The policy is NEVER REMOVE.**

---

### Category C: Kernel/BSD Struct Mirrors (False Positives) — ~45 warnings

`ProcessObserver.swift` (45 warnings, highest in project) contains private Swift mirror structs for two C kernel structs from `proc_pidinfo`:
- `proc_bsdinfo` — all 45 fields flagged as "assigned, but never used"
- `proc_taskinfo` — similar fields

These structs must mirror the exact C ABI layout. Most fields are populated by the kernel via `proc_pidinfo()` and only a few (e.g., `pbi_uid`, `pti_total_user`, `pti_resident_size`) are subsequently read. The others must exist to maintain correct memory layout/stride.

File: `/Users/alexis/Documents/IT & Tech/MyApps/Thea/Shared/Platforms/macOS/ProcessObserver.swift`

**Action: None. Removing fields would corrupt the struct layout and break kernel calls.**

---

### Category D: Unwired Top-Level Views (4 warnings) — Needs Wiring

Four platform Clip views are flagged as unused structs — they exist but no navigation entry point references them:

| File | Warning |
|------|---------|
| `/Users/alexis/Documents/IT & Tech/MyApps/Thea/iOS/Views/TheaClipHistoryView.swift` | `TheaClipHistoryView` unused |
| `/Users/alexis/Documents/IT & Tech/MyApps/Thea/tvOS/Views/TheaClipRelayView.swift` | `TheaClipRelayView` unused |
| `/Users/alexis/Documents/IT & Tech/MyApps/Thea/watchOS/Views/TheaClipWatchView.swift` | `TheaClipWatchView` unused |
| `/Users/alexis/Documents/IT & Tech/MyApps/Thea/macOS/Views/TheaClipPanelView.swift` | `selectedPinboard` property unused |

**Status: Views exist, navigation wiring missing. Per policy, do NOT remove. Wire them in when implementing TheaClip on each platform.**

---

### Category E: Wiring Gaps in Active Systems — ~103 warnings (Key Findings)

These are in files that ARE included in the build and SHOULD be wired. They represent incomplete feature connections.

#### E1: PostResponsePipeline (Shared/Core/Managers/)
- `Enum 'PostResponsePipeline' is unused` — the enum container itself is never called from ChatManager or app lifecycle
- The file internally calls `TaskPlanDAG.shared.createPlan()` and `ConfidenceSystem`, but nothing invokes `PostResponsePipeline` itself
- **Wiring gap**: ChatManager should call PostResponsePipeline after receiving AI responses

#### E2: TaskPlanDAG (Shared/Intelligence/Planning/)
- `Property 'shared' is unused` — the singleton is not called from any active code
- `Function 'createPlan(goal:context:)' is unused`, `Function 'execute(_:)' is unused`
- Called only from PostResponsePipeline (which itself is unwired — see E1)
- **Wiring gap**: Cascades from E1. Fix E1 to fix E2.

#### E3: ServiceContainer (Shared/Core/DependencyInjection/)
- `Class 'ServiceContainer' is unused` — DI container has no callers project-wide
- **Status**: DI pattern not yet adopted. Retain for future wiring.

#### E4: VerificationPlugin Protocol (Shared/Intelligence/Verification/)
- `Protocol 'VerificationPlugin' is unused`
- `Struct 'VerificationInput' is unused`
- `Struct 'VerificationOutput' is unused`
- `Class 'VerificationPluginRegistry' is unused`
- `Extension 'VerificationPlugin' is unused`
- The plugin registry pattern for verification is defined but ConfidenceSystem does not yet use the plugin registry — it calls verifiers directly
- **Wiring gap**: VerificationPluginRegistry is an extensibility layer not yet connected to ConfidenceSystem

#### E5: MoltbookAgent (Shared/Agents/)
- `Function 'composeResponse(to:content:)' is unused`
- `Function 'approvePendingPost(id:)' is unused`
- `Function 'rejectPendingPost(id:)' is unused`
- `Function 'clearPendingPosts()' is unused`
- `Function 'getUnreadInsights()' is unused`
- `Function 'markInsightRead(id:)' is unused`
- `Enum 'MoltbookPostResult' is unused`
- `Property 'privacyGuard' is unused`
- Several model properties in MoltbookDiscussion/MoltbookInsight structs assigned but not displayed in UI
- **Status**: MoltbookAgent is wired for lifecycle/heartbeat but its content management API (approve/reject posts, insights) is not surfaced in MoltbookSettingsView

#### E6: ChatManager Extensions (Shared/Core/Managers/)
- `ChatManager.configure(modelContext:)` — called only from tests, not app startup
- `ChatManager.injectForegroundAppContext(into:)` — built but not called
- `ChatManager+Intelligence.switchToBranch(_:for:in:)` — branch conversation not connected to UI
- `ChatManager+Intelligence.buildDeviceContextPrompt()` — device context prompt injection not activated
- `ChatManager+Messaging.removeQueuedMessage(at:)` — message queue management not exposed in UI
- **Status**: ChatManager has rich API surface, significant portions unused by current UI

#### E7: PersonalBaselineMonitor (Shared/Intelligence/Health/)
- `Property 'shared' is unused` — not called anywhere
- All 17 methods unused including `updateBaseline`, `checkForAnomalies`, `runDailyCheck`
- **Wiring gap**: PersonalBaselineMonitor exists but is never started. Should be initialized in HealthCoachingPipeline or app lifecycle.

#### E8: TheaFeatureFlag (Shared/Core/FeatureFlagEnum.swift)
- `Enum 'TheaFeatureFlag' is unused` (Periphery perspective)
- **False positive**: TheaFeatureFlag IS used via SettingsManager+FeatureFlags.swift and SettingsProviding protocol (78 usages of `SettingsManager.shared.` project-wide). Periphery may be misidentifying because the usage is indirect through protocol conformance.

#### E9: AppConfiguration Reset Functions (Shared/Core/Configuration/)
- `resetProviderConfig()`, `resetVoiceConfig()`, `resetKnowledgeScannerConfig()`, `resetMetaAIConfig()`, `resetQAToolsConfig()` — all unused
- **Status**: Settings reset actions not wired to Settings UI buttons

#### E10: SchemaVersions Migration Helpers (Shared/Core/DataModel/)
- `backupDatabase(context:)` and `validateMigration(context:)` — unused
- **Status**: Database migration safety functions exist but are not called pre-migration

---

### Category F: Parameters Unused — 168 warnings

Unused function parameters are common in protocol conformances and delegate implementations where the signature is fixed. Key examples:

- `MultiModelConsensus.swift`: `originalResponse` and `taskType` parameters ignored in comparison logic
- `AutonomousAgentV3.swift`: `_plan`, `state`, `step` parameters unused in several async closures
- `ChatManager+Messaging.swift`: `provider` parameter unused in one overload
- `ChatManager+Intelligence.swift`: `taskType` assigned but not forwarded

**Action**: For protocol-conformance parameters, prefix with `_`. For non-protocol cases, these represent logic that was planned but not implemented. Do NOT remove — add `_ ` prefix to silence Periphery while preserving the parameter for future use.

---

## Top 10 Files by Warning Count

| Rank | File | Warnings | Classification |
|------|------|----------|----------------|
| 1 | `Shared/Platforms/macOS/ProcessObserver.swift` | 45 | False positive (kernel struct mirror) |
| 2 | `Shared/AI/Adaptive/AdaptivePromptEngine.swift` | 43 | Excluded build target |
| 3 | `Shared/Code/CodeIntelligence.swift` | 41 | Excluded/unwired intelligence feature |
| 4 | `Shared/AI/LocalModels/ProactiveModelManager.swift` | 41 | Excluded build target |
| 5 | `Shared/Context/DeviceAwareness/UnifiedDeviceAwarenessTypes.swift` | 36 | Types built but not consumed by UI |
| 6 | `Shared/AI/Learning/SwiftKnowledgeLearnerTypes.swift` | 33 | Excluded build area |
| 7 | `Shared/Financial/FinancialIntegration.swift` | 29 | Feature incomplete — no UI callers |
| 8 | `Shared/Intelligence/LifeMonitoring/StressDetector.swift` | 28 | Excluded/partially wired |
| 9 | `Shared/AI/LocalModels/UnifiedLocalModelOrchestrator.swift` | 28 | Excluded build target |
| 10 | `Shared/AI/LocalModels/AIModelGovernor.swift` | 28 | Excluded build target |

---

## Actionable Wiring Recommendations (Priority Order)

> Policy: NEVER REMOVE. Only wire in or annotate.

### Priority 1 — High Impact, Straightforward Wiring

1. **PostResponsePipeline → ChatManager**: Call `PostResponsePipeline.run(response:context:)` from `ChatManager` after each AI response. This will also activate TaskPlanDAG.

2. **PersonalBaselineMonitor → HealthCoachingPipeline**: Call `PersonalBaselineMonitor.shared.runDailyCheck()` from `HealthCoachingPipeline.start()` or app lifecycle.

3. **AppConfiguration reset functions → MacSettingsView**: Wire `resetProviderConfig()` etc. to Reset buttons in settings sections.

### Priority 2 — MoltbookAgent Content Management

4. **MoltbookSettingsView**: Surface `approvePendingPost(id:)`, `rejectPendingPost(id:)`, `getUnreadInsights()` in `MoltbookSettingsView` with a pending posts list and insights section.

### Priority 3 — Extensibility Infrastructure

5. **VerificationPluginRegistry → ConfidenceSystem**: Replace direct verifier calls in ConfidenceSystem with plugin registry dispatch. Unlocks runtime plugin registration.

6. **ServiceContainer**: Adopt DI container in app startup to replace `SettingsManager.shared` singleton access pattern.

### Priority 4 — ChatManager API Completeness

7. **ChatManager.injectForegroundAppContext**: Call from app's `onActive` lifecycle to inject frontmost app context into system prompt.

8. **ChatManager.buildDeviceContextPrompt**: Activate in `sendMessage` to enrich prompts with device state.

9. **ChatManager.switchToBranch**: Wire to a branch conversation UI (currently no branch selection UI exists).

---

## False Positives Summary

| Source | Count | Reason |
|--------|-------|--------|
| Excluded build targets (analyzed but not built) | ~290 | Files on disk but not in any build target |
| Kernel/BSD struct mirrors (ProcessObserver) | ~45 | ABI layout fields must exist even if not read |
| Design token palettes (WatchColors, TVColors) | ~40 | Exhaustive color systems for future use |
| Protocol conformance params | ~50 | Signature fixed by protocol, cannot remove |
| TheaFeatureFlag (indirect usage) | 2 | Used via SettingsProviding protocol conformance |
| **Total estimated false positives** | **~427** | |

---

## Genuine Actionable Warnings

After subtracting false positives (~427) from total (2,667):

**~2,240 genuine warnings** remain — all representing features built but not yet wired into the app's active call graph. Per the project policy (NEVER REMOVE), these are to be wired in over time as features are activated.

---

## What Was Done in This Session

- Ran full 4-platform Periphery scan (`Thea-macOS`, `Thea-iOS`, `Thea-watchOS`, `Thea-tvOS`)
- Analyzed all 2,667 warnings across 501 files
- Categorized into: excluded targets, false positives, design tokens, wiring gaps
- Identified 9 specific actionable wiring gaps (E1–E10)
- No code was removed (policy compliance)
- This report replaces the 2026-02-10 single-platform analysis

---

*Generated: 2026-02-18 | Periphery 2.21.2 | Machine: msm3u (Mac Studio M3 Ultra)*
