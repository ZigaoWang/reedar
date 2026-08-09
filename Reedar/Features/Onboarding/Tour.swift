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

    /// What the screen you are actually on wants to say, set by that screen.
    ///
    /// The add and retire flows have steps of their own, and a tour that says
    /// "fill this in" while you are three questions deep has stopped helping.
    /// Each page sets this as it goes and clears it when it leaves, so the one
    /// card can follow a flow it knows nothing about.
    var detail: String?

    /// The steps that have been carried out. Membership is what unlocks the
    /// key that moves on: until you have done the thing, Next is not a way
    /// forward, it is a way past — and that is what Skip is for.
    var done: Set<Step> = []

    /// Whether the step on screen has been carried out.
    var isDone: Bool { done.contains(step) }

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
            case .dragAReed: "Drag a reed"
            case .openAReed: "Open a reed"
            case .logASession: "Log a session"
            case .retireIt: "Retire a reed"
            case .archive: "Find it again"
            case .lifespan: "See what they last"
            case .done: "You've seen it all"
            }
        }

        var blurb: String {
            switch self {
            case .dragAReed:
                "Press and hold the ringed reed, then slide it down. Reeds sit "
                + "in the order you mean to play them."
            case .openAReed:
                "Tap that same reed. Everything in Reedar happens to a reed, so "
                + "you pick one up first."
            case .logASession:
                "Tap Log session. Three taps, and it is the only thing the app "
                + "ever asks of you."
            case .retireIt:
                "Tap the archive key beside it. A reed you retire is a reed the "
                + "app can finally learn from."
            case .archive:
                "Tap the archive key, top left. Retired reeds live there, hours "
                + "and all."
            case .lifespan:
                "Go back, then tap the chart key, top right. This is what all "
                + "the logging was for."
            case .done:
                "The case, a reed, and the numbers behind it. Time to put a real "
                + "reed in."
            }
        }

        /// What the app says the moment you do it — the confirmation that the
        /// step was the thing you just did, not a coincidence.
        var done: String {
            switch self {
            case .dragAReed: "The others shuffled aside to make room for it."
            case .openAReed: "Its hours, its log, and how much is left in it."
            case .logASession: "That reed's hours just went up."
            case .retireIt: "Out of the case — and it kept every hour it did."
            case .archive: "Nothing is lost when a reed is retired."
            case .lifespan: "It fills in further with every reed you finish."
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
    /// The player did the thing the step asked for.
    ///
    /// It marks the step and stops there. Moving on used to happen on a timer,
    /// which meant the app deciding you had finished reading — and taking the
    /// screen away mid-sentence if you hadn't. The tick and the unlocked key
    /// say the step is done; you say when to leave it.
    func completed(_ step: Step) {
        guard isRunning, step == self.step, !done.contains(step) else { return }
        Haptics.reedAdded()
        withAnimation(.settle) { done.insert(step) }
    }

    /// Whether the tour is standing on this step right now.
    func isShowing(_ step: Step) -> Bool { isRunning && self.step == step }

    func advance(quietly: Bool = false) {
        if !quietly { Haptics.tick() }
        guard let next = Step(rawValue: step.rawValue + 1) else {
            wantsFirstReed = true
            isRunning = false
            return
        }
        withAnimation(.settle) { step = next }
    }

    /// Back a step. There is no undoing what you already did to a reed, so
    /// this only moves the card: it is for people who want to read the last
    /// one again, which is most people, once.
    /// Back a step, and arm it again.
    ///
    /// Going back to a step you have already done and finding it still ticked
    /// makes the tour a list you have read rather than a thing you are doing.
    /// It is re-armed, so the instruction means what it says a second time.
    func back() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        Haptics.tick()
        withAnimation(.settle) {
            done.remove(previous)
            step = previous
        }
    }

    var canGoBack: Bool { step.rawValue > 0 }

    func skip() {
        Haptics.tick()
        isRunning = false
    }
}

/// The light around whatever the step is pointing at.
///
/// It was a 2.5pt orange stroke, which is a selection marquee: hard, flat, and
/// stuck on top of a reed rather than shining on it. Nothing else in this app
/// is outlined — things are lit from above, or cut into the case, or lying in
/// it. So this is light: a soft edge that breathes, and no line at all.
///
/// It stops breathing the moment the step is done and turns green, because a
/// thing that has been dealt with should stop asking for attention.
private struct Halo: View {
    var shape: AnyShape
    var isDone: Bool

    @State private var breathing = false

    private var colour: Color { isDone ? Palette.signalGreen : Palette.accent }

