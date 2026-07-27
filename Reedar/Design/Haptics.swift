import CoreHaptics
import UIKit

/// Haptics with weight to them. The two moments that matter get custom
/// patterns through CoreHaptics — logging a session lands like a switch
/// closing, retiring a reed like a case lid shutting — and everything else
/// falls back to the standard generators.
@MainActor
final class Haptics {
    static let shared = Haptics()

    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    private init() {
        prepareEngine()
    }

    private func prepareEngine() {
        guard supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            // The system stops the engine when the app backgrounds; bring it
            // straight back rather than going silent for the rest of the session.
            engine.stoppedHandler = { [weak self] _ in
                Task { @MainActor in try? self?.engine?.start() }
            }
            engine.resetHandler = { [weak self] in
                Task { @MainActor in try? self?.engine?.start() }
            }
            try engine.start()
            self.engine = engine
        } catch {
            engine = nil
        }
    }

    private func play(_ events: [CHHapticEvent]) {
        guard let engine else { return }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func transient(_ time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: intensity),
                .init(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time
        )
    }

    // MARK: Moments

    /// A session lands on a reed: a firm click with a short tail, like a
    /// toggle switch throwing.
    static func sessionLogged() {
        guard shared.engine != nil else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }
        shared.play([
            shared.transient(0, intensity: 0.75, sharpness: 0.85),
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.45),
                    .init(parameterID: .hapticSharpness, value: 0.3),
                ],
                relativeTime: 0.045,
                duration: 0.12
            ),
        ])
    }

    /// A reed comes out of rotation: two soft thuds, a lid closing.
    static func reedRetired() {
        guard shared.engine != nil else {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.9)
            return
        }
        shared.play([
            shared.transient(0, intensity: 0.9, sharpness: 0.25),
            shared.transient(0.09, intensity: 0.55, sharpness: 0.15),
        ])
    }

    /// A new reed drops into a slot.
    static func reedAdded() {
        guard shared.engine != nil else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return
        }
        shared.play([
            shared.transient(0, intensity: 0.5, sharpness: 0.6),
            shared.transient(0.055, intensity: 0.8, sharpness: 0.45),
        ])
    }

    /// A reed being lifted out of the case.
    static func reedLifted() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
    }

    static func tick() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// Called at launch so the first haptic isn't the one that warms the engine.
    static func warmUp() {
        _ = shared
    }
}
