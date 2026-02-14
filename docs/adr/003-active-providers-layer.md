# ADR-003: Active AI Providers Layer

**Date:** 2026-02-08
**Status:** Accepted

## Context

Thea had two provider layers:
- `Shared/Providers/` (excluded) — original implementation with `ProviderError`, `ChatMessage`, `ChatContentPart`, `ProviderRegistry`
- `Shared/AI/Providers/` (active) — current implementation with `AnthropicError`, `AIMessage`, `AnthropicService`, `OpenRouterService`, etc.

Files being activated from excluded paths referenced types from the old Providers layer.

## Decision

**`Shared/AI/Providers/` is the canonical provider layer. All excluded code being activated must be ported to use active-layer types.**

## Type Mapping

| Old (Excluded) | New (Active) |
|---|---|
| `ProviderError` | `AnthropicError` |
| `ChatMessage` | `AIMessage` |
| `ChatOptions` | Direct parameters on `provider.chat()` |
| `ChatContentPart` | Removed (use `AIMessage` content directly) |
| `ProviderRegistry.shared.bestAvailableProvider` | `ProviderRegistry.shared.getDefaultProvider()` |
| `AIProviderHelpers.streamToString()` | Private `streamToString()` helper per file |

## Rationale

- Active layer uses Swift 6 concurrency (async/await, Sendable)
- Active layer has proper error typing with `AnthropicError` cases
- Old layer used pre-Swift 6 patterns (completion handlers, generic `ProviderError`)
- Keeping one canonical layer prevents type confusion

## Consequences

- When porting excluded files, ALL type references must be updated
- Access control must match — `internal` (default) not `public` when active types are `internal`
- `AnthropicError` was extended with additional cases (`invalidResponseDetails`, `serverError`, `fileTooLarge`) to cover scenarios from the old layer
