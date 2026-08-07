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

    private func play(_ events: [CHHapticEvent],
                      curves: [CHHapticParameterCurve] = []) {
        guard let engine else { return }
        do {
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
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

    /// The mark arriving at launch. Four things happen, in this order, and it
    /// only works because they are one continuous gesture rather than four
    /// cues in a row:
    ///
    /// - a swell from below the threshold of feeling, so it arrives rather
    ///   than starts
    /// - a run of ticks over the top of it, the gaps closing each time, like a
    ///   mechanism spinning up and finding its seat
    /// - the landing, on the frame the mark settles
    /// - a short warm tail under it, the way a heavy thing set down carries on
    ///   for a moment after it stops
    ///
    /// `landing` is the anchor — the moment the mark comes to rest on screen.
    /// Everything else is placed against it, so the caller can hand over the
    /// one number that keeps the gesture in step with the animation.
    static func launched(landing: TimeInterval = 0.44) {
        guard shared.engine != nil else {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred(intensity: 0.9)
            return
        }

        let swell = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 0.75),
                .init(parameterID: .hapticSharpness, value: 0.1),
            ],
            relativeTime: 0,
            duration: landing
        )

        // The tail is what sells the weight. Without it the landing is a
        // click; with it, something with mass has come to rest.
        let tail = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 0.6),
                .init(parameterID: .hapticSharpness, value: 0.05),
            ],
            relativeTime: landing + 0.015,
            duration: 0.24
        )

        // Closing gaps, as fractions of the run up to the landing, so the
        // whole spin-up stretches with it. Evenly spaced reads as a buzz.
        let ticks = [0.23, 0.42, 0.58, 0.71, 0.80, 0.87].enumerated().map { index, fraction in
            let ramp = Double(index) / 5
            return shared.transient(landing * fraction,
                                    intensity: Float(0.35 + ramp * 0.25),
                                    sharpness: Float(0.5 + ramp * 0.2))
        }

        // One curve per parameter, spanning the whole pattern — it scales the
        // ticks along with the swell, which is what makes them emerge out of
        // it instead of sitting on top.
        let intensity = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0, value: 0.03),
                .init(relativeTime: landing * 0.35, value: 0.22),
                .init(relativeTime: landing * 0.7, value: 0.55),
                .init(relativeTime: landing - 0.02, value: 0.95),
                .init(relativeTime: landing + 0.02, value: 1.0),
                .init(relativeTime: landing + 0.06, value: 0.55),
                .init(relativeTime: landing + 0.26, value: 0),
            ],
            relativeTime: 0
        )
        // Dull all the way up, crisp at the seat, dull again as it decays.
        let sharpness = CHHapticParameterCurve(
            parameterID: .hapticSharpnessControl,
            controlPoints: [
                .init(relativeTime: 0, value: -0.6),
                .init(relativeTime: landing * 0.75, value: -0.2),
                .init(relativeTime: landing, value: 0.25),
                .init(relativeTime: landing + 0.26, value: -0.4),
            ],
            relativeTime: 0
        )

        shared.play(
            [swell] + ticks + [shared.transient(landing, intensity: 1, sharpness: 0.5), tail],
            curves: [intensity, sharpness]
        )
    }

    /// A reed being lifted out of the case.
    static func reedLifted() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
    }

    /// A fingertip landing on the bare floor of an empty bay. Harder and
    /// lighter than a reed, because there is no cane in the way — the only tap
    /// in the case that used to return nothing at all.
    static func slotTapped() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.55)
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
