import SwiftData
import SwiftUI

/// Retiring a reed is the moment its lifespan becomes data, and the last thing
/// that ever happens to it. It asks one question per page, the way logging a
/// session does: why it's done, then a page that hands back what the reed gave
/// you before you commit to it.
///
/// It used to be one scroll of three panels with the reed shown as a 40×120
/// sliver standing on end — a fourth way of drawing the one object this app is
/// about, and a form to fill in at the end of something that deserves a
/// sentence. The reed now lies in its bay exactly as it does in the case, the
/// case's own reeds, and the archive, and the numbers under it are the point of
/// the screen rather than a caption on it.
struct RetireReedView: View {
    var reed: Reed
    var onRetired: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Query private var allReeds: [Reed]

    private enum Page { case why, confirm }

    @State private var page: Page = .why
    @State private var reason: RetireReason = .wentFlat
    /// Nothing is preselected on the first page: a reason with a tick already
    /// on it is a reason the player never actually gave.
    @State private var hasChosenReason = false
    @State private var retiredAt = Date()
    @State private var note = ""
    @State private var showingWhen = false

    /// What the player's own reeds of this model have averaged, once there are
    /// any. Nil until they have retired one.
    private var comparison: LifespanSummary? {
        LifespanStats.expectation(for: reed, among: allReeds)
    }

    private var estimate: LifespanEstimate {
        LifespanStats.estimate(for: reed, among: allReeds)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                question
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { Backdrop() }
            .safeAreaInset(edge: .bottom) { footer }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if page == .why {
                        Button("Cancel") { dismiss() }
                            .font(.copy(15))
                            .foregroundStyle(Palette.inkSecondary)
                    } else {
                        Button {
                            go(to: .why)
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                                .font(.copy(15))
                                .foregroundStyle(Palette.inkSecondary)
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(page == .why ? "Step 1 of 2" : "Step 2 of 2")
                        .font(.copy(13))
                        .foregroundStyle(Palette.inkTertiary)
                }
            }
            .onAppear {
                // For checking the second page in the simulator, the way the
                // log sheet's review page is checked.
                if ProcessInfo.processInfo.arguments.contains("-openConfirm") {
                    hasChosenReason = true
                    page = .confirm
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: Chrome

    private var question: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(page == .why ? "Why is it done?" : "Here's what it gave you")
                .font(.title(26))
                .foregroundStyle(Palette.ink)
            Text(page == .why
                 ? reed.displayTitle
                 : "\(reason.displayName) · \(Format.relativeDay(retiredAt))")
                .font(.copy(14))
                .foregroundStyle(Palette.inkSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, Metrics.screenMargin)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case .why: whyPage
        case .confirm: confirmPage
        }
    }

    /// Only the second page has a key. On the first, the answer *is* the
    /// button — picking a reason takes you on, so there is nothing to confirm.
    @ViewBuilder
    private var footer: some View {
        if page == .confirm {
            PrimaryKey(title: "Retire reed", symbol: "archivebox") { retire() }
                .padding(.horizontal, Metrics.screenMargin)
                .column()
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(.bar)
        }
    }

    // MARK: Page 1 — why

    private var whyPage: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(RetireReason.allCases) { option in
                    // No "Not counted" badge. It was two words that raised the
                    // question they were meant to answer — counted toward what,
                    // and why not this one — on a page where the answer isn't
                    // needed yet. The reed that chipped is told on the next
                    // page, where the average it's being left out of is the
                    // thing on screen.
                    ChoiceRow(title: option.displayName,
                              detail: option.detail,
                              symbol: option.symbolName,
                              isSelected: hasChosenReason && reason == option) {
                        reason = option
                        hasChosenReason = true
                        go(to: .confirm)
                    }
                }
            }
            .padding(.horizontal, Metrics.screenMargin)
            .column()
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Page 2 — confirm

