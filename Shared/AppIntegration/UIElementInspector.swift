//
//  UIElementInspector.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation
#if os(macOS)
import AppKit
import ApplicationServices
#endif

// MARK: - UI Element Inspector

/// Inspects and interacts with UI elements across applications
public actor UIElementInspector {
    public static let shared = UIElementInspector()

    // MARK: - Initialization

    private init() {}

    // MARK: - Element Discovery

    /// Get the UI element at a specific screen position
    public func getElementAt(point: CGPoint) async throws -> UIElementInfo? {
        #if os(macOS)
        var element: AXUIElement?
        let systemWide = AXUIElementCreateSystemWide()

        var elementRef: CFTypeRef?
        let result = AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &elementRef)

        guard result == .success, let ref = elementRef else {
            return nil
        }

        element = (ref as! AXUIElement)
        return try await getElementInfo(element!)
        #else
        throw IntegrationError.notSupported
        #endif
    }

    /// Get the focused element in the frontmost app
    public func getFocusedElement() async throws -> UIElementInfo? {
        #if os(macOS)
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)

        guard result == .success, let element = focusedElement else {
            return nil
        }

        return try await getElementInfo(element as! AXUIElement)
        #else
        throw IntegrationError.notSupported
        #endif
    }

    /// Get all UI elements in an application
    public func getElements(in bundleId: String) async throws -> [UIElementInfo] {
        #if os(macOS)
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }) else {
            throw IntegrationError.appNotFound(bundleId)
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        return try await getChildElements(of: appElement)
        #else
        throw IntegrationError.notSupported
        #endif
    }

    /// Find elements matching a predicate
    public func findElements(
        in bundleId: String,
        matching predicate: @Sendable (UIElementInfo) -> Bool
    ) async throws -> [UIElementInfo] {
        let allElements = try await getElements(in: bundleId)
        return allElements.filter(predicate)
    }

    /// Find element by role and title
    public func findElement(
        in bundleId: String,
        role: String,
        title: String? = nil
    ) async throws -> UIElementInfo? {
        let elements = try await findElements(in: bundleId) { element in
            if element.role != role { return false }
            if let title = title, element.title != title { return false }
            return true
        }
        return elements.first
    }

    // MARK: - Element Interaction

    /// Click on an element
    public func clickElement(_ element: UIElementInfo) async throws {
        #if os(macOS)
        guard let axElement = element.axElement else {
            throw IntegrationError.elementNotFound
        }

        let result = AXUIElementPerformAction(axElement, kAXPressAction as CFString)
        guard result == .success else {
            throw IntegrationError.actionFailed("Click failed")
        }
        #else
        throw IntegrationError.notSupported
        #endif
    }

    /// Set the value of an element
    public func setValue(_ value: String, for element: UIElementInfo) async throws {
        #if os(macOS)
        guard let axElement = element.axElement else {
            throw IntegrationError.elementNotFound
        }

        let result = AXUIElementSetAttributeValue(axElement, kAXValueAttribute as CFString, value as CFTypeRef)
        guard result == .success else {
            throw IntegrationError.actionFailed("Set value failed")
        }
        #else
        throw IntegrationError.notSupported
        #endif
    }

    /// Get the value of an element
    public func getValue(of element: UIElementInfo) async throws -> String? {
        #if os(macOS)
        guard let axElement = element.axElement else {
            throw IntegrationError.elementNotFound
        }

        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axElement, kAXValueAttribute as CFString, &value)

        guard result == .success, let stringValue = value as? String else {
            return nil
        }

        return stringValue
        #else
        throw IntegrationError.notSupported
        #endif
    }

    // MARK: - Helper Methods

    #if os(macOS)
    private func getElementInfo(_ element: AXUIElement) async throws -> UIElementInfo {
        var role: CFTypeRef?
        var title: CFTypeRef?
        var value: CFTypeRef?
        var position: CFTypeRef?
        var size: CFTypeRef?

        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position)
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size)

        var frame = CGRect.zero

        if let positionValue = position {
            var point = CGPoint.zero
            AXValueGetValue(positionValue as! AXValue, .cgPoint, &point)
            frame.origin = point
        }

        if let sizeValue = size {
            var sizeVal = CGSize.zero
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &sizeVal)
            frame.size = sizeVal
        }

        return UIElementInfo(
            role: (role as? String) ?? "unknown",
            title: title as? String,
            value: value as? String,
            frame: frame,
            axElement: element
        )
    }

    private func getChildElements(of element: AXUIElement) async throws -> [UIElementInfo] {
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)

        guard result == .success, let childArray = children as? [AXUIElement] else {
            return []
        }

        var elements: [UIElementInfo] = []

        for child in childArray {
            if let info = try? await getElementInfo(child) {
                elements.append(info)
                // Recursively get children
                let childElements = try await getChildElements(of: child)
                elements.append(contentsOf: childElements)
            }
        }

        return elements
    }
    #endif
}

