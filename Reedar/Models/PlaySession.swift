import Foundation
import SwiftData

/// One time the reed was played.
///
/// `totalMinutes` is clock time, `playingMinutes` is the part that actually wore
/// the reed. Sessions carry a `source` so a future metronome or practice timer
/// can create them without anyone filling in a form.
@Model
final class PlaySession {
    var id: UUID = UUID()
    var date: Date = Date()
    var totalMinutes: Int = 0
    var playingMinutes: Int = 0
    var contextRaw: String = SessionContext.practice.rawValue
    var sourceRaw: String = SessionSource.manual.rawValue
    var note: String = ""
    var createdAt: Date = Date()

    var reed: Reed?

    init(
        date: Date = Date(),
        totalMinutes: Int,
        playingMinutes: Int,
        context: SessionContext = .practice,
        source: SessionSource = .manual,
        note: String = "",
        reed: Reed? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.totalMinutes = totalMinutes
        self.playingMinutes = playingMinutes
        self.contextRaw = context.rawValue
        self.sourceRaw = source.rawValue
        self.note = note
        self.createdAt = Date()
        self.reed = reed
    }
}

extension PlaySession {
    var context: SessionContext {
        SessionContext(rawValue: contextRaw) ?? .practice
    }

    var source: SessionSource {
        SessionSource(rawValue: sourceRaw) ?? .manual
    }

    var playingRatio: Double {
        totalMinutes > 0 ? Double(playingMinutes) / Double(totalMinutes) : 0
    }

    var restingMinutes: Int { max(0, totalMinutes - playingMinutes) }
}