    var body: some View {
        ZStack {
            // The glow, well outside the edge.
            shape
                .stroke(colour.opacity(0.55), lineWidth: 9)
                .blur(radius: 11)
                .scaleEffect(breathing && !isDone ? 1.035 : 1)
            // A thin bright edge, so the shape stays legible against cane.
            shape
                .stroke(colour.opacity(0.9), lineWidth: 1.5)
                .blur(radius: 0.4)
        }
        .opacity(breathing && !isDone ? 0.75 : 1)
        .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true),
                   value: breathing)
        .animation(.settle, value: isDone)
        .onAppear { breathing = true }
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
            if let gesture = tour.step.gesture, !tour.isDone {
                GestureHint(kind: gesture)
                    .id(tour.step)
                    .position(x: spot.midX, y: spot.midY)
            }

            Halo(shape: outline, isDone: tour.isDone)
                .frame(width: spot.width + 10, height: spot.height + 10)
                .position(x: spot.midX, y: spot.midY)
                .allowsHitTesting(false)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // The app's own section rule, the one it uses on every panel, with
            // the step's count where a panel puts its label. The card used to
            // open with a coloured disc and a symbol in it, which is furniture
            // from a different app: nothing in Reedar is a badge, everything is
            // either engraved, milled, or a key you can press.
            HStack(spacing: 10) {
                Text(showsDone ? "Done" : "Step \(tour.step.rawValue + 1) of \(Tour.Step.allCases.count)")
                    .microLabel(showsDone ? Palette.signalGreen : Palette.inkSecondary)
                Rectangle()
                    .fill(Palette.hairline)
                    .frame(height: 1)
                Button { tour.skip() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.inkTertiary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("End the tour")
            }

            // How far through, drawn by the same bar that shows how much life
            // is left in a reed. One component, two honest uses.
            LEDBar(progress: progress, segments: Tour.Step.allCases.count,
                   height: 7, tint: showsDone ? Palette.signalGreen : Palette.accent)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title(20))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(blurb)
                    .font(.copy(14.5))
                    .foregroundStyle(Palette.ink.opacity(0.88))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    // Room for three lines whatever the step says, so the card
                    // is the same size on every one of them.
                    .frame(minHeight: 60, alignment: .top)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            keys
        }
        .padding(16)
        .raised(depth: .high)
        .shadow(color: .black.opacity(0.65), radius: 28, y: 14)
        .padding(.horizontal, Metrics.screenMargin)
        .column()
    }

    /// Two keys, cut from the same stock as the plate's, and a way past.
    ///
    /// Next only lights up once the step has been done. Before that it is a
    /// dead key and Skip is the honest way on — the difference between "I have
    /// done this" and "I would rather not" is worth a control each.
    private var keys: some View {
        HStack(spacing: 10) {
            Button { tour.back() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 46, height: 44)
            }
            .buttonStyle(.key)
            .opacity(tour.canGoBack ? 1 : 0.3)
            .disabled(!tour.canGoBack)
            .accessibilityLabel("Back a step")

            if !unlocked {
                Button("Skip") { tour.advance() }
                    .font(.copy(13.5))
                    .foregroundStyle(Palette.inkTertiary)
                    .frame(height: 44)
                    .padding(.horizontal, 4)
            }

            Spacer(minLength: 0)

            Button { tour.advance() } label: {
                HStack(spacing: 7) {
                    Text(tour.step == .done ? "Add my first reed" : "Next")
                    Image(systemName: tour.step == .done ? "plus" : "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .font(.heading(15))
                .foregroundStyle(unlocked ? Palette.onAccent : Palette.inkTertiary)
                .padding(.horizontal, 18)
                .frame(height: 44)
            }
            .buttonStyle(.key(tint: unlocked ? Palette.accent : nil))
            .disabled(!unlocked)
            .animation(.settle, value: unlocked)
        }
    }

    /// The last step has nothing to do but leave, so its key is always live.
    private var unlocked: Bool { tour.isDone || tour.step == .done }

    /// Filled through the step you are on, not the one after it.
    private var progress: Double {
        Double(tour.step.rawValue + 1) / Double(Tour.Step.allCases.count)
    }

    private var showsDone: Bool { tour.isDone }

    private var title: String {
        showsDone ? "That's it" : tour.step.title
    }

    private var blurb: String {
        if showsDone { return tour.step.done }
        if let detail = tour.detail { return detail }
        if let hint = tour.step.sheetHint { return hint }
        return tour.step.blurb
    }
}

/// A label with its symbol on the right, for anything that means "onward".
private struct TrailingIcon: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.title
            configuration.icon.font(.system(size: 11, weight: .bold))
        }
    }
}
