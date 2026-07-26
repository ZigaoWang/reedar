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

    /// The expected lifespan for an active reed: its own model+strength if the
    /// player has retired any, otherwise the model pooled across strengths.
    static func expectation(for reed: Reed, among reeds: [Reed]) -> LifespanSummary? {
        let exact = byStrength(reeds).first { $0.key == reed.lifespanKey }
        if let exact, exact.sampleCount >= 2 { return exact }
        let model = byModel(reeds).first { $0.key == reed.lifespanKey.modelOnly }
        return exact ?? model
    }
}