    private var confirmPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.stack) {
                reedPanel
                verdictPanel
                detailRows
                notesField
            }
            .padding(.horizontal, Metrics.screenMargin)
            .column()
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    /// The reed itself, in the same bay it has been lying in on every other
    /// screen. This is the last time it's shown in rotation.
    private var reedPanel: some View {
        SlotMoulding {
            ReedRow(reed: reed, estimate: estimate)
        }
        .aspectRatio(Metrics.reedLyingAspect, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    /// The payoff: the hours, and how they sit against the player's own reeds.
    /// One number and one line — everything else about this reed is a tap away
    /// on its own page, and none of it changes what the button does.
    private var verdictPanel: some View {
        Panel(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(Format.hours(minutes: reed.playingMinutes))
                        .font(.numeric(38))
                        .foregroundStyle(Palette.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("hours played")
                        .font(.copy(15))
                        .foregroundStyle(Palette.accent.opacity(0.7))
                }

                if let comparison, comparison.sampleCount > 0, reason.countsTowardLifespan {
                    // Accent, not the wear run: a reed that outlasted the
                    // average would light this bar red, which says the opposite
                    // of what happened.
                    LEDBar(progress: Double(reed.playingMinutes)
                                   / max(comparison.averageMinutes, 1),
                           segments: 18, height: 8, tint: Palette.accent)
                }

                Text(subhead)
                    .font(.copy(13))
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The two things still worth changing, both editable in place, and one
    /// line under them saying the whole thing is reversible.
    ///
    /// That line used to sit centred under the orange key, where it read as a
    /// caption on the end of the page rather than a note about the two rows it
    /// actually describes. Here it's an ordinary group footer: left margin,
    /// quiet, next to the thing it's talking about.
    private var detailRows: some View {
        VStack(alignment: .leading, spacing: 7) {
            rowGroup
            Text("You can put it back in rotation any time.")
                .font(.copy(11.5))
                .foregroundStyle(Palette.inkTertiary)
                .padding(.horizontal, 2)
        }
    }

    private var rowGroup: some View {
        VStack(spacing: 0) {
            Button {
                go(to: .why)
            } label: {
                row(label: "Reason", value: reason.displayName, chevron: "chevron.right")
            }
            .buttonStyle(.sink)

            Rectangle()
                .fill(Palette.hairline)
                .frame(height: Metrics.hairline)
                .padding(.leading, 14)

            whenRow
        }
        .padding(.vertical, 4)
        .raised(depth: .low)
    }

    private func row(label: String, value: String, chevron: String) -> some View {
        HStack {
            Text(label)
                .font(.copy(15))
                .foregroundStyle(Palette.inkSecondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.copy(15, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            Image(systemName: chevron)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.inkTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    /// Today, almost always — so it says "Today" and stays out of the way until
    /// somebody is retiring a reed they actually finished with last week.
    @ViewBuilder
    private var whenRow: some View {
        if showingWhen {
            DatePicker(selection: $retiredAt, in: ...Date(), displayedComponents: .date) {
                Text("Retired")
                    .font(.copy(15))
                    .foregroundStyle(Palette.inkSecondary)
            }
            .tint(Palette.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        } else {
            Button {
                withAnimation(.mechanical) { showingWhen = true }
            } label: {
                row(label: "Retired", value: Format.relativeDay(retiredAt), chevron: "chevron.right")
            }
            .buttonStyle(.sink)
        }
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes").microLabel()
            Well(padding: 12) {
                TextField("Anything worth remembering? (optional)", text: $note, axis: .vertical)
                    .font(.copy(15))
                    .tint(Palette.accent)
                    .lineLimit(2...4)
            }
        }
    }

    // MARK: Copy

    /// One line under the figure, whichever of the three things is true. They
    /// used to be three separate blocks that could all show at once, which is
    /// how a confirmation page turns into a report.
    private var subhead: String {
        guard reason.countsTowardLifespan else {
            return "It didn't wear out, so these hours stay out of your \(reed.modelDisplayName) average."
        }
        guard let comparison, comparison.sampleCount > 0 else {
            return "Your first \(reed.modelDisplayName)."
        }
        let delta = Double(reed.playingMinutes) - comparison.averageMinutes
        let average = Format.duration(minutes: comparison.averageMinutes)
        if abs(delta) < 30 { return "Right on your \(average) average." }
        return delta > 0
            ? "\(Format.duration(minutes: delta)) more than your \(average) average."
            : "\(Format.duration(minutes: -delta)) less than your \(average) average."
    }

    // MARK: Actions

    private func go(to next: Page) {
        page = next
        Haptics.tick()
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
