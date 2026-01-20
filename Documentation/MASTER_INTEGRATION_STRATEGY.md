# THEA Master Integration Strategy & Claude Code Implementation Plan

**Version:** 4.0 - Comprehensive Update (GPT-5.2, AAIF, Multi-Agent)
**Created:** January 12, 2026 | **Updated:** January 13, 2026
**Purpose:** Definitive strategy for integrating ALL 175+ analyzed app features into Thea with ZERO errors

---

## ⭐ PRIMARY OBJECTIVE: CHATGPT AGENT PARITY

**OpenAI's ChatGPT Agent (July 2025)** is the industry benchmark for autonomous office automation. Thea's primary goal is to match and exceed these capabilities with macOS-native advantages.

### Target Feature Parity
| ChatGPT Agent Feature | Thea Implementation | Advantage |
|----------------------|---------------------|----------|
| GUI interaction (click, scroll, type) | macOS Accessibility APIs | Native desktop control |
| Web automation | WebKit/Safari automation | Native browser |
| Task scheduling | Cron-like scheduler | macOS-integrated |
| Permission-based safety | Action classification | Native dialogs |
| User takeover | Instant handoff | Better latency |
| Multi-step reasoning | Multi-model routing | Provider choice |

### Competitive Advantages Over ChatGPT Agent
1. **Desktop automation** - ChatGPT Agent is web-only; Thea controls native apps
2. **Multi-provider** - Not locked to OpenAI; use Claude, GPT, Gemini, local models
3. **Local models** - Privacy-first option with MLX
4. **HealthKit native** - Direct Apple Health access vs API intermediary
5. **macOS integration** - System services, Shortcuts, Spotlight

---

## TABLE OF CONTENTS

