import SwiftUI

/// The guided tour: onboarding that happens in the app rather than in a
/// slideshow about it.
///
/// It was three screens of pictures first. The pictures were built from the
/// app's own components, which made them honest, and they were still pictures:
/// you read about dragging a reed instead of dragging one. So the app opens on
/// a case that already has reeds in it, and the tour asks you to actually pick
/// one up, actually open it, actually go and look at the lifespan screen.
///
/// Two rules hold it together. **Nothing it shows is real** — the reeds come
/// from the in-memory container the previews use, and the real store isn't
/// opened until the tour is over, so no demo reed can be written to disk or
/// synced to another device. And **it never blocks anything**: the dimming
/// takes no touches, so every gesture it describes can be tried the moment it
/// is described, and Skip is on every step.
@MainActor
@Observable
final class Tour {
    /// `-tourStep 2` opens the tour on its second step, for looking at one
    /// without walking through the ones before it.
    var step: Step = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-tourStep"),
              arguments.indices.contains(flag + 1),
              let number = Int(arguments[flag + 1]),
              let step = Step(rawValue: number - 1)
        else { return .dragAReed }
        return step
    }()
    /// Whether the tour is running at all.
    var isRunning = false
    /// Raised on the last step when the player asks to add a reed for real.
    var wantsFirstReed = false
    /// True for the moment between doing the thing and being shown the next
    /// step, so the card can say so instead of silently swapping its words.
    var justDidIt = false

    enum Step: Int, CaseIterable {
        case dragAReed
        case openAReed
        case logASession
        case retireIt
        case lifespan
        case done

        /// What the step points at, if anything. `nil` means the card sits in
        /// the middle of the screen and talks about the app as a whole.
        var target: Target? {
            switch self {
            case .done: nil
            case .dragAReed, .openAReed: .firstReed
            case .logASession: .logKey
            case .retireIt: .retireKey
            case .lifespan: .lifespanKey
            }
        }

        /// The one thing this step is about, drawn on the card.
        var symbol: String {
            switch self {
            case .dragAReed: "hand.draw"
            case .openAReed: "hand.tap"
            case .logASession: "plus.circle"
            case .retireIt: "archivebox"
            case .lifespan: "chart.bar"
            case .done: "checkmark.circle"
            }
        }

        /// What to do inside the sheet this step sends you into, if it does.
        var sheetHint: String? {
            switch self {
            case .logASession:
                "Set how long you played and what it was — Reedar works out how "
                + "much of that actually wore the reed. Then save it."
            case .retireIt:
                "Say why it's finished. Its hours are kept either way — that's "
                + "what the averages are made of."
            default: nil
            }
        }

        var title: String {
            switch self {
            case .dragAReed: "Move a reed"
            case .openAReed: "Open one"
            case .logASession: "Log what you play"
            case .retireIt: "Retire it when it's done"
            case .lifespan: "What your reeds last"
            case .done: "That's the whole app"
            }
        }

        var blurb: String {
            switch self {
            case .dragAReed:
                "Press and hold the ringed reed, then drag it down a slot or "
                + "two. The others shuffle aside to make room."
            case .openAReed:
                "Now tap that reed to open it. Everything in Reedar happens to "
                + "a reed, so you pick one up first."
            case .logASession:
                "Tap Log session. How long you played, and what it was — a "
                + "rehearsal isn\u{2019}t two hours of wear, so Reedar counts the "
                + "part you spent blowing."
            case .retireIt:
                "Tap the archive key. Retiring a finished reed is the moment "
                + "the app learns something: a reed that lasted you 9 hours."
            case .lifespan:
                "Go back to your case, then tap the chart key at the top. Every "
                + "retired reed adds up there."
            case .done:
                "The case, a reed, and the numbers behind it. Ready to put a "
                + "real one in?"
            }
        }

        /// What the app says the moment you do it — the confirmation that the
        /// step was the thing you just did, not a coincidence.
        var done: String {
            switch self {
            case .dragAReed: "The reeds shuffled aside to make room for it."
            case .openAReed: "This is the reed's own page \u{2014} its hours, its log, and what's left in it."
            case .logASession: "Every session you log wears the reed down a little."
            case .retireIt: "Retired reeds keep their hours. That's what the averages are made of."
            case .lifespan: "This fills in as you retire reeds \u{2014} by model, and by strength."
            case .done: ""
            }
        }

        /// The word on the key.
        ///
        /// "Skip this" rather than "Next" for every step the app can detect
        /// for itself: the way forward is doing the thing, and the key is for
        /// people who would rather not.
        var forward: String {
            switch self {
            case .done: "Add my first reed"
            default: "Skip this"
            }
        }
    }

    /// The things a step can point at. Views claim these with `.tourTarget(_:)`.
    enum Target: Hashable {
        case firstReed
        case lifespanKey
        case logKey
        case retireKey
    }

    /// The player did the thing the step asked for.
    ///
    /// Only the step that is currently being shown can be completed by it, so
    /// opening a reed on the "move a reed" step doesn't skip a beat, and going
    /// back to a screen you have already been shown doesn't wind the tour
    /// backwards. Everything else is ignored on purpose.
    ///
    /// The pause is the point. A step that vanishes the instant you touch the
    /// thing it is pointing at reads as a glitch — you get no moment of having
    /// done it right. Long enough to see the reed land, short enough not to
    /// wait on it.
    func completed(_ step: Step) {
        guard isRunning, step == self.step, !justDidIt else { return }
        Haptics.reedAdded()
        withAnimation(.mechanical) { justDidIt = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            guard isRunning, step == self.step else { return }
            withAnimation(.settle) { justDidIt = false }
            advance(quietly: true)
        }
    }

    /// The line a sheet should show, or nothing if the tour isn't there yet.
    func hint(for step: Step) -> String? {
        guard isRunning, self.step == step else { return nil }
        return step.sheetHint
    }

    func advance(quietly: Bool = false) {
        if !quietly { Haptics.tick() }
        justDidIt = false
        guard let next = Step(rawValue: step.rawValue + 1) else {
            wantsFirstReed = true
            isRunning = false
            return
        }
        withAnimation(.settle) { step = next }
    }

    func skip() {
        Haptics.tick()
        isRunning = false
    }
}

