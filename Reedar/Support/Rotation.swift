import Foundation

/// Which reed to play next.
///
/// Rotating matters because a reed that has dried out fully between sessions
/// lasts longer than one played two days running. But preference beats
/// arithmetic: if you favour a reed, you want to be told to play that one, and
/// a reed you've set aside should never come up at all.
enum Rotation {
    static func nextUp(among reeds: [Reed]) -> Reed? {
        let candidates = reeds.filter(\.isInRotation)
        guard candidates.count > 1 else { return nil }

        // Only reeds that have actually had a rest are worth suggesting;
        // never-played counts as fully rested.
        let rested = candidates.filter { ($0.daysRested ?? Int.max) >= 1 }
        guard !rested.isEmpty else { return nil }

        // A favourite wins, as long as it has rested too.
        let favourites = rested.filter(\.isFavourite)
        let pool = favourites.isEmpty ? rested : favourites

        return pool.min { lhs, rhs in
            (lhs.daysRested ?? Int.max, lhs.addedAt) > (rhs.daysRested ?? Int.max, rhs.addedAt)
        }
    }
}
