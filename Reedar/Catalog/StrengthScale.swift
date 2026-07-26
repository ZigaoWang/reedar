import Foundation

/// Brands number their strengths differently — a Vandoren 2.5 is not a
/// D'Addario 2M is not a Rigotti 2½ Medium. Each catalog model declares the
/// scale it uses so the app can show the right list and still sort sensibly.
enum StrengthScale: String, Codable, CaseIterable, Sendable {
    /// 2, 2½, 3, 3½, 4 … — Vandoren, Rico, Marca, Gonzalez, Hemke, most cane.
    case halfStep
    /// 2S, 2M, 2H, 3S, 3M, 3H … — D'Addario Select Jazz.
    case daddarioJazz
    /// 2.00, 2.25, 2.50 … — Légère synthetics, quarter steps.
    case quarterStep
    /// 2 Light / 2 Medium / 2 Strong … — Rigotti Gold.
    case rigottiGold
    /// Soft / Medium Soft / Medium / Medium Hard / Hard — Fibracell, Alexander.
    case softToHard

    var displayName: String {
        switch self {
        case .halfStep: "Half steps (2, 2½, 3…)"
        case .daddarioJazz: "Select Jazz (2S, 2M, 2H…)"
        case .quarterStep: "Quarter steps (2.25, 2.5…)"
        case .rigottiGold: "Rigotti (2 Light, 2 Medium…)"
        case .softToHard: "Soft to Hard"
        }
    }

    /// Compact name for hardware labels.
    var shortName: String {
        switch self {
        case .halfStep: "half steps"
        case .daddarioJazz: "s / m / h"
        case .quarterStep: "quarter steps"
        case .rigottiGold: "light / med / strong"
        case .softToHard: "soft to hard"
        }
    }

    /// The strengths offered for this scale, in ascending order.
    var strengths: [Strength] {
        switch self {
        case .halfStep:
            return stride(from: 1.5, through: 5.0, by: 0.5).map {
                Strength(label: Self.fractionLabel($0), value: $0, scale: self)
            }
        case .quarterStep:
            return stride(from: 1.75, through: 4.5, by: 0.25).map {
                Strength(label: String(format: "%.2f", $0), value: $0, scale: self)
            }
        case .daddarioJazz:
            return (2...4).flatMap { base in
                [("S", 0.0), ("M", 0.25), ("H", 0.5)].map { suffix, offset in
                    Strength(label: "\(base)\(suffix)",
                             value: Double(base) + offset,
                             scale: self)
                }
            }
        case .rigottiGold:
            return stride(from: 2.0, through: 4.0, by: 1.0).flatMap { base in
                [("Light", 0.0), ("Medium", 0.33), ("Strong", 0.66)].map { name, offset in
                    Strength(label: "\(Self.fractionLabel(base)) \(name)",
                             value: base + offset,
                             scale: self)
                }
            }
        case .softToHard:
            return [
                ("Soft", 2.0), ("Medium Soft", 2.5), ("Medium", 3.0),
                ("Medium Hard", 3.5), ("Hard", 4.0),
            ].map { Strength(label: $0.0, value: $0.1, scale: self) }
        }
    }

    /// A reasonable default selection so the picker doesn't open on the extreme.
    var defaultStrength: Strength {
        let all = strengths
        return all.first { abs($0.value - 2.5) < 0.2 } ?? all[all.count / 2]
    }

    private static func fractionLabel(_ value: Double) -> String {
        let whole = Int(value)
        return value == Double(whole) ? "\(whole)" : "\(whole)½"
    }
}

/// One selectable strength within a scale. `value` exists purely so strengths
/// sort and group consistently across scales; it is never shown to the player.
struct Strength: Hashable, Identifiable, Sendable {
    var label: String
    var value: Double
    var scale: StrengthScale

    var id: String { "\(scale.rawValue)-\(label)" }
}
