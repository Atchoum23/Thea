# ADR-004: @unchecked Sendable Policy

**Date:** 2026-02-10
**Status:** Accepted

## Context

Swift 6 strict concurrency requires types shared across actor boundaries to conform to `Sendable`. The codebase had 48+ uses of `@unchecked Sendable` — a compiler escape hatch that bypasses Sendable checking.

The SWIFT_STRICT_CONCURRENCY build setting is `complete`, meaning all Sendable violations are errors.

## Decision

**Audit all `@unchecked Sendable` uses. Convert to proper `Sendable` where safe. Keep `@unchecked` only where structurally necessary, with documented justification.**

### Categories Where @unchecked Sendable Is Justified

1. **NSObject delegates** (9 uses) — ObjC inheritance prevents Sendable conformance (AVSpeechSynthesizerDelegate, UNUserNotificationCenterDelegate, etc.)
2. **Types with `Any` properties** (15+ uses) — `Any`, `[String: Any]`, `AnyCodable` are not Sendable by definition
3. **Code execution engines** (3 uses) — JavaScriptCore/Process isolation requires manual safety
4. **System type wrappers** (5+ uses) — `MLModel`, `URLSession` delegates
5. **SwiftData @Model classes** — `Conversation`, `Message` etc. managed by SwiftData actor isolation

### Categories Safely Converted to Sendable

- `ActionPattern` — all `let` properties of Sendable types + `@Sendable` closure
- `UIElementInfo` — all `let` properties of Sendable types

## Rationale

- Blindly converting to `Sendable` causes build failures when types contain non-Sendable stored properties
- Actor conversion (the ideal solution for mutable classes) is a larger refactor deferred to a future session
- Each `@unchecked Sendable` use has been manually verified for thread safety

## Consequences

- New types should prefer `Sendable` or `actor` over `@unchecked Sendable`
- Each `@unchecked Sendable` in the codebase has been audited and justified
- Future work: convert mutable `@unchecked Sendable` classes to actors where feasible
