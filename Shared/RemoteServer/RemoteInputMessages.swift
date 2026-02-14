//
//  RemoteInputMessages.swift
//  Thea
//
//  Input control message types for remote server protocol
//

import Foundation

// MARK: - Input Messages

public enum InputRequest: Codable, Sendable {
    // Mouse
    case mouseMove(x: Int, y: Int)
    case mouseClick(x: Int, y: Int, button: MouseButton, clickCount: Int)
    case mouseDown(x: Int, y: Int, button: MouseButton)
    case mouseUp(x: Int, y: Int, button: MouseButton)
    case mouseDrag(fromX: Int, fromY: Int, toX: Int, toY: Int, button: MouseButton)
    case scroll(x: Int, y: Int, deltaX: Int, deltaY: Int)

    // Keyboard
    case keyPress(keyCode: UInt16, modifiers: RemoteKeyModifiers)
    case keyDown(keyCode: UInt16, modifiers: RemoteKeyModifiers)
    case keyUp(keyCode: UInt16, modifiers: RemoteKeyModifiers)
    case typeText(String)

    // Clipboard
    case setClipboard(String)
    case getClipboard

    public enum MouseButton: String, Codable, Sendable {
        case left
        case right
        case middle
    }
}

public struct RemoteKeyModifiers: OptionSet, Codable, Sendable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public static let shift = RemoteKeyModifiers(rawValue: 1 << 0)
    public static let control = RemoteKeyModifiers(rawValue: 1 << 1)
    public static let option = RemoteKeyModifiers(rawValue: 1 << 2)
    public static let command = RemoteKeyModifiers(rawValue: 1 << 3)
    public static let function = RemoteKeyModifiers(rawValue: 1 << 4)
    public static let capsLock = RemoteKeyModifiers(rawValue: 1 << 5)
}
