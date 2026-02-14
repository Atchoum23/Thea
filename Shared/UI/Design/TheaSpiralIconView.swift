import SwiftUI

// MARK: - THEA Spiral Icon

/// Animated spiral icon using the actual app icon artwork.
/// Features counter-clockwise rotation and a subtle breathing/heartbeat scale effect.
public struct TheaSpiralIconView: View {
    let size: CGFloat
    var isThinking: Bool = false
    var showGlow: Bool = true

    @State private var rotation: Double = 0
    @State private var beatScale: CGFloat = 1.0
    @State private var glowIntensity: Double = 0.5
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(size: CGFloat = 40, isThinking: Bool = false, showGlow: Bool = true) {
        self.size = size
        self.isThinking = isThinking
        self.showGlow = showGlow
    }

    public var body: some View {
        ZStack {
            // Glow layer — very gradual radial fade from warm core to imperceptible edges
            if showGlow {
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: TheaBrandColors.gold.opacity(glowIntensity * 0.55), location: 0.0),
                        .init(color: TheaBrandColors.gold.opacity(glowIntensity * 0.40), location: 0.15),
                        .init(color: TheaBrandColors.gold.opacity(glowIntensity * 0.28), location: 0.30),
                        .init(color: TheaBrandColors.gold.opacity(glowIntensity * 0.16), location: 0.45),
                        .init(color: TheaBrandColors.gold.opacity(glowIntensity * 0.08), location: 0.60),
                        .init(color: TheaBrandColors.gold.opacity(glowIntensity * 0.03), location: 0.78),
                        .init(color: Color.clear, location: 1.0)
                    ]),
                    center: .center,
                    startRadius: size * 0.1,
                    endRadius: size * 1.1
                )
                .frame(width: size * 2.4, height: size * 2.4)
            }

            // Spiral artwork — mask to a slightly inset circle to hide
            // the dark rounded-rect corners of the source image asset.
            Image("TheaSpiral")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .mask(Circle().frame(width: size * 0.92, height: size * 0.92))
                .rotationEffect(.degrees(rotation))
                .scaleEffect(beatScale)
        }
        .frame(width: size * 2.4, height: size * 2.4)
        .onAppear {
            startIdleAnimations()
            if isThinking {
                startThinkingAnimation()
            }
        }
        .onChange(of: isThinking) { _, newValue in
            if newValue {
                startThinkingAnimation()
            } else {
                stopThinkingAnimation()
            }
        }
    }

    /// Subtle idle animations: slow CW rotation + gentle breathing beat
    private func startIdleAnimations() {
        guard !reduceMotion else { return }

        // Slow clockwise rotation: one full turn per 40 seconds (noticeably alive)
        withAnimation(.linear(duration: 40).repeatForever(autoreverses: false)) {
            rotation = 360
        }

        // Breathing scale: gentle inhale/exhale every 3 seconds, like a sleeping entity
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            beatScale = 1.06
        }

        // Glow subtly pulses in sync
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            glowIntensity = 0.65
        }
    }

    private func startThinkingAnimation() {
        guard !reduceMotion else {
            glowIntensity = 0.8
            beatScale = 1.08
            return
        }
        // Faster CW rotation when thinking (awakened)
        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
            rotation = 360
        }
        // Stronger, quicker pulse when thinking
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            beatScale = 1.10
        }
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            glowIntensity = 0.9
        }
    }

    private func stopThinkingAnimation() {
        // Return to idle animations
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.5)) {
            glowIntensity = 0.5
        }
        startIdleAnimations()
    }
}
