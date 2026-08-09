import SwiftData
import SwiftUI

/// Every reed the player has finished with — the raw material behind the data.
struct ArchiveView: View {
    @Environment(Tour.self) private var tour: Tour?
    @Query(sort: \Reed.retiredAt, order: .reverse) private var reeds: [Reed]

    private var retired: [Reed] { reeds.filter(\.isRetired) }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Metrics.stack) {
                ForEach(Array(retired.enumerated()), id: \.element.id) { index, reed in
                    NavigationLink(value: reed) {
                        ArchiveRow(reed: reed,
                                   index: retired.count - index,
                                   estimate: LifespanStats.estimate(for: reed, among: reeds))
                    }
                    .buttonStyle(.sink)
                }
            }
            .padding(.horizontal, Metrics.screenMargin)
            .column()
            .padding(.top, 4)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background { Backdrop() }
        .onAppear { tour?.completed(.archive) }
        // The system's title, at the system's size, like every other screen.
        // This was a hand-rolled principal item at 12pt bold, which came out
        // noticeably smaller than Lifespan's next door — two conventions for
        // one thing, and no reason for either.
        .navigationTitle("Archive")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

/// One retired reed: the reed itself, then what finished it.
///
/// The reed is drawn exactly as the case draws it — same `ReedRow`, same
/// `SlotMoulding`, same proportions. It used to be a 22×68 sliver standing on
/// end in a rounded rectangle, which is a fourth way of drawing the one object
/// this whole app is about. A reed is the same reed wherever it's shown; only
/// what's said about it changes.
struct ArchiveRow: View {
    var reed: Reed
    var index: Int
    var estimate: LifespanEstimate

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            SlotMoulding {
                ReedRow(reed: reed, estimate: estimate)
            }
            .aspectRatio(Metrics.reedLyingAspect, contentMode: .fit)
            .frame(maxWidth: .infinity)

            HStack(alignment: .center, spacing: 8) {
                Text(indexLabel(index))
                    .font(.numeric(10, weight: .medium))
                    .foregroundStyle(Palette.inkTertiary)

                Text("Retired \(Format.mediumDate(reed.retiredAt ?? Date()))")
                    .font(.copy(11))
                    .foregroundStyle(Palette.inkTertiary)
                    .lineLimit(1)

                if let reason = reed.retireReason {
                    Tag(text: reason.displayName,
                        symbol: reason.symbolName,
                        tint: reason.countsTowardLifespan ? Palette.inkSecondary : Palette.signalAmber)
                }

                Spacer(minLength: 4)

                // The one number the reed can't print on itself: what it gave
                // you in total, which is the whole reason the archive exists.
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(Format.hours(minutes: reed.playingMinutes))
                        .font(.numeric(17, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text("h")
                        .font(.numeric(11, weight: .medium))
                        .foregroundStyle(Palette.inkTertiary)
                }
            }
        }
        .padding(12)
        .raised(depth: .low)
    }
}
