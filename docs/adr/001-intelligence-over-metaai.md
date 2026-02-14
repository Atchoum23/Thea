# ADR-001: Intelligence Layer Over MetaAI

**Date:** 2026-02-08
**Status:** Accepted

## Context

Thea had two overlapping AI orchestration layers:
- `Shared/AI/MetaAI/` (~73 files) — original implementation with types like `MetaAIMCPServerInfo`, `AIErrorContext`, `ModelCapabilityRecord`
- `Shared/Intelligence/` — newer implementation with `TaskClassifier`, `ModelRouter`, `SmartModelRouter`, `ConfidenceSystem`

Both layers defined similar types, causing compilation conflicts when both were active.

## Decision

**Keep `Intelligence/` as the canonical AI orchestration layer. Keep `MetaAI/` excluded from all builds.**

## Rationale

- Intelligence layer follows cleaner MVVM patterns with protocol-based composition
- Intelligence types (`TaskClassifier`, `ModelRouter`) are already wired into `ChatManager.selectProviderAndModel()`
- MetaAI has ~73 files with documented type conflicts that would require extensive renaming
- Activating MetaAI provides no unique functionality not already in Intelligence
- The excluded MetaAI files are preserved in source control for reference

## Consequences

- All new AI orchestration code goes in `Intelligence/`
- MetaAI remains excluded via `**/AI/MetaAI/**` in project.yml
- If MetaAI functionality is needed, it must be migrated to Intelligence with proper naming