/// The label that sits over the borrowed case for as long as it is borrowed.
///
/// Without it the app opens on three reeds nobody bought, asks you to retire
/// one, and leaves you working out whether you have somehow inherited a case.
/// It says what they are in four words and gets out of the way.
///
/// Drawn as an overlay above the case rather than a row inside it: a strip in
/// the layout would take height off the bed and squash every bay, and the bays
/// are the one thing on that screen that must not move.
struct DemoTag: View {
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "hand.tap")
                .font(.system(size: 11, weight: .bold))
            Text("Practice reeds — none of these are yours")
                .font(.copy(12, weight: .semibold))
        }
        .foregroundStyle(Palette.onAccent)
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .background(Capsule().fill(Palette.accent))
        .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
        .allowsHitTesting(false)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

/// One line of guidance inside a sheet the tour has sent you into.
///
/// The tour's own card lives above the case, and a sheet covers it — so the
/// moment somebody follows "tap Log session" they lose the voice that told
/// them to. This is that voice, carried into the sheet.
struct TourHint: View {
    var text: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.accent)
            Text(text)
                .font(.copy(12.5))
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: Metrics.radiusInner, style: .continuous)
                .fill(Palette.surfaceRaised)
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.radiusInner, style: .continuous)
                        .strokeBorder(Palette.accent.opacity(0.35), lineWidth: 1)
                }
        }
        .padding(.horizontal, Metrics.screenMargin)
        .padding(.bottom, 8)
    }
}

// MARK: - Claiming a place on screen

/// Where each tour target is, in the window's coordinates.
///
/// Anchors rather than frames: a `GeometryReader` per target would change the
/// layout it is trying to measure, and these targets are reeds and keys whose
/// sizes are the whole point.
struct TourAnchors: PreferenceKey {
    static var defaultValue: [Tour.Target: Anchor<CGRect>] { [:] }

    static func reduce(value: inout [Tour.Target: Anchor<CGRect>],
                       nextValue: () -> [Tour.Target: Anchor<CGRect>]) {
        value.merge(nextValue()) { first, _ in first }
    }
}

extension View {
    /// Marks this view as something the tour can point at.
    func tourTarget(_ target: Tour.Target) -> some View {
        anchorPreference(key: TourAnchors.self, value: .bounds) { [target: $0] }
    }

