# ADR-005: Multi-Device Sync Architecture

**Date:** 2026-02-09
**Status:** Accepted

## Context

Thea runs across 4 Apple platforms (macOS, iOS, watchOS, tvOS) and 2 development Macs (Mac Studio M3 Ultra, MacBook Air M2). Data sync and cross-device AI inference routing are core requirements.

## Decision

**Use a layered sync architecture:**

1. **Persistent data sync**: iCloud/CloudKit via `CloudKitService` (conversations, messages, settings, projects)
2. **Local inference relay**: Bonjour/Network.framework via `RemoteMacBridge` (LAN discovery of Mac Studio for on-device model inference)
3. **Code sync**: Git via `git pushsync` (pushes to origin + triggers rebuild on the other Mac via SSH)
4. **Session sync**: rsync via `claude-session-sync.sh` (Claude Code/Desktop sessions between Macs)

### Sync Protocol Details

- **CloudKit**: Delta sync with `CKServerChangeToken` for efficient polling. `CKSubscription` for push notifications. Conflict resolution via server record merge with timestamp tiebreaker.
- **Bonjour**: `NWBrowser` discovers `_thea._tcp` services on LAN. `NWConnection` sends inference requests to Mac Studio. Falls back gracefully when off-LAN.
- **Git pushsync**: Custom git alias that pushes to origin, then SSHs to the other Mac to trigger `thea-sync.sh` (pull, xcodegen, build, install).

### Future Enhancement: Tailscale Fallback

When devices are NOT on the same LAN (e.g., traveling with MacBook Air, Apple Watch on cellular), a Tailscale-based fallback for inference relay is recommended:
- Detect Bonjour discovery failure/timeout
- Fall back to Tailscale IP (stored in device config)
- Use same relay protocol over Tailscale TCP connection
- This is a design decision for the owner — NOT implemented in this pass

## Rationale

- CloudKit is the natural choice for Apple ecosystem persistent sync
- Bonjour is zero-configuration for LAN — no IP addresses needed
- Git is already the code sync mechanism; pushsync extends it with build triggers
- Each layer handles its specific data type with appropriate latency/consistency tradeoffs

## Consequences

- `CloudKitService` is the canonical sync implementation (not `CloudSyncManager`, which was removed as dead code)
- `RemoteMacBridge` handles LAN inference relay via Bonjour
- `DeviceRegistry` tracks device identities for message origin tracking
- Cross-device notifications use `CrossDeviceNotificationService` via CloudKit
