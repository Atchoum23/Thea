//
//  RemoteChatAnnotationMessages.swift
//  Thea
//
//  Chat and annotation message types for remote server protocol
//

import CoreGraphics
import Foundation

// MARK: - Chat Messages

public struct ChatMessageData: Codable, Sendable, Identifiable {
    public let id: String
    public let senderId: String
    public let senderName: String
    public let text: String
    public let timestamp: Date

    public init(senderId: String, senderName: String, text: String) {
        id = UUID().uuidString
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        timestamp = Date()
    }
}

// MARK: - Annotation Messages

public enum AnnotationRequest: Codable, Sendable {
    case addAnnotation(AnnotationData)
    case removeAnnotation(id: String)
    case clearAnnotations
    case undoLastAnnotation
}

public struct AnnotationData: Codable, Sendable, Identifiable {
    public let id: String
    public let shape: AnnotationShape
    public let color: AnnotationColor
    public let lineWidth: Float
    public let points: [CGPoint]
    public let text: String?
    public let timestamp: Date

    public init(shape: AnnotationShape, color: AnnotationColor, lineWidth: Float = 2.0, points: [CGPoint], text: String? = nil) {
        id = UUID().uuidString
        self.shape = shape
        self.color = color
        self.lineWidth = lineWidth
        self.points = points
        self.text = text
        timestamp = Date()
    }

    public enum AnnotationShape: String, Codable, Sendable {
        case freehand
        case line
        case arrow
        case rectangle
        case circle
        case text
        case highlight
    }

    public struct AnnotationColor: Codable, Sendable {
        public let red: Float
        public let green: Float
        public let blue: Float
        public let alpha: Float

        public init(red: Float, green: Float, blue: Float, alpha: Float = 1.0) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }

        public static let red = AnnotationColor(red: 1, green: 0, blue: 0)
        public static let blue = AnnotationColor(red: 0, green: 0, blue: 1)
        public static let green = AnnotationColor(red: 0, green: 1, blue: 0)
        public static let yellow = AnnotationColor(red: 1, green: 1, blue: 0, alpha: 0.5)
    }
}
