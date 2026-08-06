import Foundation

/// What the player was doing. Each context carries an honest guess at how much
/// of that time the reed was actually in the mouth — rehearsals are mostly
/// counting bars, practice is mostly playing. The estimate is always editable.
enum SessionContext: String, Codable, CaseIterable, Identifiable, Sendable {
    case practice
    case lesson
    case rehearsal
    case gig
    case session
    case audition

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .practice: "Practice"
        case .lesson: "Lesson"
        case .rehearsal: "Rehearsal"
        case .gig: "Gig"
        case .session: "Recording"
        case .audition: "Audition"
        }
    }

    var symbolName: String {
        switch self {
        case .practice: "metronome"
        case .lesson: "person.wave.2"
        case .rehearsal: "music.quarternote.3"
        case .gig: "music.mic"
        case .session: "waveform"
        case .audition: "checkmark.seal"
        }
    }

    /// Fraction of the session's clock time spent actually blowing.
    var defaultPlayingRatio: Double {
        switch self {
        case .practice: 0.85
        case .lesson: 0.55
        case .rehearsal: 0.45
        case .gig: 0.50
        case .session: 0.35
        case .audition: 0.70
        }
    }

    var ratioExplanation: String {
        switch self {
        case .practice: "Mostly playing"
        case .lesson: "About half playing"
        case .rehearsal: "Lots of waiting"
        case .gig: "Sets and breaks"
        case .session: "Lots of setup"
        case .audition: "Short, mostly playing"
        }
    }
}

/// Where a session came from. Manual today; a future metronome or practice
/// timer can write `.automatic` sessions without any model change.
enum SessionSource: String, Codable, CaseIterable, Sendable {
    case manual
    case automatic
    case imported

    var displayName: String {
        switch self {
        case .manual: "Logged by hand"
        case .automatic: "Tracked automatically"
        case .imported: "Imported"
        }
    }
}

/// Why a reed came out of rotation.
enum RetireReason: String, Codable, CaseIterable, Identifiable, Sendable {
    case wentFlat
    case chipped
    case warped
    case tooSoft
    case feltDone
    case lost

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wentFlat: "Went flat"
        case .chipped: "Chipped"
        case .warped: "Warped"
        case .tooSoft: "Blew out / too soft"
        case .feltDone: "Just felt done"
        case .lost: "Lost or damaged"
        }
    }

    var symbolName: String {
        switch self {
        case .wentFlat: "arrow.down.right"
        case .chipped: "bolt.trianglebadge.exclamationmark"
        case .warped: "wave.3.right"
        case .tooSoft: "wind"
        case .feltDone: "hand.thumbsdown"
        case .lost: "questionmark.circle"
        }
    }

    /// A reed that chipped or got lost didn't die of old age — its playing time
    /// is not a fair sample of that model's lifespan.
    var countsTowardLifespan: Bool {
        switch self {
        case .wentFlat, .tooSoft, .feltDone, .warped: true
        case .chipped, .lost: false
        }
    }
}
