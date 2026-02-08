//
//  AnnotationOverlayService.swift
//  Thea
//
//  Screen annotation tools for remote desktop sessions (draw, highlight, point)
//

import Combine
import CoreGraphics
import Foundation

// MARK: - Annotation Overlay Service

/// Manages screen annotations during remote desktop sessions
@MainActor
public class AnnotationOverlayService: ObservableObject {
    // MARK: - Published State

    @Published public private(set) var annotations: [AnnotationData] = []
    @Published public private(set) var isAnnotating = false
    @Published public var currentTool: AnnotationData.AnnotationShape = .freehand
    @Published public var currentColor: AnnotationData.AnnotationColor = .red
    @Published public var currentLineWidth: Float = 3.0

    // MARK: - Callbacks

    public var onAnnotationAdded: ((AnnotationData) -> Void)?
    public var onAnnotationRemoved: ((String) -> Void)?
    public var onAnnotationsCleared: (() -> Void)?

    // MARK: - Undo Stack

    private var undoStack: [AnnotationData] = []
    private let maxAnnotations = 100

    // MARK: - Initialization

    public init() {}

    // MARK: - Annotation Tools

    /// Start annotation mode
    public func startAnnotating() {
        isAnnotating = true
    }

    /// Stop annotation mode
    public func stopAnnotating() {
        isAnnotating = false
    }

    // MARK: - Add Annotations

    /// Add a freehand drawing
    public func addFreehand(points: [CGPoint]) {
        let annotation = AnnotationData(
            shape: .freehand,
            color: currentColor,
            lineWidth: currentLineWidth,
            points: points
        )
        addAnnotation(annotation)
    }

    /// Add a line
    public func addLine(from start: CGPoint, to end: CGPoint) {
        let annotation = AnnotationData(
            shape: .line,
            color: currentColor,
            lineWidth: currentLineWidth,
            points: [start, end]
        )
        addAnnotation(annotation)
    }

    /// Add an arrow
    public func addArrow(from start: CGPoint, to end: CGPoint) {
        let annotation = AnnotationData(
            shape: .arrow,
            color: currentColor,
            lineWidth: currentLineWidth,
            points: [start, end]
        )
        addAnnotation(annotation)
    }

    /// Add a rectangle
    public func addRectangle(origin: CGPoint, size: CGSize) {
        let annotation = AnnotationData(
            shape: .rectangle,
            color: currentColor,
            lineWidth: currentLineWidth,
            points: [origin, CGPoint(x: origin.x + size.width, y: origin.y + size.height)]
        )
        addAnnotation(annotation)
    }

    /// Add a circle
    public func addCircle(center: CGPoint, radius: CGFloat) {
        let annotation = AnnotationData(
            shape: .circle,
            color: currentColor,
            lineWidth: currentLineWidth,
            points: [center, CGPoint(x: center.x + radius, y: center.y)]
        )
        addAnnotation(annotation)
    }

    /// Add a text annotation
    public func addText(_ text: String, at position: CGPoint) {
        let annotation = AnnotationData(
            shape: .text,
            color: currentColor,
            lineWidth: currentLineWidth,
            points: [position],
            text: text
        )
        addAnnotation(annotation)
    }

    /// Add a highlight rectangle
    public func addHighlight(origin: CGPoint, size: CGSize) {
        let annotation = AnnotationData(
            shape: .highlight,
            color: .yellow,
            lineWidth: currentLineWidth,
            points: [origin, CGPoint(x: origin.x + size.width, y: origin.y + size.height)]
        )
        addAnnotation(annotation)
    }

    /// Add annotation from remote
    public func addRemoteAnnotation(_ annotation: AnnotationData) {
        annotations.append(annotation)
        trimAnnotations()
    }

    // MARK: - Remove Annotations

    /// Remove a specific annotation
    public func removeAnnotation(id: String) {
        annotations.removeAll { $0.id == id }
        onAnnotationRemoved?(id)
    }

    /// Clear all annotations
    public func clearAnnotations() {
        undoStack.append(contentsOf: annotations)
        annotations.removeAll()
        onAnnotationsCleared?()
    }

    /// Undo the last annotation
    public func undoLastAnnotation() {
        guard !annotations.isEmpty else { return }
        let removed = annotations.removeLast()
        undoStack.append(removed)
        onAnnotationRemoved?(removed.id)
    }

    /// Redo the last undone annotation
    public func redoAnnotation() {
        guard !undoStack.isEmpty else { return }
        let annotation = undoStack.removeLast()
        annotations.append(annotation)
        onAnnotationAdded?(annotation)
    }

    // MARK: - Private

    private func addAnnotation(_ annotation: AnnotationData) {
        annotations.append(annotation)
        undoStack.removeAll()
        trimAnnotations()
        onAnnotationAdded?(annotation)
    }

    private func trimAnnotations() {
        if annotations.count > maxAnnotations {
            annotations.removeFirst(annotations.count - maxAnnotations)
        }
    }
}
