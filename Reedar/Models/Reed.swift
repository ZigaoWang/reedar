import Foundation
import SwiftData

/// A single physical reed the player owns.
///
/// Catalog identity is denormalised onto the reed (brand/model/strength names
/// stored as text alongside their catalog IDs). A reed retired in 2026 should
/// still read correctly in 2030 after the catalog has been edited, and a custom
/// reed that isn't in the catalog is the same shape as one that is.
///
/// Every property has a default and every relationship is optional so the whole
/// store stays CloudKit-compatible.
@Model
final class Reed {
    var id: UUID = UUID()

    // Identity
    var brandID: String = ""
    var brandName: String = ""
    var modelID: String = ""
    var modelName: String = ""
    var strengthLabel: String = ""
    var strengthValue: Double = 0
    var scaleRaw: String = StrengthScale.halfStep.rawValue
    var isCustom: Bool = false
    var isSynthetic: Bool = false
    var instrumentRaw: String = Instrument.altoSax.rawValue

    /// Optional label for players who rotate several identical reeds — "#2",
    /// "the good one", "left of the case".
    var nickname: String = ""
    var notes: String = ""

    // Lifecycle
    var addedAt: Date = Date()
    /// Which slot in the case this reed sits in. Positions are the player's
    /// own arrangement, so they survive across launches and sync.
    var slotIndex: Int = 0
    var retiredAt: Date?
    var retireReasonRaw: String?
    var retireNote: String = ""

    @Relationship(deleteRule: .cascade, inverse: \PlaySession.reed)
    var sessions: [PlaySession]? = []

    init(
        brandID: String,
        brandName: String,
        modelID: String,
        modelName: String,
        strength: Strength,
        instrument: Instrument,
        isCustom: Bool = false,
        isSynthetic: Bool = false,
        nickname: String = "",
        notes: String = "",
        addedAt: Date = Date(),
        slotIndex: Int = 0
    ) {
        self.id = UUID()
        self.brandID = brandID
        self.brandName = brandName
        self.modelID = modelID
        self.modelName = modelName
        self.strengthLabel = strength.label
        self.strengthValue = strength.value
        self.scaleRaw = strength.scale.rawValue
        self.isCustom = isCustom
        self.isSynthetic = isSynthetic
        self.instrumentRaw = instrument.rawValue
        self.nickname = nickname
        self.notes = notes
        self.addedAt = addedAt
        self.slotIndex = slotIndex
        self.sessions = []
    }
}

// MARK: - Derived values

extension Reed {
    var instrument: Instrument {
        Instrument(rawValue: instrumentRaw) ?? .altoSax
    }

    var scale: StrengthScale {
        StrengthScale(rawValue: scaleRaw) ?? .halfStep
    }

    var retireReason: RetireReason? {
        retireReasonRaw.flatMap(RetireReason.init(rawValue:))
    }

    var isRetired: Bool { retiredAt != nil }

    var orderedSessions: [PlaySession] {
        (sessions ?? []).sorted { $0.date > $1.date }
    }

    var sessionCount: Int { sessions?.count ?? 0 }

    /// Real playing time, in minutes — the number the whole app is built around.
    var playingMinutes: Int {
        (sessions ?? []).reduce(0) { $0 + $1.playingMinutes }
    }

    var playingHours: Double { Double(playingMinutes) / 60 }

    /// Clock time the reed was out of the case, playing or not.
    var totalMinutes: Int {
        (sessions ?? []).reduce(0) { $0 + $1.totalMinutes }
    }

    var firstPlayedAt: Date? {
        (sessions ?? []).map(\.date).min()
    }

    var lastPlayedAt: Date? {
        (sessions ?? []).map(\.date).max()
    }

    /// Days between the first session and retirement (or now).
    var daysInRotation: Int {
        let start = firstPlayedAt ?? addedAt
        let end = retiredAt ?? Date()
        return max(0, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0)
    }

    /// "Vandoren Java Red" — brand and model, no strength.
    var modelDisplayName: String {
        "\(brandName) \(modelName)".trimmingCharacters(in: .whitespaces)
    }

    /// "Vandoren Java Red 2½" — the full name of the reed.
    var fullName: String {
        "\(modelDisplayName) \(strengthLabel)".trimmingCharacters(in: .whitespaces)
    }

    /// What the card shows: the nickname if there is one, else the full name.
    var displayTitle: String {
        nickname.isEmpty ? fullName : nickname
    }

    /// Short enough to fit beside a reed in its slot: the nickname, or the
    /// model on its own — the brand is already printed on the reed.
    var slotTitle: String {
        nickname.isEmpty ? modelName : nickname
    }

    var displaySubtitle: String {
        nickname.isEmpty ? instrument.shortName : "\(fullName) · \(instrument.shortName)"
    }

    /// Groups reeds of the same model and strength for stats.
    var lifespanKey: LifespanKey {
        LifespanKey(
            brandID: brandID.isEmpty ? brandName.lowercased() : brandID,
            modelID: modelID.isEmpty ? modelName.lowercased() : modelID,
            strengthLabel: strengthLabel,
            brandName: brandName,
            modelName: modelName
        )
    }
}

/// Identity used to aggregate lifespans. Strength is part of the key; the stats
/// screen also rolls these up per model by ignoring `strengthLabel`.
struct LifespanKey: Hashable, Sendable {
    var brandID: String
    var modelID: String
    var strengthLabel: String
    var brandName: String
    var modelName: String

    var modelDisplayName: String { "\(brandName) \(modelName)" }
    var fullDisplayName: String { "\(brandName) \(modelName) \(strengthLabel)" }

    /// The same key with strength dropped, for per-model roll-ups.
    var modelOnly: LifespanKey {
        LifespanKey(brandID: brandID, modelID: modelID, strengthLabel: "",
                    brandName: brandName, modelName: modelName)
    }
}
