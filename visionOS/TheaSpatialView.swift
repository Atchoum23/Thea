//
//  TheaSpatialView.swift
//  Thea visionOS
//
//  Real ARKitSession with HandTrackingProvider, WorldTrackingProvider,
//  and WorldAnchor persistence for Apple Vision Pro spatial computing.
//
//  This file is visionOS-only. It will be included in Thea-visionOS target
//  once the target is added to project.yml.
//

import Foundation
import os.log
import SwiftUI

#if os(visionOS)
    import ARKit
    import RealityKit

    private let logger = Logger(subsystem: "app.thea.visionos", category: "ARKit")

    // MARK: - TheaSpatialView

    /// Primary immersive RealityKit view for Thea on Vision Pro.
    /// Uses a real ARKitSession with HandTrackingProvider + WorldTrackingProvider
    /// and persists WorldAnchors across sessions.
    struct TheaSpatialView: View {

        @StateObject private var arManager = TheaARKitManager.shared
        @State private var theaAnchor: Entity?

        var body: some View {
            RealityView { content, attachments in
                // Restore persisted WorldAnchors and attach Thea entities
                await arManager.restoreWorldAnchors(in: content)

                // Place Thea's primary panel near the user at session start
                if let panel = attachments.entity(for: "theaPanel") {
                    panel.position = [0, 1.4, -0.8]
                    content.add(panel)
                    theaAnchor = panel
                }
            } attachments: {
                Attachment(id: "theaPanel") {
                    TheaFloatingPanel()
                }
            }
            .task { await arManager.startARKitSession() }
            .onDisappear { arManager.stopARKitSession() }
        }
    }

    // MARK: - Floating Panel

    private struct TheaFloatingPanel: View {
        var body: some View {
            VStack(spacing: 16) {
                Image(systemName: "brain")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                Text("Thea")
                    .font(.largeTitle.bold())
                Text("How can I help you today?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .glassBackgroundEffect()
            .frame(width: 360, height: 200)
        }
    }

    // MARK: - ARKit Manager

    /// Manages the ARKitSession lifecycle with hand + world tracking.
    @MainActor
    final class TheaARKitManager: ObservableObject {

        static let shared = TheaARKitManager()

        // MARK: Published State

        @Published private(set) var isSessionRunning = false
        @Published private(set) var leftHandAnchor: HandAnchor?
        @Published private(set) var rightHandAnchor: HandAnchor?
        @Published private(set) var worldAnchors: [WorldAnchor] = []
        @Published private(set) var sessionError: Error?

        // MARK: Private Properties

        private var session: ARKitSession?
        private let handProvider = HandTrackingProvider()
        private let worldProvider = WorldTrackingProvider()

        private init() {}

        // MARK: - Session Lifecycle

        /// Starts the ARKitSession with HandTracking + WorldTracking providers.
        func startARKitSession() async {
            guard !isSessionRunning else { return }

            let session = ARKitSession()
            self.session = session

            // Build provider list based on availability
            var providers: [any DataProvider] = []

            if HandTrackingProvider.isSupported {
                providers.append(handProvider)
                logger.info("HandTrackingProvider: supported ✓")
            } else {
                logger.warning("HandTrackingProvider: not supported on this device")
            }

            if WorldTrackingProvider.isSupported {
                providers.append(worldProvider)
                logger.info("WorldTrackingProvider: supported ✓")
            } else {
                logger.warning("WorldTrackingProvider: not supported on this device")
            }

            guard !providers.isEmpty else {
                logger.error("No supported ARKit providers — session not started")
                return
            }

            do {
                try await session.run(providers)
                isSessionRunning = true
                logger.info("ARKitSession started with \(providers.count) provider(s)")

                // Process updates concurrently
                async let _ = processHandUpdates()
                async let _ = processWorldAnchorUpdates()
            } catch {
                sessionError = error
                logger.error("ARKitSession failed to start: \(error.localizedDescription)")
            }
        }

        /// Stops the ARKitSession and cleans up providers.
        func stopARKitSession() {
            session?.stop()
            session = nil
            isSessionRunning = false
            logger.info("ARKitSession stopped")
        }

        // MARK: - Hand Tracking

        private func processHandUpdates() async {
            for await update in handProvider.anchorUpdates {
                switch update.event {
                case .added, .updated:
                    switch update.anchor.chirality {
                    case .left:
                        leftHandAnchor = update.anchor
                    case .right:
                        rightHandAnchor = update.anchor
                    }
                case .removed:
                    switch update.anchor.chirality {
                    case .left:
                        leftHandAnchor = nil
                    case .right:
                        rightHandAnchor = nil
                    }
                }
            }
        }

        // MARK: - World Tracking + Anchor Persistence

        private func processWorldAnchorUpdates() async {
            for await update in worldProvider.anchorUpdates {
                switch update.event {
                case .added:
                    if !worldAnchors.contains(where: { $0.id == update.anchor.id }) {
                        worldAnchors.append(update.anchor)
                        logger.debug("WorldAnchor added: \(update.anchor.id)")
                    }
                case .updated:
                    if let index = worldAnchors.firstIndex(where: { $0.id == update.anchor.id }) {
                        worldAnchors[index] = update.anchor
                    }
                case .removed:
                    worldAnchors.removeAll { $0.id == update.anchor.id }
                    logger.debug("WorldAnchor removed: \(update.anchor.id)")
                }
            }
        }

        /// Restores previously persisted WorldAnchors into the RealityKit content.
        func restoreWorldAnchors(in content: RealityViewContent) async {
            let persistedAnchors = worldProvider.allAnchors
            logger.info("Restoring \(persistedAnchors.count) persisted WorldAnchor(s)")

            for anchor in persistedAnchors {
                let entity = createRestoredEntity(for: anchor)
                entity.position = anchor.originFromAnchorTransform.translation
                content.add(entity)
            }
        }

        /// Creates a WorldAnchor at the given 3D position and persists it.
        @discardableResult
        func placeWorldAnchor(at position: SIMD3<Float>) async throws -> WorldAnchor {
            let transform = float4x4(translation: position)
            let anchor = WorldAnchor(originFromAnchorTransform: transform)
            try await worldProvider.addAnchor(anchor)
            logger.info("WorldAnchor placed at \(position)")
            return anchor
        }

        /// Removes a persisted WorldAnchor.
        func removeWorldAnchor(_ anchor: WorldAnchor) async throws {
            try await worldProvider.removeAnchor(anchor)
            logger.info("WorldAnchor removed: \(anchor.id)")
        }

        // MARK: - Pinch Gesture Detection

        /// Returns true if the specified hand is performing a pinch gesture.
        func isPinching(chirality: HandAnchor.Chirality) -> Bool {
            let hand = chirality == .left ? leftHandAnchor : rightHandAnchor
            guard let hand,
                  let skeleton = hand.handSkeleton else { return false }

            let thumbTip = skeleton.joint(.thumbTip)
            let indexTip = skeleton.joint(.indexFingerTip)

            guard thumbTip.isTracked && indexTip.isTracked else { return false }

            // Compute distance between thumb tip and index finger tip in world space
            let thumbPos = (hand.originFromAnchorTransform * thumbTip.anchorFromJointTransform).translation
            let indexPos = (hand.originFromAnchorTransform * indexTip.anchorFromJointTransform).translation
            let distance = simd_distance(thumbPos, indexPos)

            return distance < 0.025 // < 2.5 cm = pinch
        }

        // MARK: - Private Helpers

        private func createRestoredEntity(for anchor: WorldAnchor) -> Entity {
            let entity = Entity()
            entity.name = "RestoredAnchor-\(anchor.id)"
            // Attach a small visual indicator for debug builds
            #if DEBUG
                let sphere = MeshResource.generateSphere(radius: 0.02)
                let material = SimpleMaterial(color: .blue.withAlphaComponent(0.5), isMetallic: false)
                let model = ModelEntity(mesh: sphere, materials: [material])
                entity.addChild(model)
            #endif
            return entity
        }
    }

    // MARK: - SIMD helpers

    private extension float4x4 {
        init(translation: SIMD3<Float>) {
            self = matrix_identity_float4x4
            columns.3 = SIMD4(translation.x, translation.y, translation.z, 1)
        }

        var translation: SIMD3<Float> {
            SIMD3(columns.3.x, columns.3.y, columns.3.z)
        }
    }

#endif // os(visionOS)