// MARK: - UI Element Info

public struct UIElementInfo: Sendable, Identifiable {
    public let id = UUID()
    public let role: String
    public let title: String?
    public let value: String?
    public let frame: CGRect

    #if os(macOS)
    public let axElement: AXUIElement?
    #else
    public let axElement: AnyObject? = nil
    #endif

    public var isClickable: Bool {
        ["AXButton", "AXMenuItem", "AXLink", "AXCheckBox", "AXRadioButton"].contains(role)
    }

    public var isTextField: Bool {
        ["AXTextField", "AXTextArea", "AXSearchField", "AXComboBox"].contains(role)
    }

    public var description: String {
        var desc = role
        if let title = title {
            desc += ": \(title)"
        }
        if let value = value, !value.isEmpty {
            desc += " = \"\(value)\""
        }
        return desc
    }

    #if os(macOS)
    public init(role: String, title: String?, value: String?, frame: CGRect, axElement: AXUIElement?) {
        self.role = role
        self.title = title
        self.value = value
        self.frame = frame
        self.axElement = axElement
    }
    #else
    public init(role: String, title: String?, value: String?, frame: CGRect) {
        self.role = role
        self.title = title
        self.value = value
        self.frame = frame
    }
    #endif
}

// MARK: - App Capability Registry

/// Registry of app capabilities for automation
public actor AppCapabilityRegistry {
    public static let shared = AppCapabilityRegistry()

    // MARK: - State

    private var capabilities: [String: AppCapabilities] = [:]

    // MARK: - Initialization

    private init() {
        loadDefaultCapabilities()
    }

    private func loadDefaultCapabilities() {
        // Register common app capabilities
        capabilities["com.apple.Safari"] = AppCapabilities(
            canReadContent: true,
            canNavigate: true,
            canExecuteScript: true,
            knownElements: [
                "AXTextField": "URL bar",
                "AXWebArea": "Web content"
            ]
        )

        capabilities["com.apple.finder"] = AppCapabilities(
            canReadContent: true,
            canNavigate: true,
            canExecuteScript: false,
            knownElements: [
                "AXList": "File list",
                "AXOutline": "Sidebar"
            ]
        )

        capabilities["com.apple.TextEdit"] = AppCapabilities(
            canReadContent: true,
            canNavigate: false,
            canExecuteScript: false,
            knownElements: [
                "AXTextArea": "Document content"
            ]
        )
    }

    // MARK: - Registry

    /// Get capabilities for an app
    public func getCapabilities(for bundleId: String) -> AppCapabilities? {
        capabilities[bundleId]
    }

    /// Register capabilities for an app
    public func registerCapabilities(_ caps: AppCapabilities, for bundleId: String) {
        capabilities[bundleId] = caps
    }

    /// Check if an app has a specific capability
    public func hasCapability(_ bundleId: String, capability: String) -> Bool {
        guard let caps = capabilities[bundleId] else { return false }

        switch capability {
        case "readContent":
            return caps.canReadContent
        case "navigate":
            return caps.canNavigate
        case "executeScript":
            return caps.canExecuteScript
        default:
            return false
        }
    }
}

// MARK: - App Capabilities

public struct AppCapabilities: Codable, Sendable {
    public let canReadContent: Bool
    public let canNavigate: Bool
    public let canExecuteScript: Bool
    public let knownElements: [String: String]

    public init(
        canReadContent: Bool = false,
        canNavigate: Bool = false,
        canExecuteScript: Bool = false,
        knownElements: [String: String] = [:]
    ) {
        self.canReadContent = canReadContent
        self.canNavigate = canNavigate
        self.canExecuteScript = canExecuteScript
        self.knownElements = knownElements
    }
}
