import SwiftData
import SwiftUI

/// Retiring a reed is the moment its lifespan becomes data. Short: why it died,
/// when, done.
struct RetireReedView: View {
    var reed: Reed
    var onRetired: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Query private var allReeds: [Reed]

    @State private var reason: RetireReason = .wentFlat
    @State private var retiredAt = Date()
    @State private var note = ""

    private var comparison: LifespanSummary? {
        LifespanStats.expectation(for: reed, among: allReeds)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Metrics.stack) {
                    summary
                    reasonPanel
                    detailsPanel
                    PrimaryKey(title: "Retire reed", symbol: "archivebox") { retire() }
                        .padding(.top, 2)
                }
                .padding(.horizontal, Metrics.screenMargin)
                .column()
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .background { Backdrop() }
            .navigationTitle("Retire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.heading(12, weight: .medium))
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var summary: some View {
        Panel(padding: 14) {
            HStack(alignment: .top, spacing: 14) {
                ReedView(axis: .vertical, wear: 1,
                         stamp: reed.brandName,
                         strengthStamp: reed.strengthLabel)
                    .frame(width: 40, height: 120)
                    .padding(8)
                    .milled(radius: Metrics.radiusSlot)

                VStack(alignment: .leading, spacing: 10) {
                    Text(reed.fullName)
                        .font(.heading(14, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Display(value: Format.hours(minutes: reed.playingMinutes), unit: "h",
                            label: "Total playing time", size: 26)
                    if let comparison, comparison.sampleCount > 0 {
                        Text(verdict(against: comparison))
                            .font(.copy(11.5))
                            .foregroundStyle(Palette.accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var reasonPanel: some View {
        Panel(padding: 14) {
            VStack(alignment: .leading, spacing: 11) {
                RuleHeader("Why")
                KeySelector(
                    values: RetireReason.allCases,
                    selection: $reason,
                    title: { $0.displayName },
                    symbol: { $0.symbolName },
                    columns: 3
                )
                Text(reason.countsTowardLifespan
                     ? "Counts toward your \(reed.modelDisplayName) average."
                     : "Chipped or lost reeds don't count.")
                    .font(.copy(11.5))
                    .foregroundStyle(Palette.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var detailsPanel: some View {
        Panel(padding: 14) {
            VStack(alignment: .leading, spacing: 11) {
                RuleHeader("When")
                DatePicker("", selection: $retiredAt, in: ...Date(), displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(Palette.accent)
                Well(padding: 10) {
                    TextField("Note (optional)", text: $note, axis: .vertical)
                        .font(.copy(13))
                        .tint(Palette.accent)
                        .lineLimit(1...3)
                }
            }
        }
    }

    private func verdict(against summary: LifespanSummary) -> String {
        let delta = Double(reed.playingMinutes) - summary.averageMinutes
        let average = Format.duration(minutes: summary.averageMinutes)
        if abs(delta) < 30 {
            return "Same as your \(average) average."
        }
        return delta > 0
            ? "\(Format.duration(minutes: delta)) more than your \(average) average."
            : "\(Format.duration(minutes: -delta)) less than your \(average) average."
    }

    private func retire() {
        reed.retiredAt = retiredAt
        reed.retireReasonRaw = reason.rawValue
        reed.retireNote = note.trimmed
        Haptics.reedRetired()
        dismiss()
        onRetired()
    }
}
