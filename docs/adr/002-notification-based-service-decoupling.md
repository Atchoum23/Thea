# ADR-002: Notification-Based Service Decoupling

**Date:** 2026-02-09
**Status:** Accepted

## Context

`OfflineQueueService` directly called `CloudKitService.shared.syncAll()` to replay queued sync requests. This created a hard dependency that broke Swift Package tests (CloudKitService is not in the SPM target).

Similar coupling existed between other services that needed to trigger actions across module boundaries.

## Decision

**Use `NotificationCenter` post/observe patterns for cross-service communication instead of direct singleton calls.**

## Rationale

- `#if canImport(CloudKit)` doesn't help because CloudKit framework is available but `CloudKitService.swift` isn't in the SPM target
- Notification-based dispatch decouples the sender from the receiver
- The app layer observes `.offlineRequestReplay` and routes to the appropriate service
- This pattern is testable — tests can observe notifications without needing real service implementations
- Follows existing patterns used by `CrossDeviceNotificationService` and `ResponseNotificationHandler`

## Consequences

- Services post notifications instead of calling singletons directly
- App startup code registers notification observers to wire services together
- All 47 SPM tests pass without CloudKit dependencies
- New service integrations should follow this pattern
