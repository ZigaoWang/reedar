import SwiftUI

/// The mark held over a black screen for a moment on cold launch, then handed
/// off to the case.
///
/// The system launch screen this app generates is plain black, and so is the
/// veil, so there is no visible seam between them — the mark simply appears on
/// a screen that was already there.
///
/// One motion, once, in one direction. The mark arrives a hair proud of the
/// screen and settles back into it, sits still, and keeps going the same way
/// as it fades. There is no rise, no drift, no second element on its own
/// schedule — a splash that performs is a splash you have to sit through, and
/// this one is done in a little over a second.
///
/// Two rules keep it from becoming the splash screen everyone hates:
///
/// - It never gates the app. The case is live underneath from the first frame;
///   the veil is an overlay that stops taking hits the instant the fade starts.
/// - It yields. A tap dismisses it early, and Reduce Motion skips it outright.
struct LaunchVeil: View {
    /// The one motion in.
    static let settle: TimeInterval = 0.5
    /// How long it sits before it leaves.
    static let hold: Duration = .milliseconds(550)
    /// How long the hand-off to the case takes.
    static let fade: TimeInterval = 0.4

    @Binding var isPresented: Bool

    @State private var phase = Phase.arriving

    /// The whole animation, as three rests rather than a pile of flags. Every
    /// value below is a function of this and nothing else, so there is no way
    /// to end up half in one state and half in another.
    private enum Phase {
        /// Black, with the mark not yet on it.
        case arriving
        /// The mark at rest, being read.
        case shown
        /// Faded out. Still mounted, so the fade has something to run on.
        case left
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Opaque until the hand-off, so the case underneath never shows
            // through early. It carries no transform at any point — scaling
            // this is what would pull it off the edges of the glass.
            Palette.ground
                .ignoresSafeArea()
                .opacity(phase == .left ? 0 : 1)

            VStack(spacing: 15) {
                LogoMark(size: 88)
                Wordmark(size: 20)
            }
            // Set above true centre. Optically centred beats measured centre
            // here: the name hangs below the mark, so a mathematically centred
            // group sits low.
            .offset(y: -64)
            .modifier(Mark(phase: phase))
        }
        // Set against the bottom edge rather than under the mark, so it reads
        // as a colophon and leaves the mark alone. It carries the same fade as
        // everything else — there is still only one motion here.
        .overlay(alignment: .bottom) {
            Text("© \(Self.year) Zigao Wang")
                .font(.copy(11))
                .foregroundStyle(Palette.inkTertiary)
                .opacity(phase == .shown ? 1 : 0)
                .padding(.bottom, 26)
        }
        // The case is already interactive underneath — the veil only swallows
        // taps while it's fully opaque, and a tap is a request to skip it.
        // The moment the fade starts it stops taking hits, so the last 0.4s of
        // the hand-off is time the case can already be used in.
        .contentShape(Rectangle())
        .allowsHitTesting(phase != .left)
        .onTapGesture { Task { await leave() } }
        .task { await run() }
    }

    /// The mark's own state: a shade forward on arrival, at rest while it's
    /// read, a shade further back as it goes. One axis, one direction, never
    /// reversing — that is the whole of what makes it feel settled rather
    /// than staged.
    private struct Mark: ViewModifier {
        var phase: Phase

        func body(content: Content) -> some View {
            content
                .opacity(phase == .shown ? 1 : 0)
                .scaleEffect(scale)
        }

        private var scale: CGFloat {
            switch phase {
            case .arriving: 1.03
            case .shown: 1
            case .left: 0.98
            }
        }
    }

    private func run() async {
        guard !reduceMotion else {
            isPresented = false
            return
        }

        // A damped spring reaches its target at roughly four fifths of its
        // response, so that is where the haptic sets the mark down. Both come
        // off the same number and stay in step if it is ever retuned.
        Haptics.launched(landing: Self.settle * 0.8)
        // Damped almost to the point of not being a spring at all. The mark is
        // arriving at a stop, not bouncing into one.
        withAnimation(.spring(response: Self.settle, dampingFraction: 0.92)) {
            phase = .shown
        }

        try? await Task.sleep(for: .seconds(Self.settle) + Self.hold)
        await leave()
    }

    /// Fades out in place, then asks to be taken down. Doing it in that order
    /// rather than handing the exit to a `transition` is what keeps the black
    /// untransformed, and it means a tap and the timer can't fight: whichever
    /// arrives second finds the veil already leaving and returns.
    private func leave() async {
        guard phase != .left else { return }
        withAnimation(.easeOut(duration: Self.fade)) { phase = .left }
        try? await Task.sleep(for: .seconds(Self.fade))
        isPresented = false
    }

    private static var year: String {
        String(Calendar.current.component(.year, from: Date()))
    }
}

#Preview {
    LaunchVeil(isPresented: .constant(true))
}
