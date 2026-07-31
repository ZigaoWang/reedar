import SwiftData
import SwiftUI

/// Every reed the player has finished with — the raw material behind the data.
struct ArchiveView: View {
    @Query(sort: \Reed.retiredAt, order: .reverse) private var reeds: [Reed]

    private var retired: [Reed] { reeds.filter(\.isRetired) }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Metrics.stack) {
                ForEach(Array(retired.enumerated()), id: \.element.id) { index, reed in
                    NavigationLink(value: reed) {
                        ArchiveRow(reed: reed, index: retired.count - index)
                    }
                    .buttonStyle(.sink)
                }
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.top, 4)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background { Backdrop() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Archive")
                    .font(.heading(12, weight: .bold))
                    .foregroundStyle(Palette.ink)
            }
        }
    }
}

struct ArchiveRow: View {
    var reed: Reed
    var index: Int

    var body: some View {
        HStack(spacing: 14) {
            ReedView(
                axis: .vertical,
                wear: 1,
                stamp: "",
                strengthStamp: "",
                isRetired: true
            )
            .frame(width: 22, height: 68)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .milled(radius: 4)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(indexLabel(index))
                        .font(.numeric(10, weight: .medium))
                        .foregroundStyle(Palette.inkTertiary)
                    Text(reed.fullName)
                        .font(.heading(13, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                }
                Text("\(reed.instrument.shortName) · retired \(Format.mediumDate(reed.retiredAt ?? Date()))")
                    .font(.copy(11))
                    .foregroundStyle(Palette.inkTertiary)
                if let reason = reed.retireReason {
                    Tag(text: reason.displayName,
                        symbol: reason.symbolName,
                        tint: reason.countsTowardLifespan ? Palette.inkSecondary : Palette.signalAmber)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 1) {
                Text(Format.hours(minutes: reed.playingMinutes))
                    .font(.numeric(19, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text("Hours").microLabel(Palette.inkTertiary)
            }
        }
        .padding(12)
        .raised(depth: .low)
    }
}
