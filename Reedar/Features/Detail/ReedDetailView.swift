import SwiftData
import SwiftUI

/// The reed out of the case: the unit itself, its numbers, and its log.
struct ReedDetailView: View {
    @Bindable var reed: Reed

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allReeds: [Reed]

    @State private var isLogging = false
    @State private var isRetiring = false
    @State private var editingSession: PlaySession?
    @State private var confirmingDelete = false

    private var expectation: LifespanSummary? {
        LifespanStats.expectation(for: reed, among: allReeds)
    }

    private var wear: Double {
        guard let expectation, expectation.averageMinutes > 0 else { return 0 }
        return Double(reed.playingMinutes) / expectation.averageMinutes
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Metrics.stack) {
                header
                if let expectation { lifeSection(expectation) }
                if !reed.isRetired { controls }
                if reed.isRetired { retiredNote }
                if !reed.notes.isEmpty { notes }
                history
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background { Backdrop() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(reed.displayTitle)
                    .font(.heading(12, weight: .bold))
                    .foregroundStyle(Palette.ink)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if reed.isRetired {
                        Button {
                            unretire()
                        } label: {
                            Label("Put Back in Rotation", systemImage: "arrow.uturn.backward")
                        }
                    }
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete Reed", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Palette.ink)
                }
            }
        }
        .sheet(isPresented: $isLogging) { LogSessionView(reed: reed) }
        .sheet(isPresented: $isRetiring) { RetireReedView(reed: reed) { dismiss() } }
        .sheet(item: $editingSession) { LogSessionView(reed: reed, editing: $0) }
        .confirmationDialog(
            "Delete this reed and its \(Format.count(reed.sessionCount, "session"))?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                context.delete(reed)
                dismiss()
            }
        } message: {
            Text("Retiring keeps its history in your lifespan data. Deleting removes it for good.")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            ReedView(
                axis: .vertical,
                wear: wear,
                stamp: reed.brandName,
                strengthStamp: reed.strengthLabel,
                isRetired: reed.isRetired
            )
            .frame(width: 54, height: 164)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .milled(radius: Metrics.radiusSlot)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(reed.modelDisplayName)
                        .font(.heading(15, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text("\(reed.strengthLabel) · \(reed.instrument.displayName)")
                        .font(.copy(12))
                        .foregroundStyle(Palette.inkSecondary)
                }

                Display(value: Format.hours(minutes: reed.playingMinutes), unit: "h",
                        label: "Playing time", size: 30,
                        tint: reed.isRetired ? Palette.ink : Palette.accent)

                HStack(spacing: 8) {
                    miniStat("\(reed.sessionCount)", "Sessions")
                    Rectangle().fill(Palette.hairline).frame(width: 1, height: 22)
                    miniStat("\(reed.daysInRotation)", "Days")
                }
            }
        }
        .padding(14)
        .raised(depth: .medium)
    }

    private func miniStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.numeric(15, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Text(label).microLabel(Palette.inkTertiary)
        }
    }

    // MARK: Life

    private func lifeSection(_ expectation: LifespanSummary) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 11) {
                RuleHeader("Life", trailing: "\(Format.hours(minutes: expectation.averageMinutes))h avg")
                LEDBar(progress: wear, segments: 18, height: 9)
                Text(lifeText(expectation))
                    .font(.copy(12))
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func lifeText(_ expectation: LifespanSummary) -> String {
        let basis = expectation.key.strengthLabel.isEmpty
            ? expectation.key.modelDisplayName
            : expectation.key.fullDisplayName
        let sample = "\(Format.count(expectation.sampleCount, "retired reed"))"
        if wear >= 1 {
            return "Past the \(Format.duration(minutes: expectation.averageMinutes)) your \(basis) reeds usually last, from \(sample). Worth checking how it still feels."
        }
        let left = expectation.averageMinutes - Double(reed.playingMinutes)
        return "Your \(basis) reeds last about \(Format.duration(minutes: expectation.averageMinutes)), from \(sample). Roughly \(Format.duration(minutes: left)) to go."
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 9) {
            PrimaryKey(title: "Log session", symbol: "plus") { isLogging = true }
            IconKey(symbol: "archivebox", tint: nil, size: 50, label: "Retire reed") {
                isRetiring = true
            }
        }
    }

    private var retiredNote: some View {
        Panel {
            VStack(alignment: .leading, spacing: 8) {
                RuleHeader("Retired", trailing: Format.mediumDate(reed.retiredAt ?? Date()))
                HStack(spacing: 8) {
                    Image(systemName: reed.retireReason?.symbolName ?? "archivebox")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                    Text(reed.retireReason?.displayName ?? "Retired")
                        .font(.heading(13, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                }
                if !reed.retireNote.isEmpty {
                    Text(reed.retireNote)
                        .font(.copy(12))
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
        }
    }

    private var notes: some View {
        Panel {
            VStack(alignment: .leading, spacing: 8) {
                RuleHeader("Notes")
                Text(reed.notes)
                    .font(.copy(12.5))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: History

    private var history: some View {
        Panel(padding: 14) {
            VStack(alignment: .leading, spacing: 11) {
                RuleHeader("Log", trailing: reed.sessionCount > 0
                           ? "\(Format.duration(minutes: reed.totalMinutes)) total" : nil)

                if reed.orderedSessions.isEmpty {
                    Text("Nothing logged yet.")
                        .font(.copy(12))
                        .foregroundStyle(Palette.inkTertiary)
                        .padding(.vertical, 6)
                } else {
                    Well(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(reed.orderedSessions.enumerated()), id: \.element.id) { index, session in
                                Button {
                                    editingSession = session
                                } label: {
                                    SessionRow(session: session)
                                }
                                .buttonStyle(.sink)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        context.delete(session)
                                    } label: {
                                        Label("Delete Session", systemImage: "trash")
                                    }
                                }

                                if index < reed.orderedSessions.count - 1 {
                                    Rectangle()
                                        .fill(Palette.hairline)
                                        .frame(height: Metrics.hairline)
                                        .padding(.leading, 12)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func unretire() {
        reed.retiredAt = nil
        reed.retireReasonRaw = nil
        reed.retireNote = ""
        Haptics.tick()
    }
}

struct SessionRow: View {
    var session: PlaySession

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: session.context.symbolName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.inkSecondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(session.context.displayName)
                    .font(.heading(12, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                HStack(spacing: 4) {
                    Text(Format.relativeDay(session.date))
                    Text("·")
                    Text("\(Format.duration(minutes: session.totalMinutes)) total")
                    if session.source == .automatic {
                        Image(systemName: "bolt.fill").font(.system(size: 7))
                    }
                }
                .font(.numeric(10.5))
                .foregroundStyle(Palette.inkTertiary)
            }

            Spacer(minLength: 0)

            Text(Format.duration(minutes: session.playingMinutes))
                .font(.numeric(13, weight: .semibold))
                .foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}
