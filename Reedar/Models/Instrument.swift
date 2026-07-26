import Foundation

/// The instrument a reed is cut for.
///
/// V1 only surfaces saxophones, but the instrument is stored on every reed and
/// every catalog entry from day one. Adding clarinet means flipping
/// `isAvailable` and adding catalog entries — no migration, no rewrite.
enum Instrument: String, Codable, CaseIterable, Identifiable, Sendable {
    case sopranoSax
    case altoSax
    case tenorSax
    case bariSax
    case bassSax
    case bbClarinet
    case bassClarinet
    case ebClarinet

    var id: String { rawValue }

    var family: InstrumentFamily {
        switch self {
        case .sopranoSax, .altoSax, .tenorSax, .bariSax, .bassSax: .saxophone
        case .bbClarinet, .bassClarinet, .ebClarinet: .clarinet
        }
    }

    /// Full name, used in pickers and detail views.
    var displayName: String {
        switch self {
        case .sopranoSax: "Soprano Sax"
        case .altoSax: "Alto Sax"
        case .tenorSax: "Tenor Sax"
        case .bariSax: "Baritone Sax"
        case .bassSax: "Bass Sax"
        case .bbClarinet: "B♭ Clarinet"
        case .bassClarinet: "Bass Clarinet"
        case .ebClarinet: "E♭ Clarinet"
        }
    }

    /// Compact name for cards and chips.
    var shortName: String {
        switch self {
        case .sopranoSax: "Soprano"
        case .altoSax: "Alto"
        case .tenorSax: "Tenor"
        case .bariSax: "Bari"
        case .bassSax: "Bass Sax"
        case .bbClarinet: "B♭ Clarinet"
        case .bassClarinet: "Bass Cl."
        case .ebClarinet: "E♭ Clarinet"
        }
    }

    /// Instruments offered in the UI. Widening this is the only change needed
    /// to ship clarinet support once the catalog carries clarinet reeds.
    static var selectable: [Instrument] {
        allCases.filter { $0.family == .saxophone && $0 != .bassSax }
    }
}

enum InstrumentFamily: String, Codable, CaseIterable, Sendable {
    case saxophone
    case clarinet

    var displayName: String {
        switch self {
        case .saxophone: "Saxophone"
        case .clarinet: "Clarinet"
        }
    }
}
