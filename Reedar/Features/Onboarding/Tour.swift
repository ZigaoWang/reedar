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
    /// The reed the tour is talking about.
    ///
    /// It has to be an identity, not a position. Ringing "the reed in slot one"
    /// looks right until the step you are on is *move a reed*: the moment it
    /// leaves slot one the ring stays behind and jumps onto whichever reed
    /// shuffled up into it, which is both wrong and the flicker you can see.
    /// Held by id, the ring travels with the reed under your finger and goes
    /// green wherever you drop it.
    var focusReed: UUID?

    /// True for the moment between doing the thing and being shown the next
    /// step, so the card can say so instead of silently swapping its words.
    var justDidIt = false

    enum Step: Int, CaseIterable {
        case dragAReed
        case openAReed
        case logASession
        case retireIt
        case archive
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
            case .archive: .archiveKey
            case .lifespan: .lifespanKey
            }
        }

        /// The gesture to mime on top of the target.
        var gesture: GestureHint.Kind? {
            switch self {
            case .dragAReed: .drag
            case .openAReed, .logASession, .retireIt, .archive, .lifespan: .tap
            case .done: nil
            }
        }

        /// The one thing this step is about, drawn on the card.
        var symbol: String {
            switch self {
            case .dragAReed: "hand.draw"
            case .openAReed: "hand.tap"
            case .logASession: "plus.circle"
            case .retireIt: "archivebox"
            case .archive: "tray.full"
            case .lifespan: "chart.bar"
            case .done: "checkmark.circle"
            }
        }

        /// The heading the tour wears once it has followed you into a sheet.
        var sheetTitle: String {
            switch self {
            case .logASession: "Fill this in"
            case .retireIt: "Say why it's done"
            default: title
            }
        }

        /// What to do inside the sheet this step sends you into, if it does.
        var sheetHint: String? {
            switch self {
            case .logASession:
                "How long you played, and what it was. Two hours of rehearsal "
                + "isn\u{2019}t two hours of wear, so Reedar works out how much of "
                + "it reached the reed."
            case .retireIt:
                "Chipped, gone soft, or simply finished. Either way the reed "
                + "keeps its hours \u{2014} and those hours are what every average "
                + "in the app is built from."
            default: nil
            }
        }

        var title: String {
            switch self {
            case .dragAReed: "Move a reed"
            case .openAReed: "Open one"
            case .logASession: "Log what you play"
            case .retireIt: "Retire it when it's done"
            case .archive: "Where finished reeds go"
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
            case .archive:
                "That reed has left the case. Tap the archive key, top left, to "
                + "see where it went — retired reeds keep every hour they did."
            case .lifespan:
                "Back in your case, tap the chart key at the top right. Every "
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
            case .archive: "Nothing is lost when you retire a reed \u{2014} it just moves out of the way."
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
        case archiveKey

        /// A reed is not a rectangle, and a box drawn round one in an app that
        /// draws the reed's outline everywhere else looks like a selection
        /// marquee. Traced properly, the highlight also shows the reed's whole
        /// length, which is what the step is asking you to pick up.
        var isReed: Bool { self == .firstReed }
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

    /// Whether the tour is standing on this step right now.
    func isShowing(_ step: Step) -> Bool { isRunning && self.step == step }

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

/// A fingertip, doing the thing the step is asking for, on top of the thing it
/// is asking you to do it to.
///
/// Words describing a gesture are the weakest part of any tour: "press and hold,
/// then drag" is four instructions and a guess about which reed. A dot that
/// slides down the reed, over and over, is none. It takes no touches, so your
/// own finger lands on the reed underneath it.
struct GestureHint: View {
    enum Kind { case tap, drag }

    var kind: Kind
    @State private var going = false

    var body: some View {
        fingertip
            .scaleEffect(kind == .tap && going ? 0.82 : 1)
            .offset(y: kind == .drag && going ? 46 : -10)
            .opacity(kind == .drag && going ? 0 : 0.95)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: kind == .tap ? 0.75 : 1.15)
                        .repeatForever(autoreverses: kind == .tap)
                ) { going = true }
            }
    }

    private var fingertip: some View {
        ZStack {
            Circle()
                .fill(Palette.accent.opacity(0.28))
                .frame(width: 42, height: 42)
            Circle()
                .fill(Palette.accent)
                .frame(width: 20, height: 20)
                .overlay { Circle().strokeBorder(.white.opacity(0.65), lineWidth: 1.5) }
                .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
        }
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
        ring.transition(.opacity)
    }

    @ViewBuilder private var ring: some View {
        if let spot {
            if let gesture = tour.step.gesture, !tour.justDidIt {
                GestureHint(kind: gesture)
                    .id(tour.step)
                    .position(x: spot.midX, y: spot.midY)
            }
            outline
                .stroke(tour.justDidIt ? Palette.signalGreen : Palette.accent,
                        lineWidth: 2.5)
                .shadow(color: (tour.justDidIt ? Palette.signalGreen : Palette.accent)
                    .opacity(0.55), radius: 10)
                .frame(width: spot.width + 10, height: spot.height + 10)
                .position(x: spot.midX, y: spot.midY)
                .allowsHitTesting(false)
                // No animation on the position. The anchor already updates
                // every frame while a reed is under a finger, so animating it
                // as well makes the ring swim along behind the reed instead of
                // being drawn on it.
                .animation(.mechanical, value: tour.justDidIt)
        }
    }

    /// The reed's own shape for a reed, a key's own corner for a key.
    private var outline: AnyShape {
        tour.step.target?.isReed == true
            ? AnyShape(ReedShape(axis: .horizontalReversed))
            : AnyShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

}

