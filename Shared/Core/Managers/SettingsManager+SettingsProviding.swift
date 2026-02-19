// SettingsManager+SettingsProviding.swift
// Thea V4 — SettingsProviding protocol conformance
//
// Declares SettingsManager's conformance to the SettingsProviding protocol.
// All required property getters are satisfied by the @Published properties
// on SettingsManager itself. The isFeatureEnabled(_:) method is provided
// by SettingsManager+FeatureFlags.swift.
//
// DIP fix: services can depend on `any SettingsProviding` instead of
// coupling directly to `SettingsManager.shared`.

import Foundation

// MARK: - Protocol Conformance

// periphery:ignore - Reserved: SettingsProviding protocol — reserved for future feature activation
extension SettingsManager: SettingsProviding {}
