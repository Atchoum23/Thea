import SwiftUI

// MARK: - Reduce Motion Aware Animation

/// All animation presets are defined in TheaDesignSystem.swift → TheaAnimation enum.
/// This file provides the reduce-motion helper extension.

extension View {
    /// Applies animation only when reduce motion is not enabled
    func theaAnimation<V: Equatable>(
        _ animation: Animation,
        value: V,
        reduceMotion: Bool
    ) -> some View {
        self.animation(reduceMotion ? nil : animation, value: value)
    }
}
