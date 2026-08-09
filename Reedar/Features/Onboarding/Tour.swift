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
        else { return .welcome }
        return step
    }()
    /// Whether the tour is running at all.
    var isRunning = false
    /// Raised on the last step when the player asks to add a reed for real.
    var wantsFirstReed = false

    enum Step: Int, CaseIterable {
        case welcome
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
            case .welcome, .done: nil
            case .dragAReed, .openAReed: .firstReed
            case .logASession: .logKey
            case .retireIt: .retireKey
            case .lifespan: .lifespanKey
            }
        }

        var title: String {
            switch self {
            case .welcome: "Have a look round"
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
            case .welcome:
                "There are a few reeds in this case so you can try things out. "
                + "None of them are yours — they go when the tour does."
            case .dragAReed:
                "Press a reed and drag it up or down. The others shuffle aside "
                + "to make room. Go on, try it."
            case .openAReed:
                "Tap a reed to open it. Everything you do happens to a reed, so "
                + "you pick one up first."
            case .logASession:
                "How long you played and what it was. A rehearsal isn't two "
                + "hours of wear, so Reedar counts the part you spent blowing."
            case .retireIt:
                "When a reed is finished, retire it. That is the moment the app "
                + "learns something — a reed that lasted you 9 hours."
            case .lifespan:
                "Every retired reed adds up here: how long each model really "
                + "lasts you, by brand and by strength."
            case .done:
                "The case, a reed, and the numbers behind it. Ready to put a "
                + "real one in?"
            }
        }

        /// The word on the key that moves on.
        var forward: String {
            switch self {
            case .welcome: "Show me"
            case .done: "Add my first reed"
            default: "Next"
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

    func advance() {
        Haptics.tick()
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

/// The dimming, the ring and the card.
///
/// The dimming is a shape with a hole cut in it — even-odd fill rather than a
/// blur or a mask, so the thing being pointed at is lit by the app's own
/// screen rather than by anything drawn on top of it. It takes no touches at
/// all: the tour describes gestures and you have to be able to make them while
/// it is still on screen, or the instruction is theatre.
struct TourOverlay: View {
    @Bindable var tour: Tour
    /// Where the current step's target is, if it is on this screen.
    var spot: CGRect?

    var body: some View {
        ZStack {
            dimming
            ring
            card
        }
        .transition(.opacity)
    }

    private var dimming: some View {
        Canvas { context, size in
            var shape = Path(CGRect(origin: .zero, size: size))
            if let spot {
                shape.addRoundedRect(in: spot.insetBy(dx: -6, dy: -6),
                                     cornerSize: CGSize(width: 14, height: 14))
            }
            context.fill(shape, with: .color(.black.opacity(0.72)), style: FillStyle(eoFill: true))
        }
        // The whole point: the app underneath stays usable while the tour talks
        // about it.
        .allowsHitTesting(false)
    }

    @ViewBuilder private var ring: some View {
        if let spot {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Palette.accent.opacity(0.9), lineWidth: 2)
                .frame(width: spot.width + 12, height: spot.height + 12)
                .position(x: spot.midX, y: spot.midY)
                .allowsHitTesting(false)
                .animation(.settle, value: spot)
        }
    }

    /// The words, on the far side of the screen from whatever is being pointed
    /// at, so the card never covers its own subject.
    private var card: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 9) {
                Text(tour.step.title)
                    .font(.heading(17))
                    .foregroundStyle(Palette.ink)
                Text(tour.step.blurb)
                    .font(.copy(13.5))
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button("Skip tour") { tour.skip() }
                        .font(.copy(13))
                        .foregroundStyle(Palette.inkTertiary)
                    Spacer(minLength: 8)
                    PrimaryKey(title: tour.step.forward) { tour.advance() }
                        .frame(maxWidth: 190)
                }
                .padding(.top, 3)
            }
            .padding(16)
            .raised(depth: .high)
            .shadow(color: .black.opacity(0.6), radius: 26, y: 12)
            .padding(.horizontal, Metrics.screenMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity,
                   alignment: cardIsHigh(in: geo.size) ? .top : .bottom)
            .padding(.vertical, 54)
        }
    }

    /// Above the target if the target is in the lower half, below it if not.
    private func cardIsHigh(in size: CGSize) -> Bool {
        guard let spot else { return false }
        return spot.midY > size.height * 0.55
    }
}