    /// The same, for one of many — the first reed in the case is a tour target
    /// and the seven behind it are not.
    @ViewBuilder
    func tourTargetIf(_ condition: Bool, _ target: Tour.Target) -> some View {
        if condition { tourTarget(target) } else { self }
    }
}

// MARK: - What you see

/// The ring and the card. No scrim.
///
/// It dimmed the whole app at first, with a hole cut out for whatever was being
/// pointed at. Two things were wrong with that. The app went black, which is a
/// strange thing to do to somebody you are trying to show around — the tour is
/// meant to be about the app, not draped over it. And the hole was a rectangle
/// cut where the target *was*: drag the reed the step is asking you to drag and
/// it slides straight out of its own spotlight, leaving a bright empty hole and
/// a dark reed.
///
/// So the app stays lit and the ring follows. It is anchored to the target's own
/// bounds, which move with it, so a reed under your finger stays ringed the
/// whole way down the case.
struct TourOverlay: View {
    @Bindable var tour: Tour
    /// Where the current step's target is, if it is on this screen.
    var spot: CGRect?

    var body: some View {
        ZStack(alignment: .bottom) {
            ring
            VStack(spacing: 9) {
                DemoTag()
                card
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 10)
        }
        .transition(.opacity)
    }

    @ViewBuilder private var ring: some View {
        if let spot {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tour.justDidIt ? Palette.signalGreen : Palette.accent,
                              lineWidth: 2.5)
                .shadow(color: (tour.justDidIt ? Palette.signalGreen : Palette.accent)
                    .opacity(0.5), radius: 10)
                .frame(width: spot.width + 12, height: spot.height + 12)
                .position(x: spot.midX, y: spot.midY)
                .allowsHitTesting(false)
                // Follows the thing it is pointing at, including while a finger
                // is dragging it.
                .animation(.spring(response: 0.28, dampingFraction: 0.9), value: spot)
                .animation(.mechanical, value: tour.justDidIt)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                Image(systemName: tour.justDidIt
                      ? "checkmark.circle.fill" : tour.step.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tour.justDidIt ? Palette.signalGreen : Palette.accent)
                    .frame(width: 20)
                Text(tour.justDidIt ? "That's it" : tour.step.title)
                    .font(.heading(17))
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                // Lamps for the feel of it, and the number for anybody who
                // wants to know how much of this is left.
                Text("\(tour.step.rawValue + 1) of \(Tour.Step.allCases.count)")
                    .font(.numeric(11.5, weight: .medium))
                    .foregroundStyle(Palette.inkTertiary)
                lamps
            }

            Text(tour.justDidIt ? tour.step.done : tour.step.blurb)
                .font(.copy(13.5))
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            // The loud key only where pressing one is the actual next move.
            // On every other step the way on is to go and do the thing being
            // pointed at, and an orange key saying "Skip this" next to that
            // instruction is the app shouting over itself.
            if tour.step == .done {
                PrimaryKey(title: tour.step.forward, symbol: "plus") { tour.advance() }
                    .padding(.top, 4)
                Button("Not yet") { tour.skip() }
                    .font(.copy(13.5))
                    .foregroundStyle(Palette.inkSecondary)
                    .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 12) {
                    Button("Skip tour") { tour.skip() }
                        .font(.copy(13))
                        .foregroundStyle(Palette.inkTertiary)
                    Spacer(minLength: 8)
                    Button(tour.step.forward) { tour.advance() }
                        .font(.copy(13.5, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                        .opacity(tour.justDidIt ? 0.25 : 1)
                        .disabled(tour.justDidIt)
                }
                .padding(.top, 5)
            }
        }
        .padding(16)
        .raised(depth: .high)
        .shadow(color: .black.opacity(0.6), radius: 26, y: 12)
        .padding(.horizontal, Metrics.screenMargin)
        .column()
        .animation(.settle, value: tour.step)
    }

    /// How far along, in the app's own lamps rather than "3 of 5".
    private var lamps: some View {
        HStack(spacing: 5) {
            ForEach(Tour.Step.allCases, id: \.rawValue) { step in
                LED(isOn: step.rawValue <= tour.step.rawValue, size: 5)
            }
        }
        .animation(.mechanical, value: tour.step)
        .accessibilityLabel("Step \(tour.step.rawValue + 1) of \(Tour.Step.allCases.count)")
    }
}
