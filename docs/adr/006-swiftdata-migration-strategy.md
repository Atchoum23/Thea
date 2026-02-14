# ADR-006: SwiftData Migration Strategy

**Date:** 2026-02-09
**Status:** Accepted

## Context

Adding non-optional `@Model` properties to existing SwiftData schema breaks CoreData lightweight migration. Users who had an older schema version would see a crash on launch because `ModelContainer` fails to initialize and caches the failure for the process lifetime.

## Decision

**Use SQLite pre-flight schema validation before `ModelContainer` initialization.**

### Implementation

1. In `TheamacOSApp.init()`, open the SQLite store directly (bypassing SwiftData)
2. Check if expected columns exist in the schema using `PRAGMA table_info()`
3. If schema is outdated: delete the store file BEFORE `ModelContainer` init
4. `ModelContainer` then creates a fresh store with the current schema

### Key Constraint

CoreData/SwiftData caches store initialization failures within a process. The store must be deleted BEFORE the first `ModelContainer` init attempt — deleting after a failed init and retrying does NOT work in the same process.

## Rationale

- SwiftData's built-in lightweight migration doesn't handle non-optional property additions
- Pre-flight validation is the only way to detect and handle this before SwiftData sees the store
- Deleting the store loses local data but prevents permanent launch crashes
- For Thea, CloudKit sync will re-populate data from iCloud after store recreation

## Consequences

- All new non-optional `@Model` properties must have the pre-flight check updated
- Data loss on schema change is acceptable because CloudKit sync recovers data
- Future improvement: add migration mapping models for lossless schema evolution
