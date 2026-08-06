import Foundation

/// The lifespan of one model+strength combination, computed from retired reeds.
struct LifespanSummary: Identifiable, Sendable {
    var key: LifespanKey
    /// Reeds that died of wear and count toward the average.
    var sampleCount: Int
    /// Reeds excluded because they chipped or were lost.
    var excludedCount: Int
    var averageMinutes: Double
    var shortestMinutes: Int
    var longestMinutes: Int
    var averageSessions: Double
    var averageDays: Double
    /// The most common way this reed dies.
    var commonReason: RetireReason?

    var id: String { "\(key.brandID)-\(key.modelID)-\(key.strengthLabel)" }

    var averageHours: Double { averageMinutes / 60 }

    /// Below three retired reeds an average is a rumour, not a statistic — the
    /// UI still shows it, but labelled as early days.
    var isConfident: Bool { sampleCount >= 3 }

    var spreadMinutes: Int { max(0, longestMinutes - shortestMinutes) }
}

enum LifespanStats {
    /// Group retired reeds by model **and** strength.
    static func byStrength(_ reeds: [Reed]) -> [LifespanSummary] {
        summarize(reeds, keyPath: { $0.lifespanKey })
    }

    /// Group retired reeds by model, pooling all strengths.
    static func byModel(_ reeds: [Reed]) -> [LifespanSummary] {
        summarize(reeds, keyPath: { $0.lifespanKey.modelOnly })
    }

    private static func summarize(
        _ reeds: [Reed],
        keyPath: (Reed) -> LifespanKey
    ) -> [LifespanSummary] {
        let retired = reeds.filter(\.isRetired)
        let groups = Dictionary(grouping: retired, by: keyPath)

        return groups.compactMap { key, group -> LifespanSummary? in
            // A chipped reed says nothing about how long the model lasts.
            let counted = group.filter { $0.retireReason?.countsTowardLifespan ?? true }
            guard !counted.isEmpty else { return nil }

            let minutes = counted.map(\.playingMinutes)
            let reasons = counted.compactMap(\.retireReason)
            let commonReason = Dictionary(grouping: reasons, by: { $0 })
                .max { $0.value.count < $1.value.count }?.key

            return LifespanSummary(
                key: key,
                sampleCount: counted.count,
                excludedCount: group.count - counted.count,
                averageMinutes: Double(minutes.reduce(0, +)) / Double(counted.count),
                shortestMinutes: minutes.min() ?? 0,
                longestMinutes: minutes.max() ?? 0,
                averageSessions: Double(counted.reduce(0) { $0 + $1.sessionCount }) / Double(counted.count),
                averageDays: Double(counted.reduce(0) { $0 + $1.daysInRotation }) / Double(counted.count),
                commonReason: commonReason
            )
        }
        .sorted { $0.averageMinutes > $1.averageMinutes }
    }

    /// A rough figure for a cane sax reed: a couple of weeks of daily playing.
    /// Only used until the player has retired anything of their own, and always
    /// labelled as not theirs.
    static let typicalMinutes: Double = 12 * 60

    /// What this reed is expected to last, always.
    ///
    /// It used to need a retired reed of the same model, which never arrives if
    /// you only ever buy one of something. So it falls back: the same model and
    /// strength, then the model at any strength, then everything you have
    /// retired, then a typical reed. Every answer carries where it came from, so
    /// the app can say so instead of quietly presenting a guess as a measurement.
    static func estimate(for reed: Reed, among reeds: [Reed]) -> LifespanEstimate {
        if let exact = byStrength(reeds).first(where: { $0.key == reed.lifespanKey }),
           exact.sampleCount >= 2 {
            return LifespanEstimate(minutes: exact.averageMinutes,
                                    sampleCount: exact.sampleCount,
                                    source: "your \(reed.fullName) reeds")
        }
        if let model = byModel(reeds).first(where: { $0.key == reed.lifespanKey.modelOnly }) {
            return LifespanEstimate(minutes: model.averageMinutes,
                                    sampleCount: model.sampleCount,
                                    source: "your \(reed.modelDisplayName) reeds")
        }

        let counted = reeds.filter(\.isRetired)
            .filter { $0.retireReason?.countsTowardLifespan ?? true }
        if !counted.isEmpty {
            let average = Double(counted.reduce(0) { $0 + $1.playingMinutes }) / Double(counted.count)
            return LifespanEstimate(minutes: average,
                                    sampleCount: counted.count,
                                    source: "your reeds so far")
        }

        return LifespanEstimate(minutes: typicalMinutes, sampleCount: 0, source: "a typical reed")
    }

    /// The matching summary, where the richer figures are wanted. Nil until the
    /// player has retired something of that model.
    static func expectation(for reed: Reed, among reeds: [Reed]) -> LifespanSummary? {
        let exact = byStrength(reeds).first { $0.key == reed.lifespanKey }
        if let exact, exact.sampleCount >= 2 { return exact }
        let model = byModel(reeds).first { $0.key == reed.lifespanKey.modelOnly }
        return exact ?? model
    }
}

/// How long a reed is expected to last, and what that is based on.
struct LifespanEstimate {
    var minutes: Double
    /// How many of the player's own retired reeds are behind it. Zero means the
    /// standard figure, which is nobody's reed in particular.
    var sampleCount: Int
    /// Said the way it reads in a sentence: "your Vandoren Java reeds".
    var source: String

    var isPersonal: Bool { sampleCount > 0 }
    /// Under three reeds an average is a rumour, not a statistic.
    var isConfident: Bool { sampleCount >= 3 }
}