1. [Strategic Overview](#1-strategic-overview)
2. [Zero-Error Architecture Framework](#2-zero-error-architecture-framework)
3. [Complete Module Breakdown](#3-complete-module-breakdown)
4. [Implementation Sequence](#4-implementation-sequence)
5. [Quality Gates & Verification](#5-quality-gates--verification)
6. [Complete Claude Code Prompt](#6-complete-claude-code-prompt)
7. [Post-Implementation Checklist](#7-post-implementation-checklist)

---

## 1. STRATEGIC OVERVIEW

### 1.1 Mission
Integrate features from 175+ analyzed applications into Thea while maintaining:
- **ZERO compilation errors**
- **ZERO compiler warnings**
- **ZERO runtime crashes**
- **100% Swift 6 strict concurrency compliance**
- **Full test coverage for new code**

### 1.2 Feature Categories to Integrate

| Category | Apps Analyzed | Priority | Complexity |
|----------|--------------|----------|------------|
| **Office Automation (ChatGPT Agent)** | 10+ | **P0** | **Very High** |
| **Health Integration (ChatGPT Health)** | 20+ | **P0** | **High** |
| **Multi-Agent Architecture** | 8+ | **P1** | **High** |
| Wellness & Mental Health | 8 | P1 | Medium |
| Health Tracking (Sleep/HR/Activity) | 15 | P1 | High |
| ADHD & Cognitive Support | 12 | P1 | Medium |
| Psychology Assessment | 10 | P2 | Medium |
| Career Development | 12 | P2 | Low |
| Personal Finance | 18 | P1 | High |
| Passive Income Tracking | 20 | P3 | Low |
| Display Control | 4 | P3 | Low |
| Food & Nutrition | 8 | P2 | Medium |
| **Standards Compliance (AGENTS.md, MCP)** | AAIF | **P1** | Medium |
| Multi-Model Provider Strategy | 10+ | P1 | Medium |
| Natural Language Data Ops | Mammoth.io | P2 | Medium |
| Enterprise Security Patterns | Mammoth Cyber | P3 | High |
| **TOTAL** | **175+** | - | - |

### 1.3 Key Design Patterns from Analyzed Apps

**From Endel (Wellness):**
- Circadian-aware UI adaptation
- AI-generated ambient audio triggers
- Time/weather/heart rate responsive systems

**From YNAB/Copilot (Finance):**
- Zero-based budgeting methodology
- AI auto-categorization (70% faster logging)
- Subscription monitoring and alerts

**From Tiimo/Inflow (ADHD):**
- Visual timeline planning
- AI-powered task breakdown
- Countdown timers with gamification

**From AutoSleep (Health):**
- Automatic tracking (no user input required)
- Privacy-first (no data upload)
- HealthKit deep integration

**From Cronometer (Nutrition):**
- 84-nutrient tracking granularity
- USDA-sourced accuracy
- Clinical-grade data precision

---

## 2. ZERO-ERROR ARCHITECTURE FRAMEWORK

### 2.1 Swift 6 Strict Concurrency Rules

```swift
// RULE 1: All services are actors
public actor HealthService: HealthDataProvider {
    // Thread-safe by design
}

// RULE 2: All ViewModels use @MainActor
@MainActor
public final class DashboardViewModel: ObservableObject {
    // UI thread guaranteed
}

// RULE 3: All data models are Sendable
public struct SleepRecord: Identifiable, Codable, Sendable {
    // Safe to pass across actor boundaries
}

// RULE 4: All enums are Sendable
public enum SleepStage: String, Codable, Sendable, CaseIterable {
    case awake, light, deep, rem
}

// RULE 5: Use nonisolated for computed properties
extension SleepRecord {
    nonisolated var formattedDuration: String {
        // Safe read-only access
    }
}
```

### 2.2 Module Structure Standard

Every new module MUST follow this exact structure:

```
Shared/Integrations/{ModuleName}/
├── Models/
│   └── {ModuleName}Models.swift       // All Sendable data models
├── Protocols/
│   └── {ModuleName}Protocols.swift    // Protocol definitions first
├── Services/
│   └── {ModuleName}Service.swift      // Actor-based services
├── ViewModels/
│   └── {ModuleName}ViewModel.swift    // @MainActor ViewModels
├── Views/
│   └── {ModuleName}View.swift         // SwiftUI views
└── Tests/
    └── {ModuleName}Tests.swift        // Unit tests
```

### 2.3 Import Organization

```swift
// ALWAYS in this order:
import Foundation
import SwiftUI          // Only in Views/ViewModels
import SwiftData        // Only if using persistence
import HealthKit        // Only in Health module
import Charts           // Only if using charts
@testable import TheaCore  // Only in tests
```

### 2.4 Error Handling Pattern

```swift
// Define module-specific errors as Sendable
public enum HealthError: Error, Sendable, LocalizedError {
    case notAuthorized
    case notAvailable
    case queryFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Health data access not authorized"
        case .notAvailable: return "HealthKit not available on this device"
        case .queryFailed(let reason): return "Query failed: \(reason)"
        }
    }
}
```

---

## 3. COMPLETE MODULE BREAKDOWN

### 3.1 HEALTH MODULE (Priority 1)

**Features from analyzed apps:**
- AutoSleep: Automatic sleep detection, no button press
- Sleep Cycle: Smart alarm, sleep stage analysis
- SmartBP: ECG integration, ORCHA-approved accuracy
- MedM: 800+ device integrations

**Files to create:**

```
Shared/Integrations/Health/
├── Models/
│   └── HealthModels.swift
├── Protocols/
│   └── HealthProtocols.swift
├── Services/
│   ├── HealthKitService.swift
│   ├── SleepTrackingService.swift
│   └── CardiovascularService.swift
├── ViewModels/
│   └── HealthDashboardViewModel.swift
├── Views/
│   ├── HealthDashboardView.swift
│   ├── SleepAnalysisView.swift
│   └── HeartRateView.swift
└── Tests/
    └── HealthServiceTests.swift
```

**Lines of code estimate:** ~2,000

### 3.2 WELLNESS MODULE (Priority 1)

**Features from analyzed apps:**
- Endel: Circadian-aware audio, adaptive UI
- Headspace: Guided meditation, SOS sessions
- Focus modes with ambient audio triggers

**Files to create:**

```
Shared/Integrations/Wellness/
├── Models/
│   └── WellnessModels.swift
├── Protocols/
│   └── WellnessProtocols.swift
├── Services/
│   ├── CircadianService.swift
│   ├── FocusModeService.swift
│   └── AmbientAudioService.swift
├── ViewModels/
│   └── WellnessViewModel.swift
├── Views/
│   ├── WellnessDashboardView.swift
│   ├── FocusSessionView.swift
│   └── CircadianAdaptiveUI.swift
└── Tests/
    └── WellnessServiceTests.swift
```

**Lines of code estimate:** ~1,500

### 3.3 ADHD & COGNITIVE MODULE (Priority 1)

**Features from analyzed apps:**
- Tiimo: Visual timeline, AI task breakdown (iPhone App of Year 2025)
- Inflow: 73.1% symptom reduction (peer-reviewed)
- Forest: Gamified focus timer
- Goblin Tools: Free task breakdown

**Files to create:**

```
Shared/Integrations/Cognitive/
├── Models/
│   └── CognitiveModels.swift
├── Protocols/
│   └── CognitiveProtocols.swift
├── Services/
│   ├── TaskBreakdownService.swift
│   ├── VisualTimerService.swift
│   └── FocusGamificationService.swift
├── ViewModels/
│   └── ADHDDashboardViewModel.swift
├── Views/
│   ├── VisualTimelineView.swift
│   ├── TaskBreakdownView.swift
│   ├── PomodoroTimerView.swift
│   └── FocusForestView.swift
└── Tests/
    └── CognitiveServiceTests.swift
```

**Lines of code estimate:** ~1,800

### 3.4 FINANCIAL MODULE (Priority 1)

**Features from analyzed apps:**
- YNAB: Zero-based budgeting, "give every dollar a job"
- Copilot: AI auto-categorization (70% faster), Apple exclusive
- Monarch: Year/month forecasting, family sharing
- Robinhood: Fractional shares, crypto tracking
- Acorns: Round-ups micro-investing

**Files to create:**

```
Shared/Integrations/Financial/
├── Models/
│   └── FinancialModels.swift
├── Protocols/
│   └── FinancialProtocols.swift
├── Services/
│   ├── BudgetService.swift
│   ├── TransactionCategorizerService.swift
│   ├── SubscriptionMonitorService.swift
│   └── InvestmentTrackerService.swift
├── ViewModels/
│   └── FinancialDashboardViewModel.swift
├── Views/
│   ├── BudgetView.swift
│   ├── TransactionListView.swift
│   ├── SubscriptionManagerView.swift
│   └── InvestmentOverviewView.swift
└── Tests/
    └── FinancialServiceTests.swift
```

**Lines of code estimate:** ~2,500

### 3.5 CAREER MODULE (Priority 2)

**Features from analyzed apps:**
- Rocky.ai: Daily reflections, soft skills practice
- Coach: 65,000+ users, expert-backed activities
- Simply.Coach: SMART goals framework
- Life Note: AI journaling with 1,000+ historical mentors

**Files to create:**

```
Shared/Integrations/Career/
├── Models/
│   └── CareerModels.swift
├── Protocols/
│   └── CareerProtocols.swift
├── Services/
│   ├── GoalTrackingService.swift
│   ├── SkillDevelopmentService.swift
│   └── ReflectionJournalService.swift
├── ViewModels/
│   └── CareerDashboardViewModel.swift
├── Views/
│   ├── GoalTrackerView.swift
│   ├── SkillProgressView.swift
│   └── DailyReflectionView.swift
└── Tests/
    └── CareerServiceTests.swift
```

**Lines of code estimate:** ~1,200

### 3.6 ASSESSMENT MODULE (Priority 2)

**Features from analyzed apps:**
- Psychology Today: EQ assessments, HSP detection
- TEIQue: 153-item comprehensive EQ
- Dr. Elaine Aron HSP Scale: 27-item questionnaire
- Lumosity: Age-based cognitive benchmarking
- CogniFit: Daily training with progress tracking

**Files to create:**

```
Shared/Integrations/Assessment/
├── Models/
│   └── AssessmentModels.swift
├── Protocols/
│   └── AssessmentProtocols.swift
├── Services/
│   ├── AssessmentEngineService.swift
│   ├── CognitiveLoadMonitor.swift
│   └── PersonalityInsightsService.swift
├── ViewModels/
│   └── AssessmentViewModel.swift
├── Views/
│   ├── AssessmentListView.swift
│   ├── QuestionnaireView.swift
│   └── ResultsAnalysisView.swift
└── Tests/
    └── AssessmentServiceTests.swift
```

**Lines of code estimate:** ~1,500

### 3.7 NUTRITION MODULE (Priority 2)

**Features from analyzed apps:**
- Cronometer: 84 nutrients, USDA-sourced, clinical accuracy
- MyFitnessPal: 14M+ verified foods, barcode scanner
- Fitia: Photo/voice/text logging (70% faster)
- Hoot: Nutrition Score 1-100, 40% longer retention

**Files to create:**

```
Shared/Integrations/Nutrition/
├── Models/
│   └── NutritionModels.swift
├── Protocols/
│   └── NutritionProtocols.swift
├── Services/
│   ├── NutritionTrackingService.swift
│   ├── FoodDatabaseService.swift
│   └── MealPlanningService.swift
├── ViewModels/
│   └── NutritionDashboardViewModel.swift
├── Views/
│   ├── FoodLogView.swift
│   ├── NutrientBreakdownView.swift
│   └── MealPlannerView.swift
└── Tests/
    └── NutritionServiceTests.swift
```

**Lines of code estimate:** ~1,400

### 3.8 DISPLAY MODULE (Priority 3 - macOS only)

**Features from analyzed apps:**
- DisplayBuddy: DDC/CI hardware control, presets
- BetterDisplay: Full DDC on M1/M2 HDMI, HiDPI scaling
- XDR/HDR extra brightness support

**Files to create:**

```
Shared/Integrations/Display/
├── Models/
│   └── DisplayModels.swift
├── Protocols/
│   └── DisplayProtocols.swift
├── Services/
│   └── DisplayControlService.swift
├── ViewModels/
│   └── DisplaySettingsViewModel.swift
├── Views/
│   └── DisplayControlView.swift
└── Tests/
    └── DisplayServiceTests.swift
```

**Lines of code estimate:** ~600

### 3.9 INCOME MODULE (Priority 3)

**Features from analyzed apps:**
- Passive income tracking from multiple sources
- Side hustle management
- Gig economy earnings aggregation

**Files to create:**

```
Shared/Integrations/Income/
├── Models/
│   └── IncomeModels.swift
├── Protocols/
│   └── IncomeProtocols.swift
├── Services/
│   ├── IncomeTrackerService.swift
│   └── SideHustleService.swift
├── ViewModels/
│   └── IncomeDashboardViewModel.swift
├── Views/
│   ├── IncomeOverviewView.swift
│   └── SideHustleListView.swift
└── Tests/
    └── IncomeServiceTests.swift
```

**Lines of code estimate:** ~800

---

## 4. IMPLEMENTATION SEQUENCE

### 4.1 Phase 1: Foundation (Days 1-2)

**Objective:** Create all protocols and base models for all modules

**Files to create in order:**
1. `Shared/Integrations/IntegrationTypes.swift` - Shared types
2. All `*Protocols.swift` files across all modules
3. All `*Models.swift` files across all modules

**Verification command:**
```bash
xcodebuild -scheme Thea -destination 'platform=macOS' build 2>&1 | grep -E "error:|warning:"
# Expected: No output (zero errors, zero warnings)
```

### 4.2 Phase 2: Health Services (Days 3-4)

**Objective:** Implement HealthKit integration

**Files in order:**
1. `Health/Services/HealthKitService.swift`
2. `Health/Services/SleepTrackingService.swift`
3. `Health/Services/CardiovascularService.swift`
4. `Health/ViewModels/HealthDashboardViewModel.swift`
5. `Health/Views/HealthDashboardView.swift`
6. `Health/Tests/HealthServiceTests.swift`

### 4.3 Phase 3: Wellness & Focus (Days 5-6)

**Objective:** Implement circadian UI and focus modes

**Files in order:**
1. `Wellness/Services/CircadianService.swift`
2. `Wellness/Services/FocusModeService.swift`
3. `Wellness/Services/AmbientAudioService.swift`
4. `Wellness/ViewModels/WellnessViewModel.swift`
5. `Wellness/Views/*`
6. `Wellness/Tests/WellnessServiceTests.swift`

### 4.4 Phase 4: Cognitive/ADHD (Days 7-8)

**Objective:** Visual timers, task breakdown, gamification

**Files in order:**
1. `Cognitive/Services/TaskBreakdownService.swift`
2. `Cognitive/Services/VisualTimerService.swift`
3. `Cognitive/Services/FocusGamificationService.swift`
4. `Cognitive/ViewModels/ADHDDashboardViewModel.swift`
5. `Cognitive/Views/*`
6. `Cognitive/Tests/CognitiveServiceTests.swift`

### 4.5 Phase 5: Financial (Days 9-11)

**Objective:** Budget tracking, categorization, subscriptions

**Files in order:**
1. `Financial/Services/BudgetService.swift`
2. `Financial/Services/TransactionCategorizerService.swift`
3. `Financial/Services/SubscriptionMonitorService.swift`
4. `Financial/Services/InvestmentTrackerService.swift`
5. `Financial/ViewModels/FinancialDashboardViewModel.swift`
6. `Financial/Views/*`
7. `Financial/Tests/FinancialServiceTests.swift`

### 4.6 Phase 6: Career & Assessment (Days 12-13)

**Objective:** Goals, skills, assessments

**Files in order:**
1. `Career/Services/*`
2. `Career/ViewModels/*`
3. `Career/Views/*`
4. `Assessment/Services/*`
5. `Assessment/ViewModels/*`
6. `Assessment/Views/*`

### 4.7 Phase 7: Nutrition & Remaining (Days 14-15)

**Objective:** Nutrition, display control, income tracking

**Files in order:**
1. `Nutrition/Services/*`
2. `Nutrition/ViewModels/*`
3. `Nutrition/Views/*`
4. `Display/Services/*` (macOS only)
5. `Display/Views/*`
6. `Income/Services/*`
7. `Income/Views/*`

### 4.8 Phase 8: Integration & Dashboard (Days 16-18)

**Objective:** Unified dashboard, cross-module communication

**Files to create:**
1. `Shared/UI/Views/UnifiedDashboardView.swift`
2. `Shared/Core/Managers/IntegrationsManager.swift`
3. `Shared/Core/FeatureFlags.swift`
4. Integration tests across all modules

---

## 5. QUALITY GATES & VERIFICATION

### 5.1 After Every File Creation

```bash
# MANDATORY: Run after creating each file
xcodebuild -scheme Thea -destination 'platform=macOS' build 2>&1 | grep -E "error:|warning:" | head -20

# If ANY output: STOP and fix before proceeding
# If no output: Continue to next file
```

### 5.2 After Each Module Completion

```bash
# Run full test suite
xcodebuild test -scheme Thea -destination 'platform=macOS' -only-testing:TheaCoreTests 2>&1

# Check for memory issues
xcodebuild test -scheme Thea -destination 'platform=macOS' -enableAddressSanitizer YES

# Check for thread issues  
xcodebuild test -scheme Thea -destination 'platform=macOS' -enableThreadSanitizer YES
```

### 5.3 Final Verification Checklist

| Check | Command | Expected |
|-------|---------|----------|
| Zero errors | `xcodebuild build \| grep error:` | No output |
| Zero warnings | `xcodebuild build \| grep warning:` | No output |
| Tests pass | `xcodebuild test` | All green |
| No data races | Thread Sanitizer | No issues |
| No memory leaks | Address Sanitizer | No issues |
| Swift 6 compliant | Build with strict | Success |

---

## 6. COMPLETE CLAUDE CODE PROMPT

Copy the following prompt exactly into Claude Code:

---


```
# CLAUDE CODE IMPLEMENTATION PROMPT FOR THEA
# Version: 2.0 Complete
# Copy this ENTIRE prompt into Claude Code

---

## CONTEXT

You are implementing comprehensive feature integrations for Thea, a macOS AI assistant app. The codebase is located at:
- **Project root:** /Users/alexis/Documents/IT & Tech/MyApps/Thea
- **Development code:** /Users/alexis/Documents/IT & Tech/MyApps/Thea/Development
- **Shared code:** /Users/alexis/Documents/IT & Tech/MyApps/Thea/Development/Shared
- **Documentation:** /Users/alexis/Documents/IT & Tech/MyApps/Thea/Documentation

**Thea targets:**
- macOS 26 (Tahoe) exclusively for this phase
- Swift 6.0 with strict concurrency
- SwiftUI for all UI
- SwiftData for persistence
- HealthKit for health data

---

## YOUR MISSION

Implement 9 new integration modules based on 155+ analyzed apps. You MUST achieve:
- ✅ ZERO compilation errors
- ✅ ZERO compiler warnings
- ✅ ZERO runtime crashes
- ✅ 100% Swift 6 strict concurrency compliance
- ✅ Full test coverage for new code

---

## CRITICAL RULES (NEVER VIOLATE)

### Rule 1: Build After Every File
After creating or modifying ANY file, run:
```bash
cd /Users/alexis/Documents/IT\ \&\ Tech/MyApps/Thea/Development
xcodebuild -scheme Thea -destination 'platform=macOS' build 2>&1 | grep -E "error:|warning:" | head -20
```
If ANY errors or warnings appear: STOP and FIX immediately before creating the next file.

### Rule 2: Swift 6 Concurrency Patterns
- ALL services MUST be `actor` types
- ALL ViewModels MUST use `@MainActor`
- ALL data models MUST conform to `Sendable`
- ALL enums MUST conform to `Sendable`
- Use `nonisolated` for computed properties that don't access mutable state
- NEVER use `@unchecked Sendable` unless absolutely necessary

### Rule 3: Module Structure (EXACT)
Every module follows this structure:
```
Shared/Integrations/{ModuleName}/
├── Models/{ModuleName}Models.swift
├── Protocols/{ModuleName}Protocols.swift  
├── Services/{ModuleName}Service.swift
├── ViewModels/{ModuleName}ViewModel.swift
├── Views/{ModuleName}View.swift
└── Tests/{ModuleName}Tests.swift
```

### Rule 4: File Header Template
Every Swift file MUST start with:
```swift
//
//  FileName.swift
//  Thea
//
//  Created by Claude Code on {DATE}
//  Copyright © 2026. All rights reserved.
//

import Foundation
// other imports as needed
```

### Rule 5: Error Handling
Every service MUST have a corresponding error enum:
```swift
public enum {ModuleName}Error: Error, Sendable, LocalizedError {
    case specificCase
    
    public var errorDescription: String? {
        switch self {
        case .specificCase: return "Description"
        }
    }
}
```

---

## IMPLEMENTATION ORDER (FOLLOW EXACTLY)

### STEP 1: Create Integration Types (DO FIRST)

Create file: `Shared/Integrations/IntegrationTypes.swift`

```swift
//
//  IntegrationTypes.swift
//  Thea
//
//  Shared types for all integration modules
//

import Foundation

// MARK: - Common Protocols

public protocol DataProvider: Actor {
    associatedtype DataType: Sendable
    func fetch() async throws -> DataType
}

public protocol Trackable: Identifiable, Codable, Sendable {
    var id: UUID { get }
    var createdAt: Date { get }
    var updatedAt: Date { get }
}

// MARK: - Common Enums

public enum DataSource: String, Codable, Sendable, CaseIterable {
    case automatic
    case manual
    case healthKit
    case thirdParty
    case imported
}

public enum Priority: Int, Codable, Sendable, CaseIterable, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case urgent = 3
    
    public static func < (lhs: Priority, rhs: Priority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum Trend: String, Codable, Sendable {
    case improving
    case stable  
    case declining
    case unknown
}

// MARK: - Date Helpers

public extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    var endOfDay: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
    }
    
    func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: self) ?? self
    }
}
```

**VERIFY:** Build and confirm zero errors/warnings.

---

### STEP 2: Health Module Protocols

Create file: `Shared/Integrations/Health/Protocols/HealthProtocols.swift`

```swift
//
//  HealthProtocols.swift
//  Thea
//

import Foundation

// MARK: - Health Data Provider

public protocol HealthDataProvider: Actor {
    func requestAuthorization() async throws
    func fetchSleepData(for dateRange: DateInterval) async throws -> [SleepRecord]
    func fetchHeartRateData(for dateRange: DateInterval) async throws -> [HeartRateRecord]
    func fetchActivityData(for date: Date) async throws -> ActivitySummary
}

// MARK: - Sleep Analyzer

public protocol SleepAnalyzer: Sendable {
    func analyzeSleepQuality(records: [SleepRecord]) -> SleepQualityAnalysis
    func detectSleepPatterns(records: [SleepRecord]) -> [SleepPattern]
    func generateSleepRecommendations(analysis: SleepQualityAnalysis) -> [String]
}

// MARK: - Cardiovascular Monitor

public protocol CardiovascularMonitor: Actor {
    func getCurrentHeartRate() async throws -> Int
    func getRestingHeartRate(days: Int) async throws -> Int
    func getHeartRateVariability(days: Int) async throws -> Double
    func detectAnomalies(records: [HeartRateRecord]) -> [CardiacAnomaly]
}
```

**VERIFY:** Build and confirm zero errors/warnings.

---

### STEP 3: Health Module Models

Create file: `Shared/Integrations/Health/Models/HealthModels.swift`

```swift
//
//  HealthModels.swift
//  Thea
//

import Foundation

// MARK: - Sleep Models

public struct SleepRecord: Identifiable, Codable, Sendable {
    public let id: UUID
    public let source: DataSource
    public let startTime: Date
    public let endTime: Date
    public let stages: [SleepStage]
    public let quality: SleepQuality
    
    public init(id: UUID = UUID(), source: DataSource, startTime: Date, endTime: Date, stages: [SleepStage], quality: SleepQuality) {
        self.id = id
        self.source = source
        self.startTime = startTime
        self.endTime = endTime
        self.stages = stages
        self.quality = quality
    }
    
    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    public var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

public enum SleepStage: String, Codable, Sendable, CaseIterable {
    case awake, light, deep, rem
    
    public var displayName: String {
        switch self {
        case .awake: return "Awake"
        case .light: return "Light Sleep"
        case .deep: return "Deep Sleep"
        case .rem: return "REM"
        }
    }
    
    public var color: String {
        switch self {
        case .awake: return "#EF4444"
        case .light: return "#60A5FA"
        case .deep: return "#3B82F6"
        case .rem: return "#8B5CF6"
        }
    }
}

public enum SleepQuality: String, Codable, Sendable, CaseIterable {
    case poor, fair, good, excellent
    
    public var displayName: String { rawValue.capitalized }
    
    public var score: Int {
        switch self {
        case .poor: return 1
        case .fair: return 2
        case .good: return 3
        case .excellent: return 4
        }
    }
}

public struct SleepQualityAnalysis: Sendable {
    public let averageQuality: SleepQuality
    public let averageDuration: TimeInterval
    public let deepSleepPercentage: Double
    public let remSleepPercentage: Double
    public let consistency: Double
    public let trend: Trend
    
    public init(averageQuality: SleepQuality, averageDuration: TimeInterval, deepSleepPercentage: Double, remSleepPercentage: Double, consistency: Double, trend: Trend) {
        self.averageQuality = averageQuality
        self.averageDuration = averageDuration
        self.deepSleepPercentage = deepSleepPercentage
        self.remSleepPercentage = remSleepPercentage
        self.consistency = consistency
        self.trend = trend
    }
}

public struct SleepPattern: Identifiable, Sendable {
    public let id: UUID
    public let type: PatternType
    public let description: String
    public let frequency: Int
    
    public enum PatternType: String, Sendable {
        case consistent, irregular, improving, declining
    }
    
    public init(id: UUID = UUID(), type: PatternType, description: String, frequency: Int) {
        self.id = id
        self.type = type
        self.description = description
        self.frequency = frequency
    }
}

// MARK: - Heart Rate Models

public struct HeartRateRecord: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let bpm: Int
    public let source: DataSource
    public let context: HeartRateContext
    
    public init(id: UUID = UUID(), timestamp: Date, bpm: Int, source: DataSource, context: HeartRateContext) {
        self.id = id
        self.timestamp = timestamp
        self.bpm = bpm
        self.source = source
        self.context = context
    }
}

public enum HeartRateContext: String, Codable, Sendable {
    case resting, active, workout, sleep, recovery
}

public struct CardiacAnomaly: Identifiable, Sendable {
    public let id: UUID
    public let type: AnomalyType
    public let timestamp: Date
    public let severity: Severity
    public let description: String
    
    public enum AnomalyType: String, Sendable {
        case tachycardia, bradycardia, irregularRhythm, unusualVariability
    }
    
    public enum Severity: String, Sendable {
        case low, medium, high
    }
    
    public init(id: UUID = UUID(), type: AnomalyType, timestamp: Date, severity: Severity, description: String) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.severity = severity
        self.description = description
    }
}

// MARK: - Activity Models

public struct ActivitySummary: Codable, Sendable {
    public let date: Date
    public let steps: Int
    public let calories: Int
    public let distance: Double
    public let activeMinutes: Int
    public let standHours: Int
    
    public init(date: Date, steps: Int, calories: Int, distance: Double, activeMinutes: Int = 0, standHours: Int = 0) {
        self.date = date
        self.steps = steps
        self.calories = calories
        self.distance = distance
        self.activeMinutes = activeMinutes
        self.standHours = standHours
    }
}

// MARK: - Health Errors

public enum HealthError: Error, Sendable, LocalizedError {
    case notAvailable
    case notAuthorized
    case queryFailed(String)
    case invalidDateRange
    case noData
    
    public var errorDescription: String? {
        switch self {
        case .notAvailable: return "HealthKit is not available on this device"
        case .notAuthorized: return "Health data access not authorized"
        case .queryFailed(let reason): return "Health query failed: \(reason)"
        case .invalidDateRange: return "Invalid date range specified"
        case .noData: return "No health data available for the specified period"
        }
    }
}
```

**VERIFY:** Build and confirm zero errors/warnings.

---

### STEP 4: Health Service Implementation

Create file: `Shared/Integrations/Health/Services/HealthKitService.swift`

```swift
//
//  HealthKitService.swift
//  Thea
//

import Foundation
import HealthKit

public actor HealthKitService: HealthDataProvider {
    private let healthStore: HKHealthStore
    private var isAuthorized: Bool = false
    
    public init() {
        self.healthStore = HKHealthStore()
    }
    
    public func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthError.notAvailable
        }
        
        let readTypes: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
        isAuthorized = true
    }
    
    public func fetchSleepData(for dateRange: DateInterval) async throws -> [SleepRecord] {
        guard isAuthorized else { throw HealthError.notAuthorized }
        
        return try await withCheckedThrowingContinuation { continuation in
            let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
            let predicate = HKQuery.predicateForSamples(withStart: dateRange.start, end: dateRange.end)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthError.queryFailed(error.localizedDescription))
                    return
                }
                
                let records = (samples as? [HKCategorySample] ?? []).compactMap { sample -> SleepRecord? in
                    let stage = self.mapSleepStage(from: sample.value)
                    let quality = self.estimateSleepQuality(duration: sample.endDate.timeIntervalSince(sample.startDate))
                    
                    return SleepRecord(
                        source: .healthKit,
                        startTime: sample.startDate,
                        endTime: sample.endDate,
                        stages: [stage],
                        quality: quality
                    )
                }
                continuation.resume(returning: records)
            }
            
            healthStore.execute(query)
        }
    }
    
    public func fetchHeartRateData(for dateRange: DateInterval) async throws -> [HeartRateRecord] {
        guard isAuthorized else { throw HealthError.notAuthorized }
        
        return try await withCheckedThrowingContinuation { continuation in
            let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
            let predicate = HKQuery.predicateForSamples(withStart: dateRange.start, end: dateRange.end)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthError.queryFailed(error.localizedDescription))
                    return
                }
                
                let records = (samples as? [HKQuantitySample] ?? []).map { sample in
                    HeartRateRecord(
                        timestamp: sample.startDate,
                        bpm: Int(sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))),
                        source: .healthKit,
                        context: .resting
                    )
                }
                continuation.resume(returning: records)
            }
            
            healthStore.execute(query)
        }
    }
    
    public func fetchActivityData(for date: Date) async throws -> ActivitySummary {
        guard isAuthorized else { throw HealthError.notAuthorized }
        
        let startOfDay = date.startOfDay
        let endOfDay = date.endOfDay
        let dateRange = DateInterval(start: startOfDay, end: endOfDay)
        
        async let steps = fetchSteps(for: dateRange)
        async let calories = fetchCalories(for: dateRange)
        async let distance = fetchDistance(for: dateRange)
        
        return ActivitySummary(
            date: date,
            steps: try await steps,
            calories: try await calories,
            distance: try await distance
        )
    }
    
    // MARK: - Private Helpers
    
    private func fetchSteps(for dateRange: DateInterval) async throws -> Int {
        try await fetchQuantitySum(
            typeIdentifier: .stepCount,
            unit: .count(),
            dateRange: dateRange
        )
    }
    
    private func fetchCalories(for dateRange: DateInterval) async throws -> Int {
        try await fetchQuantitySum(
            typeIdentifier: .activeEnergyBurned,
            unit: .kilocalorie(),
            dateRange: dateRange
        )
    }
    
    private func fetchDistance(for dateRange: DateInterval) async throws -> Double {
        Double(try await fetchQuantitySum(
            typeIdentifier: .distanceWalkingRunning,
            unit: .meterUnit(with: .kilo),
            dateRange: dateRange
        ))
    }
    
    private func fetchQuantitySum(
        typeIdentifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        dateRange: DateInterval
    ) async throws -> Int {
        return try await withCheckedThrowingContinuation { continuation in
            let quantityType = HKObjectType.quantityType(forIdentifier: typeIdentifier)!
            let predicate = HKQuery.predicateForSamples(withStart: dateRange.start, end: dateRange.end)
            
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: HealthError.queryFailed(error.localizedDescription))
                    return
                }
                
                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: Int(value))
            }
            
            healthStore.execute(query)
        }
    }
    
    private nonisolated func mapSleepStage(from value: Int) -> SleepStage {
        switch value {
        case 0: return .awake
        case 1: return .light
        case 2: return .deep
        case 3: return .rem
        default: return .light
        }
    }
    
    private nonisolated func estimateSleepQuality(duration: TimeInterval) -> SleepQuality {
        let hours = duration / 3600
        switch hours {
        case ..<5: return .poor
        case 5..<6.5: return .fair
        case 6.5..<8: return .good
        default: return .excellent
        }
    }
}
```

**VERIFY:** Build and confirm zero errors/warnings.

---

### STEP 5: Health ViewModel

Create file: `Shared/Integrations/Health/ViewModels/HealthDashboardViewModel.swift`

```swift
//
//  HealthDashboardViewModel.swift
//  Thea
//

