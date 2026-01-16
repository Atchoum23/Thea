import Foundation
import SwiftUI

#if os(macOS)
  import AppKit
#else
  import UIKit
#endif

@MainActor
@Observable
final class HandoffManager: NSObject {
  static let shared = HandoffManager()

  private(set) var currentActivity: NSUserActivity?
  private(set) var isHandoffAvailable: Bool = false

  private override init() {
    super.init()
  }

  // MARK: - Conversation Handoff

  func startConversationActivity(_ conversation: Conversation) {
    let activity = NSUserActivity(activityType: "app.teathe.thea.conversation")
    activity.title = conversation.title
    activity.userInfo = [
      "conversationID": conversation.id.uuidString,
      "title": conversation.title,
    ]
    activity.isEligibleForHandoff = true
    activity.isEligibleForSearch = true

    #if os(iOS) || os(watchOS)
      activity.isEligibleForPrediction = true
      activity.becomeCurrent()
    #endif

    currentActivity = activity
    isHandoffAvailable = true
  }

  func continueConversationActivity(_ userActivity: NSUserActivity) -> UUID? {
    guard userActivity.activityType == "app.teathe.thea.conversation" else {
      return nil
    }

    guard let conversationIDString = userActivity.userInfo?["conversationID"] as? String,
      let conversationID = UUID(uuidString: conversationIDString)
    else {
      return nil
    }

    return conversationID
  }

  // MARK: - Project Handoff

  func startProjectActivity(_ project: Project) {
    let activity = NSUserActivity(activityType: "app.teathe.thea.project")
    activity.title = project.title
    activity.userInfo = [
      "projectID": project.id.uuidString,
      "title": project.title,
    ]
    activity.isEligibleForHandoff = true
    activity.isEligibleForSearch = true

    #if os(iOS) || os(watchOS)
      activity.isEligibleForPrediction = true
      activity.becomeCurrent()
    #endif

    currentActivity = activity
    isHandoffAvailable = true
  }

  func continueProjectActivity(_ userActivity: NSUserActivity) -> UUID? {
    guard userActivity.activityType == "app.teathe.thea.project" else {
      return nil
    }

    guard let projectIDString = userActivity.userInfo?["projectID"] as? String,
      let projectID = UUID(uuidString: projectIDString)
    else {
      return nil
    }

    return projectID
  }

  // MARK: - Code Workspace Handoff

  func startWorkspaceActivity(_ workspaceURL: URL) {
    let activity = NSUserActivity(activityType: "app.teathe.thea.workspace")
    activity.title = "Workspace: \(workspaceURL.lastPathComponent)"
    activity.userInfo = [
      "workspacePath": workspaceURL.path
    ]
    activity.isEligibleForHandoff = true

    #if os(iOS)
      activity.becomeCurrent()
    #endif

    currentActivity = activity
    isHandoffAvailable = true
  }

  func continueWorkspaceActivity(_ userActivity: NSUserActivity) -> URL? {
    guard userActivity.activityType == "app.teathe.thea.workspace" else {
      return nil
    }

    guard let workspacePath = userActivity.userInfo?["workspacePath"] as? String else {
      return nil
    }

    return URL(fileURLWithPath: workspacePath)
  }

  // MARK: - Stop Activity

  func stopCurrentActivity() {
    currentActivity?.invalidate()
    currentActivity = nil
    isHandoffAvailable = false
  }

  // MARK: - Universal Links

  func handleUniversalLink(_ url: URL) -> HandoffAction? {
    guard url.host == "teathe.app" else { return nil }

    let pathComponents = url.pathComponents.filter { $0 != "/" }

    guard pathComponents.count >= 2 else { return nil }

    let actionType = pathComponents[0]
    let identifier = pathComponents[1]

    switch actionType {
    case "conversation":
      if let conversationID = UUID(uuidString: identifier) {
        return .openConversation(conversationID)
      }
    case "project":
      if let projectID = UUID(uuidString: identifier) {
        return .openProject(projectID)
      }
    case "workspace":
      let workspacePath = pathComponents.dropFirst().joined(separator: "/")
      return .openWorkspace(URL(fileURLWithPath: "/" + workspacePath))
    default:
      break
    }

    return nil
  }

  // MARK: - Generate Universal Link

  func generateUniversalLink(for conversation: Conversation) -> URL? {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "teathe.app"
    components.path = "/conversation/\(conversation.id.uuidString)"
    return components.url
  }

  func generateUniversalLink(for project: Project) -> URL? {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "teathe.app"
    components.path = "/project/\(project.id.uuidString)"
    return components.url
  }
}

// MARK: - Handoff Action

enum HandoffAction {
  case openConversation(UUID)
  case openProject(UUID)
  case openWorkspace(URL)
}

// MARK: - App Delegate Extensions

#if os(iOS)
  extension UIApplication {
    func continueUserActivity(_ userActivity: NSUserActivity) -> Bool {
      let handoffManager = HandoffManager.shared

      if let conversationID = handoffManager.continueConversationActivity(userActivity) {
        NotificationCenter.default.post(
          name: .openConversation,
          object: nil,
          userInfo: ["conversationID": conversationID]
        )
        return true
      }

      if let projectID = handoffManager.continueProjectActivity(userActivity) {
        NotificationCenter.default.post(
          name: .openProject,
          object: nil,
          userInfo: ["projectID": projectID]
        )
        return true
      }

      if let workspaceURL = handoffManager.continueWorkspaceActivity(userActivity) {
        NotificationCenter.default.post(
          name: .openWorkspace,
          object: nil,
          userInfo: ["workspaceURL": workspaceURL]
        )
        return true
      }

      return false
    }
  }
#endif

#if os(macOS)
  extension NSApplication {
    func continueUserActivity(_ userActivity: NSUserActivity) -> Bool {
      let handoffManager = HandoffManager.shared

      if let conversationID = handoffManager.continueConversationActivity(userActivity) {
        NotificationCenter.default.post(
          name: .openConversation,
          object: nil,
          userInfo: ["conversationID": conversationID]
        )
        return true
      }

      if let projectID = handoffManager.continueProjectActivity(userActivity) {
        NotificationCenter.default.post(
          name: .openProject,
          object: nil,
          userInfo: ["projectID": projectID]
        )
        return true
      }

      if let workspaceURL = handoffManager.continueWorkspaceActivity(userActivity) {
        NotificationCenter.default.post(
          name: .openWorkspace,
          object: nil,
          userInfo: ["workspaceURL": workspaceURL]
        )
        return true
      }

      return false
    }
  }
#endif

// MARK: - Notification Names

extension Notification.Name {
  static let openConversation = Notification.Name("openConversation")
  static let openProject = Notification.Name("openProject")
  static let openWorkspace = Notification.Name("openWorkspace")
}
