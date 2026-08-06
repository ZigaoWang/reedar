import SwiftData
import SwiftUI

/// Logging a session works the same way as adding a reed: one question per
/// page. What you were doing, how long, then a page that tells you what the
/// app worked out and lets you change it before saving.
struct LogSessionView: View {
    /// The reed this session belongs to. You picked it up to get here, so
    /// there is nothing to choose.
    var reed: Reed
    /// Existing session to edit; nil when logging a new one.
    var editing: PlaySession?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private enum Page { case what, how, review }

    @State private var page: Page = .what
    @State private var date = Date()
    @State private var totalMinutes = 60
    @State private var ratio = SessionContext.practice.defaultPlayingRatio
    @State private var sessionContext: SessionContext = .practice
    @State private var note = ""
    @State private var showingAdjust = false
    @State private var showingWhen = false
    @State private var didPrepare = false
    @State private var repeater: Task<Void, Never>?

    private let presets = [15, 30, 45, 60, 90, 120]

    private var playingMinutes: Int {
        max(5, Int((Double(totalMinutes) * ratio / 5).rounded()) * 5)
    }

    /// What this reed will be on once the session is saved.
    private var newTotal: Int {
        let existing = editing.map { reed.playingMinutes - $0.playingMinutes } ?? reed.playingMinutes
        return existing + playingMinutes
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
                    if page == .what {
                        Button("Cancel") { dismiss() }
                            .font(.copy(15))
                            .foregroundStyle(Palette.inkSecondary)
                    } else {
                        Button {
                            back()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                                .font(.copy(15))
                                .foregroundStyle(Palette.inkSecondary)
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(stepLabel)
                        .font(.copy(13))
                        .foregroundStyle(Palette.inkTertiary)
                }
            }
            .onAppear(perform: prepare)
            .onDisappear { stopRepeating() }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: Chrome

    private var stepLabel: String {
        switch page {
        case .what: "Step 1 of 3"
        case .how: "Step 2 of 3"
        case .review: "Step 3 of 3"
        }
    }

    private var questionText: String {
        switch page {
        case .what: "What were you doing?"
        case .how: "How long?"
        case .review: "Here's the session"
        }
    }

    private var subtitle: String {
        switch page {
        case .what: reed.displayTitle
        case .how: sessionContext.displayName
        case .review: "\(sessionContext.displayName) · \(Format.duration(minutes: totalMinutes))"
        }
    }

    private var question: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(questionText)
                .font(.title(26))
                .foregroundStyle(Palette.ink)
            Text(subtitle)
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
        case .what: whatPage
        case .how: howPage
        case .review: reviewPage
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch page {
        case .what:
            EmptyView()
        case .how:
            PrimaryKey(title: "Continue", symbol: "arrow.right") { go(to: .review) }
                .padding(.horizontal, Metrics.screenMargin)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(.bar)
        case .review:
            PrimaryKey(title: editing == nil ? "Save session" : "Save changes",
                       symbol: "checkmark") { save() }
                .padding(.horizontal, Metrics.screenMargin)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(.bar)
        }
    }

    // MARK: Page 1 — what

    private var whatPage: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(SessionContext.allCases) { option in
                    ChoiceRow(title: option.displayName,
                              detail: option.ratioExplanation,
                              isSelected: false) {
                        sessionContext = option
                        if !showingAdjust { ratio = option.defaultPlayingRatio }
                        go(to: .how)
                    }
                }
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Page 2 — how long