import Foundation
import SwiftUI

@MainActor
public final class HealthDashboardViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published public var sleepRecords: [SleepRecord] = []
    @Published public var heartRateRecords: [HeartRateRecord] = []
    @Published public var activitySummary: ActivitySummary?
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var selectedTimeRange: TimeRange = .week
    
    // MARK: - Private Properties
    
    private let healthService: HealthKitService
    
    // MARK: - Time Range
    
    public enum TimeRange: String, CaseIterable, Sendable {
        case day = "Today"
        case week = "Week"
        case month = "Month"
        
        public var days: Int {
            switch self {
            case .day: return 1
            case .week: return 7
            case .month: return 30
            }
        }
    }
    
    // MARK: - Initialization
    
    public init(healthService: HealthKitService = HealthKitService()) {
        self.healthService = healthService
    }
    
    // MARK: - Public Methods
    
    public func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let endDate = Date()
        guard let startDate = Calendar.current.date(byAdding: .day, value: -selectedTimeRange.days, to: endDate) else {
            errorMessage = "Failed to calculate date range"
            return
        }
        let dateRange = DateInterval(start: startDate, end: endDate)
        
        do {
            try await healthService.requestAuthorization()
            
            async let sleep = healthService.fetchSleepData(for: dateRange)
            async let heartRate = healthService.fetchHeartRateData(for: dateRange)
            async let activity = healthService.fetchActivityData(for: Date())
            
            sleepRecords = try await sleep
            heartRateRecords = try await heartRate
            activitySummary = try await activity
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    public func refreshData() async {
        await loadData()
    }
    
    // MARK: - Computed Properties
    
    public var averageSleepDuration: String {
        guard !sleepRecords.isEmpty else { return "No data" }
        let totalDuration = sleepRecords.reduce(0) { $0 + $1.duration }
        let average = totalDuration / Double(sleepRecords.count)
        let hours = Int(average) / 3600
        let minutes = (Int(average) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
    
    public var averageHeartRate: String {
        guard !heartRateRecords.isEmpty else { return "No data" }
        let total = heartRateRecords.reduce(0) { $0 + $1.bpm }
        let average = total / heartRateRecords.count
        return "\(average) BPM"
    }
    
    public var stepsToday: String {
        guard let summary = activitySummary else { return "No data" }
        return "\(summary.steps.formatted()) steps"
    }
}
```

**VERIFY:** Build and confirm zero errors/warnings.

---

### STEP 6: Health Dashboard View

Create file: `Shared/Integrations/Health/Views/HealthDashboardView.swift`

```swift
//
//  HealthDashboardView.swift
//  Thea
//

import SwiftUI

public struct HealthDashboardView: View {
    @StateObject private var viewModel: HealthDashboardViewModel
    
    public init(healthService: HealthKitService = HealthKitService()) {
        _viewModel = StateObject(wrappedValue: HealthDashboardViewModel(healthService: healthService))
    }
    
    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading health data...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") {
                            Task { await viewModel.loadData() }
                        }
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            timeRangePicker
                            summaryCards
                            sleepSection
                            activitySection
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Health")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.refreshData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await viewModel.loadData()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var timeRangePicker: some View {
        Picker("Time Range", selection: $viewModel.selectedTimeRange) {
            ForEach(HealthDashboardViewModel.TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.selectedTimeRange) { _, _ in
            Task { await viewModel.loadData() }
        }
    }
    
    private var summaryCards: some View {
        HStack(spacing: 12) {
            SummaryCard(
                title: "Avg Sleep",
                value: viewModel.averageSleepDuration,
                icon: "bed.double.fill",
                color: .blue
            )
            
            SummaryCard(
                title: "Avg Heart Rate",
                value: viewModel.averageHeartRate,
                icon: "heart.fill",
                color: .red
            )
            
            SummaryCard(
                title: "Steps Today",
                value: viewModel.stepsToday,
                icon: "figure.walk",
                color: .green
            )
        }
    }
    
    private var sleepSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep History")
                .font(.headline)
            
            if viewModel.sleepRecords.isEmpty {
                Text("No sleep data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.sleepRecords.prefix(7)) { record in
                    SleepRecordRow(record: record)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Activity")
                .font(.headline)
            
            if let summary = viewModel.activitySummary {
                ActivitySummaryView(summary: summary)
            } else {
                Text("No activity data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Supporting Views

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.headline)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct SleepRecordRow: View {
    let record: SleepRecord
    
    var body: some View {
        HStack {
            Image(systemName: "bed.double.fill")
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading) {
                Text(record.startTime, style: .date)
                    .font(.subheadline)
                Text(record.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(record.quality.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(qualityColor.opacity(0.2))
                .foregroundStyle(qualityColor)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
    
    private var qualityColor: Color {
        switch record.quality {
        case .poor: return .red
        case .fair: return .orange
        case .good: return .yellow
        case .excellent: return .green
        }
    }
}

struct ActivitySummaryView: View {
    let summary: ActivitySummary
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                ActivityMetric(title: "Steps", value: "\(summary.steps.formatted())", icon: "figure.walk")
                ActivityMetric(title: "Calories", value: "\(summary.calories) kcal", icon: "flame.fill")
                ActivityMetric(title: "Distance", value: String(format: "%.1f km", summary.distance), icon: "map")
            }
        }
    }
}

struct ActivityMetric: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.green)
            Text(value)
                .font(.subheadline.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    HealthDashboardView()
}
```

**VERIFY:** Build and confirm zero errors/warnings.

---

## CONTINUE WITH REMAINING MODULES

After successfully creating the Health module with zero errors, continue with:

1. **Wellness Module** - CircadianService, FocusModeService, AmbientAudioService
2. **Cognitive Module** - TaskBreakdownService, VisualTimerService, FocusGamificationService  
3. **Financial Module** - BudgetService, TransactionCategorizerService, SubscriptionMonitorService
4. **Career Module** - GoalTrackingService, SkillDevelopmentService, ReflectionJournalService
5. **Assessment Module** - AssessmentEngineService, CognitiveLoadMonitor, PersonalityInsightsService
6. **Nutrition Module** - NutritionTrackingService, FoodDatabaseService
7. **Display Module** - DisplayControlService (macOS only)
8. **Income Module** - IncomeTrackerService, SideHustleService

For each module, follow the EXACT same pattern:
1. Create Protocols first
2. Create Models second  
3. Create Service (actor) third
4. Create ViewModel (@MainActor) fourth
5. Create Views fifth
6. Create Tests sixth
7. VERIFY build after each file

---

## FINAL INTEGRATION

After all modules are complete, create:

1. **UnifiedDashboardView** - Aggregates all module dashboards
2. **IntegrationsManager** - Coordinates cross-module communication
3. **FeatureFlags** - Enable/disable modules safely

---

## VERIFICATION CHECKLIST

Before marking complete:

```bash
# Zero errors
xcodebuild -scheme Thea -destination 'platform=macOS' build 2>&1 | grep "error:" | wc -l
# Expected: 0

# Zero warnings  
xcodebuild -scheme Thea -destination 'platform=macOS' build 2>&1 | grep "warning:" | wc -l
# Expected: 0

# Tests pass
xcodebuild test -scheme Thea -destination 'platform=macOS'
# Expected: All tests pass
```

---

## SUCCESS CRITERIA

- [ ] All 9 modules implemented
- [ ] 150+ unit tests passing
- [ ] Zero build errors
- [ ] Zero build warnings
- [ ] All async code properly isolated with actors/@MainActor
- [ ] All models conform to Sendable
- [ ] All views render correctly in Preview
- [ ] Performance targets met (<500ms API, <16ms UI)
```

---

## 7. POST-IMPLEMENTATION CHECKLIST

### 7.1 Code Quality

- [ ] All files have proper headers
- [ ] All public APIs documented with comments
- [ ] No force unwraps (!) in production code
- [ ] All errors properly handled
- [ ] No deprecated APIs used

### 7.2 Testing

- [ ] Unit tests for all services
- [ ] Unit tests for all ViewModels
- [ ] Integration tests for module interactions
- [ ] UI tests for critical flows
- [ ] Performance tests for data-heavy operations

### 7.3 Documentation

- [ ] README updated with new features
- [ ] API documentation complete
- [ ] User guide updated
- [ ] Changelog updated

### 7.4 Deployment

- [ ] Version bumped appropriately
- [ ] Privacy policy updated if needed
- [ ] App Store screenshots updated
- [ ] Release notes prepared

---

## APPENDIX A: File Count Summary

| Module | Files | LOC |
|--------|-------|-----|
| Integration Types | 1 | 80 |
| Health | 6 | 2,000 |
| Wellness | 6 | 1,500 |
| Cognitive | 6 | 1,800 |
| Financial | 7 | 2,500 |
| Career | 6 | 1,200 |
| Assessment | 6 | 1,500 |
| Nutrition | 6 | 1,400 |
| Display | 5 | 600 |
| Income | 6 | 800 |
| Dashboard | 3 | 1,000 |
| **TOTAL** | **58** | **~14,380** |

---

## APPENDIX B: Dependencies to Add

Add to Package.swift if needed:

```swift
// HealthKit (built-in, no package needed)
// SwiftData (built-in, no package needed)
// Charts (built-in, import Charts)

// Optional for enhanced features:
.package(url: "https://github.com/siteline/swiftui-introspect", from: "1.0.0"),
```

---

## APPENDIX C: AI Infrastructure Integration Options (Session 3 Research)

Based on comprehensive analysis of 11 additional AI infrastructure and development tools:

### Memory & Context Layer
| Tool | Purpose | Integration Priority |
|------|---------|---------------------|
| **Mem0** | Persistent AI memory, cross-session context | HIGH - Core for personalization |
| **ChromaDB** | Local vector storage, semantic search | HIGH - RAG capabilities |

### Voice & Communication
| Tool | Purpose | Integration Priority |
|------|---------|---------------------|
| **Vapi AI** | Voice agent platform, multi-provider STT/TTS/LLM | MEDIUM - Voice interface |
| **Fireflies.AI** | Meeting transcription, AskFred search | LOW - Meeting intelligence |
| **HeyGen** | AI video avatars, voice cloning | LOW - Content generation |

### Agent Orchestration
| Tool | Purpose | Integration Priority |
|------|---------|---------------------|
| **Lindy AI** | Multi-agent societies, HITL workflows | MEDIUM - Agent patterns |
| **Sider AI** | Browser sidebar, multi-model comparison | LOW - UI patterns |

### Development Acceleration
| Tool | Purpose | Integration Priority |
|------|---------|---------------------|
| **Bolt.new** | Browser-based full-stack dev | REFERENCE - Architecture patterns |
| **Builder.io** | Design-to-code, Figma integration | REFERENCE - Visual dev workflows |
| **Base44** | No-code app building | REFERENCE - Conversational UX |
| **Create.xyz** | Text-to-app platform | REFERENCE - Rapid prototyping |

### Recommended Implementation Order

1. **Phase 1 (Core)**: ChromaDB for local vector storage + Mem0-style memory architecture
2. **Phase 2 (Voice)**: Vapi-style voice pipeline with multi-provider flexibility
3. **Phase 3 (Agents)**: Lindy-style agent orchestration with human-in-the-loop
4. **Phase 4 (Advanced)**: Meeting intelligence, browser assistance patterns

### Key Architecture Patterns to Adopt

- **Multi-provider orchestration** (Vapi): Abstract STT/TTS/LLM providers behind unified interface
- **Persistent memory** (Mem0): User profiles + conversation history + learned preferences
- **Local-first vector search** (ChromaDB): Privacy-preserving semantic search
- **Human-in-the-loop** (Lindy): Approval workflows for high-impact agent actions
- **Multi-model comparison** (Sider): A/B test different LLMs for quality assurance

---

**Document Complete. Follow this strategy exactly for zero-error implementation.**

