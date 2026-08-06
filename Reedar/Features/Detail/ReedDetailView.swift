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

    private var estimate: LifespanEstimate {
        LifespanStats.estimate(for: reed, among: allReeds)
    }

    private var wear: Double {
        guard estimate.minutes > 0 else { return 0 }
        return Double(reed.playingMinutes) / estimate.minutes
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Metrics.stack) {
                header
                statusPanel
                stats
                lifeSection
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
                    Button {
                        reed.isFavourite.toggle()
                        Haptics.tick()
                    } label: {
                        Label(reed.isFavourite ? "Remove from favourites" : "Mark as favourite",
                              systemImage: reed.isFavourite ? "star.slash" : "star")
                    }

                    Divider()

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
        .task {
            // Open the log sheet directly, for checking it in the simulator.
            if ProcessInfo.processInfo.arguments.contains("-openLog") { isLogging = true }
        }
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
            Text("Retiring keeps its hours. Deleting removes everything.")
        }
    }

    // MARK: Header

    /// The reed itself, lying in a slot the width of the screen — the same
    /// object, the same way up, as the one you tapped in the case. Stood on
    /// end in a column beside the text it was a thumbnail of a reed; across
    /// the top at its true proportions it is the reed.
    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            ReedView(
                axis: .horizontalReversed,
                wear: wear,
                stamp: reed.brandName,
                strengthStamp: reed.strengthLabel,
                isRetired: reed.isRetired
            )
            .aspectRatio(Metrics.reedLyingAspect, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .padding(9)
            .milled(radius: Metrics.radiusSlot)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    if reed.isFavourite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Palette.accent)
                    }
                    Text(reed.modelDisplayName)
                        .font(.title(22))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                Text("\(reed.strengthLabel) · \(reed.instrument.displayName)")
                    .font(.copy(13))
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
        .padding(14)
        .raised(depth: .medium)
    }

    /// The three numbers, side by side and weighted the same, in one recess.
    /// They were a stack of a big inset display and two small figures crammed
    /// into a column, which read as three different kinds of thing.
    private var stats: some View {
        HStack(spacing: 0) {
            statCell(Format.hours(minutes: reed.playingMinutes), unit: "h",
                     label: "Playing time",
                     tint: reed.isRetired ? Palette.ink : Palette.accent)
            statRule
            statCell("\(reed.sessionCount)", label: "Sessions")
            statRule
            statCell(reed.daysRested.map { "\($0)" } ?? "—",
                     unit: reed.daysRested == nil ? nil : "d",
                     label: "Rested")
        }
        .padding(.vertical, 15)
        .milled(radius: Metrics.radiusInner)
    }

    private var statRule: some View {
        Rectangle().fill(Palette.hairline).frame(width: 1, height: 34)
    }

    private func statCell(_ value: String,
                          unit: String? = nil,
                          label: String,
                          tint: Color = Palette.ink) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.numeric(26))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                if let unit {
                    Text(unit)
                        .font(.numeric(13, weight: .medium))
                        .foregroundStyle(tint.opacity(0.55))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Text(label).microLabel(Palette.inkTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    /// The one thing the page has to answer: can I play this, and how much is
    /// left in it. One state, one colour, one sentence — not four separate
    /// readings for the player to combine in their head.
    /// The state, then anything worth knowing about this particular reed, in
    /// one paragraph. Break-in advice used to be a second panel below this
    /// one, which read as a competing headline rather than a footnote to it.
    private var detail: String {
        let state = reed.statusDetail(against: estimate)
        guard reed.isBreakingIn, !reed.isRetired else { return state }
        return state.hasSuffix(".") ? state + " New reed, keep sessions short."
                                    : state + ". New reed, keep sessions short."
    }

    private var statusPanel: some View {
        let status = reed.status(against: estimate)
        return Panel {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 9) {
                    Image(systemName: status.symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(status.tint)
                    Text(status.label)
                        .font(.heading(16))
                        .foregroundStyle(Palette.ink)
                }
                Text(detail)
                    .font(.copy(13))
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Life

    /// Always here, even before there's anything to compare against. A panel
    /// that appears only once the app has enough data is a panel nobody knows
    /// exists, and the reason it's empty is worth saying out loud.
    private var lifeSection: some View {
        Panel {
            VStack(alignment: .leading, spacing: 11) {
                RuleHeader("Life", trailing: "\(Format.hours(minutes: estimate.minutes))h expected")
                LEDBar(progress: wear, segments: 18, height: 9)
                Text(lifeText)
                    .font(.copy(12))
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }



    /// Always says what the figure is based on. An estimate off a typical reed
    /// and one off six of your own are very different claims, and the app
    /// should not present them in the same voice.
    private var lifeText: String {
        let expected = Format.duration(minutes: estimate.minutes)
        let left = estimate.minutes - Double(reed.playingMinutes)
        let basis = estimate.isPersonal
            ? "\(expected) is the average for \(estimate.source), from \(Format.count(estimate.sampleCount, "reed"))."
            : "\(expected) is what \(estimate.source) lasts. Retire one of your own to make this yours."
        if left <= 0 { return "Past \(expected). " + basis }
        return "About \(Format.duration(minutes: left)) left. " + basis
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
