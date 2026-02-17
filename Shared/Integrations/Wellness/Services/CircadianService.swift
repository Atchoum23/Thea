import Foundation

/// Service for managing circadian rhythm-based features
public actor CircadianService: CircadianServiceProtocol {
    private var currentPhase: CircadianPhase
    private var observers: [WeakObserver] = []

    public init() {
        currentPhase = CircadianPhase.current()
    }

    // MARK: - Public Methods

    /// Returns the current circadian phase based on time of day.
    public func getCurrentPhase() async -> CircadianPhase {
        currentPhase
    }

    /// Returns UI recommendations (brightness, blue filter, theme) for the current phase.
    public func getUIRecommendations() async -> UIRecommendations {
        let phase = currentPhase
        let theme: UIRecommendations.Theme = switch phase {
        case .earlyMorning, .morning, .midday, .afternoon:
            .light
        case .evening:
            .auto
        case .night, .lateNight, .deepNight:
            .dark
        }

        return UIRecommendations(
            brightness: phase.recommendedBrightness,
            blueFilterIntensity: phase.blueFilterIntensity,
            suggestedTheme: theme,
            phase: phase
        )
    }

    /// Recalculates the circadian phase and notifies observers if it changed.
    public func updatePhaseSettings() async {
        let newPhase = CircadianPhase.current()

        if newPhase != currentPhase {
            currentPhase = newPhase
            await notifyObservers(phase: newPhase)
        }
    }

    // MARK: - Observer Management

    /// Registers an observer for circadian phase change notifications.
    public func addObserver(_ observer: WellnessObserver) {
        observers.append(WeakObserver(observer))
        cleanupObservers()
    }

    /// Removes a previously registered observer.
    public func removeObserver(_ observer: WellnessObserver) {
        observers.removeAll { $0.value === observer }
    }

    private func cleanupObservers() {
        observers.removeAll { $0.value == nil }
    }

    private func notifyObservers(phase: CircadianPhase) async {
        cleanupObservers()
        for weakObserver in observers {
            weakObserver.value?.circadianPhaseDidChange(to: phase)
        }
    }

    // MARK: - Helper Types

    private struct WeakObserver {
        weak var value: WellnessObserver?

        init(_ value: WellnessObserver) {
            self.value = value
        }
    }
}
