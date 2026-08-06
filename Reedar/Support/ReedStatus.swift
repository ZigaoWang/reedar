import SwiftUI

/// What state a reed is in, as one answer, in words a player already uses.
///
/// There were eight of these, plus a set-aside flag, plus a star, plus a wear
/// bar, and between them they said the same few things four different ways.
/// Three states is what the case actually needs: play it, leave it today, or
/// it's had its life.
///
/// The order below is the order they override each other in. A reed that is
/// worn out is worn out whether or not it also played today.
enum ReedStatus {
    /// Good to pick up.
    case ready
    /// Played today. Cane needs a day to dry before it is worth playing again.
    case playedToday
    /// Past what this model usually gives you.
    case wornOut
    /// Done, and in the archive.
    case retired

    var label: String {
        switch self {
        case .ready: "Ready"
        case .playedToday: "Played today"
        case .wornOut: "Worn out"
        case .retired: "Retired"
        }
    }

    var tint: Color {
        switch self {
        case .ready: Palette.signalGreen
        case .playedToday: Palette.inkSecondary
        case .wornOut: Palette.signalAmber
        case .retired: Palette.inkTertiary
        }
    }

    var symbolName: String {
        switch self {
        case .ready: "checkmark.circle"
        case .playedToday: "clock"
        case .wornOut: "exclamationmark.triangle"
        case .retired: "archivebox"
        }
    }
}

extension Reed {
    /// The one status, worked out in the order the cases are written.
    func status(against expectation: LifespanSummary?) -> ReedStatus {
        if isRetired { return .retired }

        if let expectation, expectation.averageMinutes > 0,
           Double(playingMinutes) >= expectation.averageMinutes {
            return .wornOut
        }
        // A day is the shortest honest answer to "can I play this again", so
        // today is the only resting day.
        if daysRested == 0 { return .playedToday }
        return .ready
    }

    /// One plain sentence saying what to do about it.
    func statusDetail(against expectation: LifespanSummary?) -> String {
        switch status(against: expectation) {
        case .ready:
            guard sessionCount > 0 else { return "Not played yet. Good to go." }
            return "\(restLabel). Good to play."
        case .playedToday:
            return "You played it today. Give it a day to dry before playing it again."
        case .wornOut:
            guard let expectation else { return "Past what you usually get from this one." }
            return "It has passed the \(Format.duration(minutes: expectation.averageMinutes)) your \(modelDisplayName) reeds usually give you. Retire it when it stops feeling right."
        case .retired:
            guard let date = retiredAt else { return "In the archive." }
            return "Retired on \(Format.mediumDate(date))."
        }
    }
}