    private var howPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Tapping a time is the fast path — it takes you straight on.
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                          spacing: 10) {
                    ForEach(presets, id: \.self) { minutes in
                        ChoiceKey(title: Format.duration(minutes: minutes),
                                  isSelected: totalMinutes == minutes,
                                  height: 62) {
                            withAnimation(.mechanical) { totalMinutes = minutes }
                            Haptics.tick()
                        }
                    }
                }

                if reed.isBreakingIn {
                    HStack(spacing: 7) {
                        Image(systemName: "leaf")
                            .font(.system(size: 12, weight: .semibold))
                        Text("New reed. Keep it short.")
                            .font(.copy(13))
                    }
                    .foregroundStyle(Palette.accent)
                    .padding(.top, 4)
                }

                Text("Or set it exactly")
                    .font(.copy(13))
                    .foregroundStyle(Palette.inkTertiary)
                    .padding(.top, 6)

                HStack(spacing: 12) {
                    stepButton("minus", -5)
                    Text(Format.duration(minutes: totalMinutes))
                        .font(.numeric(30))
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity)
                        .contentTransition(.numericText())
                    stepButton("plus", 5)
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .raised(depth: .low)
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private func stepButton(_ symbol: String, _ delta: Int) -> some View {
        Button {
            step(by: delta)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Palette.ink)
                .frame(width: 56, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Palette.surfaceRaised)
                )
        }
        .buttonStyle(.sink)
        .accessibilityLabel(delta > 0 ? "Add five minutes" : "Take off five minutes")
        // Holding keeps counting, so a three hour rehearsal isn't 36 taps.
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35).onEnded { _ in startRepeating(delta) }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0).onEnded { _ in stopRepeating() }
        )
    }

    // MARK: Page 3 — review

    private var reviewPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 0) {
                    summaryRow("Session", value: sessionContext.displayName)
                    divider
                    summaryRow("Length", value: Format.duration(minutes: totalMinutes))
                    divider
                    whenRow
                    divider
                    playingRow
                    divider
                    totalRow
                }
                .padding(.vertical, 4)
                .raised(depth: .low)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes").microLabel()
                    Well(padding: 12) {
                        TextField("How did it feel? (optional)", text: $note, axis: .vertical)
                            .font(.copy(15))
                            .tint(Palette.accent)
                            .lineLimit(2...4)
                    }
                }
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var divider: some View {
        Rectangle()
            .fill(Palette.hairline)
            .frame(height: Metrics.hairline)
            .padding(.leading, 14)
    }

    private func summaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.copy(15))
                .foregroundStyle(Palette.inkSecondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.copy(15, weight: .semibold))
                .foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    /// The one figure the app worked out for you, with its reasoning and a way
    /// to overrule it.
    private var playingRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Counts as playing")
                    .font(.copy(15))
                    .foregroundStyle(Palette.inkSecondary)
                Spacer(minLength: 8)
                Text(Format.duration(minutes: playingMinutes))
                    .font(.copy(15, weight: .bold))
                    .foregroundStyle(Palette.accent)
                    .contentTransition(.numericText())
            }

            Text(sessionContext.ratioExplanation)
                .font(.copy(12.5))
                .foregroundStyle(Palette.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)

            if showingAdjust {
                Slider(value: $ratio, in: 0.05...1) { editing in
                    if !editing { Haptics.tick() }
                }
                .tint(Palette.accent)
                HStack {
                    Text("\(Format.percent(ratio)) of the session")
                        .font(.copy(12))
                        .foregroundStyle(Palette.inkTertiary)
                    Spacer()
                    Button("Reset") {
                        withAnimation(.mechanical) {
                            ratio = sessionContext.defaultPlayingRatio
                            showingAdjust = false
                        }
                    }
                    .font(.copy(12, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                }
            } else {
                Button("Not right? Adjust it") {
                    withAnimation(.mechanical) { showingAdjust = true }
                }
                .font(.copy(13, weight: .semibold))
                .foregroundStyle(Palette.accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    /// What saving does to the reed — the reason any of this is being typed in.
    private var totalRow: some View {
        HStack {
            Text(reed.displayTitle)
                .font(.copy(15))
                .foregroundStyle(Palette.inkSecondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text("\(Format.hours(minutes: reed.playingMinutes))h")
                .font(.numeric(15))
                .foregroundStyle(Palette.inkSecondary)
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.inkTertiary)
            Text("\(Format.hours(minutes: newTotal))h")
                .font(.numeric(15, weight: .bold))
                .foregroundStyle(Palette.accent)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    private var whenRow: some View {
        Group {
            if showingWhen {
                DatePicker(selection: $date, in: ...Date(),
                           displayedComponents: [.date, .hourAndMinute]) {
                    Text("When")
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
                    HStack {
                        Text("When")
                            .font(.copy(15))
                            .foregroundStyle(Palette.inkSecondary)
                        Spacer(minLength: 8)
                        Text(Format.relativeDay(date))
                            .font(.copy(15, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.inkTertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.sink)
            }
        }
    }

    // MARK: Duration stepping

    private func step(by delta: Int) {
        let next = totalMinutes + delta
        guard next >= 5, next <= 600 else { Haptics.warning(); stopRepeating(); return }
        withAnimation(.mechanical) { totalMinutes = next }
        Haptics.tick()
    }

    private func startRepeating(_ delta: Int) {
        repeater?.cancel()
        repeater = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(90))
                guard !Task.isCancelled else { return }
                step(by: delta)
            }
        }
    }

    private func stopRepeating() {
        repeater?.cancel()
        repeater = nil
    }

    // MARK: Navigation

    private func go(to next: Page) {
        page = next
        Haptics.tick()
    }

    private func back() {
        switch page {
        case .what: break
        case .how: page = .what
        case .review: page = .how
        }
    }

    // MARK: Actions

    private func prepare() {
        guard !didPrepare else { return }
        didPrepare = true

        if let editing {
            date = editing.date
            totalMinutes = editing.totalMinutes
            sessionContext = editing.context
            note = editing.note
            ratio = editing.totalMinutes > 0
                ? Double(editing.playingMinutes) / Double(editing.totalMinutes)
                : editing.context.defaultPlayingRatio
            showingAdjust = abs(ratio - editing.context.defaultPlayingRatio) > 0.02
            page = .review
        } else if let last = reed.orderedSessions.first {
            // Most players repeat themselves: same kind of session, similar
            // length. Starting there usually means no adjusting at all.
            sessionContext = last.context
            totalMinutes = min(max(last.totalMinutes, 5), 600)
            ratio = last.context.defaultPlayingRatio
        }
        if ProcessInfo.processInfo.arguments.contains("-openReview") { page = .review }
    }

    private func save() {
        if let editing {
            editing.date = date
            editing.totalMinutes = totalMinutes
            editing.playingMinutes = playingMinutes
            editing.contextRaw = sessionContext.rawValue
            editing.note = note.trimmed
        } else {
            context.insert(PlaySession(
                date: date,
                totalMinutes: totalMinutes,
                playingMinutes: playingMinutes,
                context: sessionContext,
                source: .manual,
                note: note.trimmed,
                reed: reed
            ))
        }

        Haptics.sessionLogged()
        dismiss()
    }
}
