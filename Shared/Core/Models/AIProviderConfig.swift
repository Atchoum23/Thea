import Foundation
import SwiftData

@Model
final class AIProviderConfig {
  @Attribute(.unique) var id: UUID
  var providerName: String
  var displayName: String
  var isEnabled: Bool
  var hasValidAPIKey: Bool
  var installedAt: Date
  var pluginVersion: String?

  init(
    id: UUID = UUID(),
    providerName: String,
    displayName: String,
    isEnabled: Bool = true,
    hasValidAPIKey: Bool = false,
    installedAt: Date = Date(),
    pluginVersion: String? = nil
  ) {
    self.id = id
    self.providerName = providerName
    self.displayName = displayName
    self.isEnabled = isEnabled
    self.hasValidAPIKey = hasValidAPIKey
    self.installedAt = installedAt
    self.pluginVersion = pluginVersion
  }
}

// MARK: - Identifiable

extension AIProviderConfig: Identifiable {}