/// The tour's own card: a symbol, where you are, what to do, and a way out.
///
/// One view for both places it appears. It sits above the case for the steps
/// that happen there, and inside the log and retire sheets for the steps that
/// happen in those — because a sheet covers the card that sent you into it, and
/// a tour that goes quiet exactly when you arrive somewhere new is a tour that
/// has abandoned you. It was a thin strip with a sparkle on it at first, which
/// was a different app's furniture bolted into this one.
struct TourCard: View {
    @Bindable var tour: Tour
    /// True inside a sheet, where the step has its own heading and its own
    /// line, and where "skip" means this step rather than this screen.
    var inSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 11) {
                // The symbol in a disc, so the card has one fixed anchor point
                // that doesn't move as the words change length.
                Image(systemName: showsDone ? "checkmark" : tour.step.symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.onAccent)
                    .frame(width: 30, height: 30)
                    .background {
                        Circle().fill(showsDone ? Palette.signalGreen : Palette.accent)
                    }

                VStack(alignment: .leading, spacing: 1) {
                    Text(showsDone ? "Done" : "Step \(tour.step.rawValue + 1) of \(Tour.Step.allCases.count)")
                        .font(.micro(10.5))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(showsDone ? Palette.signalGreen : Palette.inkTertiary)
                    Text(title)
                        .font(.title(19))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 0)
            }

            Text(blurb)
                .font(.copy(14.5))
                .foregroundStyle(Palette.ink.opacity(0.9))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                // Three lines' worth, whatever the step says. Without it the
                // card grows and shrinks under your thumb every time the words
                // change, which is most of what reads as glitchy.
                .frame(minHeight: 62, alignment: .top)
                .frame(maxWidth: .infinity, alignment: .leading)

            if tour.step == .done {
                PrimaryKey(title: tour.step.forward, symbol: "plus") { tour.advance() }
                Button("Not yet") { tour.skip() }
                    .font(.copy(13.5))
                    .foregroundStyle(Palette.inkSecondary)
                    .frame(maxWidth: .infinity)
            } else {
                HStack {
                    if !inSheet {
                        Button("End tour") { tour.skip() }
                            .font(.copy(13.5))
                            .foregroundStyle(Palette.inkTertiary)
                    }
                    Spacer(minLength: 8)
                    Button(inSheet ? "Skip this step" : "Skip this step") {
                        tour.advance()
                    }
                    .font(.copy(13.5, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                    .opacity(showsDone ? 0.2 : 1)
                    .disabled(showsDone)
                }
            }
        }
        .padding(18)
        .raised(depth: .high)
        .shadow(color: .black.opacity(0.65), radius: 28, y: 14)
        .padding(.horizontal, Metrics.screenMargin)
        .column()
    }

    /// The tick only belongs where the deed was done: a sheet closing is what
    /// completes its own step, so the card inside it is already gone.
    private var showsDone: Bool { tour.justDidIt && !inSheet }

    private var title: String {
        showsDone ? "That's it" : (inSheet ? tour.step.sheetTitle : tour.step.title)
    }

    private var blurb: String {
        if showsDone { return tour.step.done }
        if inSheet, let hint = tour.step.sheetHint { return hint }
        return tour.step.blurb
    }
}
