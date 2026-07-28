import SwiftData
import SwiftUI

/// Two taps and you're done: how long, and what it was. The app works out how
/// much of that was actually playing; the number is shown plainly and can be
/// nudged, but nobody has to touch it.
struct LogSessionView: View {
    /// The reed this session belongs to. Sessions are always logged against a
    /// reed you already picked up, so there is nothing to choose here.
    var reed: Reed
    /// Existing session to edit; nil when logging a new one.
    var editing: PlaySession?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var date = Date()
    @State private var totalMinutes = 60
    @State private var ratio = SessionContext.practice.defaultPlayingRatio
    @State private var sessionContext: SessionContext = .practice
    @State private var showingAdjust = false
    @State private var showingOther = false
    @State private var showingWhen = false
    @State private var didPrepare = false

    private let presets = [15, 30, 45, 60, 90, 120]

    private var playingMinutes: Int {
        max(5, Int((Double(totalMinutes) * ratio / 5).rounded()) * 5)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    reedBanner
                    durationStep
                    contextStep
                    result
                    whenRow
                }
                .padding(.horizontal, Metrics.screenMargin)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background { Backdrop() }
            .safeAreaInset(edge: .bottom) {
                PrimaryKey(title: editing == nil ? "Save" : "Save changes",
                           symbol: "checkmark",
) { save() }
                    .padding(.horizontal, Metrics.screenMargin)
                    .padding(.bottom, 8)
                    .padding(.top, 6)
                    .background(.bar)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(editing == nil ? "Log a session" : "Edit session")
                        .font(.heading(12.5, weight: .bold))
                        .foregroundStyle(Palette.ink)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.heading(12, weight: .medium))
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            .onAppear(perform: prepare)
        }
    }

    // MARK: Steps

    /// A reminder of which reed you're logging against, not a control.
    private var reedBanner: some View {
        HStack(spacing: 12) {
            ReedView(axis: .horizontalReversed)
                .frame(width: 78, height: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(reed.displayTitle)
                    .font(.heading(15))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text("\(Format.hours(minutes: reed.playingMinutes))h so far")
                    .font(.copy(12))
                    .foregroundStyle(Palette.inkSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .raised(depth: .low)
    }

    private var durationStep: some View {
        Step(number: 1, question: "How long did you play?") {
            VStack(spacing: 7) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3),
                          spacing: 7) {
                    ForEach(presets, id: \.self) { minutes in
                        ChoiceKey(title: spokenDuration(minutes),
                               isSelected: totalMinutes == minutes && !showingOther) {
                            withAnimation(.mechanical) {
                                totalMinutes = minutes
                                showingOther = false
                            }
                            Haptics.tick()
                        }
                    }
                }

                if showingOther {
                    HStack(spacing: 10) {
                        stepKey("minus", -5)
                        Text(Format.duration(minutes: totalMinutes))
                            .font(.numeric(20, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                            .frame(maxWidth: .infinity)
                            .contentTransition(.numericText())
                        stepKey("plus", 5)
                    }
                    .padding(.top, 2)
                } else {
                    ChoiceKey(title: "Something else", isSelected: false, height: 42) {
                        withAnimation(.mechanical) { showingOther = true }
                        Haptics.tick()
                    }
                }
            }
        }
    }

    private var contextStep: some View {
        Step(number: 2, question: "What was it?") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3),
                      spacing: 7) {
                ForEach(SessionContext.allCases) { option in
                    ChoiceKey(title: option.displayName,
                           symbol: option.symbolName,
                           isSelected: sessionContext == option,
                           height: 62) {
                        withAnimation(.mechanical) {
                            sessionContext = option
                            ratio = option.defaultPlayingRatio
                        }
                        Haptics.tick()
                    }
                }
            }
        }
    }

    /// What the app worked out, in a sentence, with the escape hatch tucked
    /// underneath for the people who care.
    private var result: some View {
        Panel(padding: 14) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("That's about")
                        .font(.copy(13))
                        .foregroundStyle(Palette.inkSecondary)
                    Text(Format.duration(minutes: playingMinutes))
                        .font(.numeric(21, weight: .bold))
                        .foregroundStyle(Palette.accent)
                        .contentTransition(.numericText())
                    Text("of playing")
                        .font(.copy(13))
                        .foregroundStyle(Palette.inkSecondary)
                }

                Text(sessionContext.ratioExplanation)
                    .font(.copy(11.5))
                    .foregroundStyle(Palette.inkTertiary)

                if showingAdjust {
                    VStack(spacing: 8) {
                        Slider(value: $ratio, in: 0.05...1) { editing in
                            if !editing { Haptics.tick() }
                        }
                        .tint(Palette.accent)
                        HStack {
                            Text("\(Format.percent(ratio)) of the time")
                                .font(.numeric(11))
                                .foregroundStyle(Palette.inkTertiary)
                            Spacer()
                            Button("Reset") {
                                withAnimation(.mechanical) { ratio = sessionContext.defaultPlayingRatio }
                            }
                            .font(.heading(11, weight: .semibold))
                            .foregroundStyle(Palette.accent)
                        }
                    }
                } else {
                    Button {
                        withAnimation(.mechanical) { showingAdjust = true }
                    } label: {
                        Text("Not right? Adjust it")
                            .font(.heading(11.5, weight: .semibold))
                            .foregroundStyle(Palette.accent)
                    }
                }
            }
        }
    }

    private var whenRow: some View {
        Group {
            if showingWhen {
                Panel(padding: 12) {
                    DatePicker("", selection: $date, in: ...Date(),
                               displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(Palette.accent)
                }
            } else {
                Button {
                    withAnimation(.mechanical) { showingWhen = true }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "clock").font(.system(size: 11, weight: .semibold))
                        Text(Format.relativeDay(date))
                            .font(.heading(11.5, weight: .medium))
                        Text("· tap to change")
                            .font(.copy(11))
                            .foregroundStyle(Palette.inkTertiary)
                    }
                    .foregroundStyle(Palette.inkSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.sink)
            }
        }
    }

    private func stepKey(_ symbol: String, _ delta: Int) -> some View {
        Button {
            let next = totalMinutes + delta
            guard next >= 5, next <= 600 else { Haptics.warning(); return }
            withAnimation(.mechanical) { totalMinutes = next }
            Haptics.tick()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Palette.ink)
                .frame(width: 58, height: 42)
        }
        .buttonStyle(KeyButtonStyle(radius: Metrics.radiusKey, travel: 2.5))
    }

    /// "1 hour", not "60m" — the app is talking, not reporting.
    private func spokenDuration(_ minutes: Int) -> String {
        switch minutes {
        case ..<60: "\(minutes) min"
        case 60: "1 hour"
        case 90: "1½ hours"
        default: "\(minutes / 60) hours"
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
            ratio = editing.totalMinutes > 0
                ? Double(editing.playingMinutes) / Double(editing.totalMinutes)
                : editing.context.defaultPlayingRatio
            showingOther = !presets.contains(editing.totalMinutes)
        }
    }

    private func save() {
        if let editing {
            editing.reed = reed
            editing.date = date
            editing.totalMinutes = totalMinutes
            editing.playingMinutes = playingMinutes
            editing.contextRaw = sessionContext.rawValue
        } else {
            context.insert(PlaySession(
                date: date,
                totalMinutes: totalMinutes,
                playingMinutes: playingMinutes,
                context: sessionContext,
                source: .manual,
                reed: reed
            ))
        }

        Haptics.sessionLogged()
        dismiss()
    }
}

// MARK: - Pieces

/// A numbered question. The whole flow is three of these.
struct Step<Content: View>: View {
    var number: Int
    var question: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("\(number)")
                    .font(.numeric(10, weight: .bold))
                    .foregroundStyle(Palette.onAccent)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Palette.accent))
                Text(question)
                    .font(.heading(15, weight: .bold))
                    .foregroundStyle(Palette.ink)
            }
            content
        }
    }
}


