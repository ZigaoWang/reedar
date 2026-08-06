import SwiftUI

/// The mark held over a black screen for a moment on cold launch, then handed
/// off to the case.
///
/// The system launch screen this app generates is plain black, and so is the
/// veil, so there is no visible seam between them — the mark simply appears on
/// a screen that was already there.
///
/// One motion, once. The mark and the name come in together on a single spring
/// with the haptic swell under them, sit still, and go. Nothing arrives on its
/// own schedule and nothing is staged against anything else.
///
/// Two rules keep this from becoming the splash screen everyone hates:
///
/// - It never gates the app. The case is live underneath from the first frame;
///   the veil is an overlay that stops taking hits the instant the fade starts.
/// - It yields. A tap dismisses it early, and Reduce Motion skips it outright.
struct LaunchVeil: View {
    /// The one motion in.
    static let rise: TimeInterval = 0.55
    /// How long it sits before it leaves.
    static let hold: Duration = .milliseconds(900)
    /// How long the hand-off to the case takes.
    static let fade: TimeInterval = 0.45

    @Binding var isPresented: Bool

    /// Drives the entrance only. Separate from `isPresented` so arriving and
    /// leaving can carry different curves.
    @State private var hasArrived = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Opaque, so the case underneath never shows through early.
            Palette.ground
                .ignoresSafeArea()

            VStack(spacing: 15) {
                LogoMark(size: 88)
                Text("Reedar")
                    .font(.title(18))
                    .foregroundStyle(Palette.ink)
                    .tracking(0.4)
            }
            // The whole mark as one object: up, forward, and into focus.
            .opacity(hasArrived ? 1 : 0)
            .scaleEffect(hasArrived ? 1 : 0.96)
            .offset(y: hasArrived ? 0 : 12)
            // Set above true centre. Optically centred beats measured centre
            // here: the name hangs below the mark, so a mathematically centred
            // group sits low.
            .offset(y: -64)
        }
        // Set against the bottom edge rather than under the mark, so it reads
        // as a colophon and leaves the mark alone. It carries the same fade as
        // everything else — there is still only one motion here.
        .overlay(alignment: .bottom) {
            Text("© \(Self.year) Zigao Wang")
                .font(.copy(11))
                .foregroundStyle(Palette.inkTertiary)
                .opacity(hasArrived ? 1 : 0)
                .padding(.bottom, 26)
        }
        // The case is already interactive underneath — the veil only swallows
        // taps while it's fully opaque, and a tap is a request to skip it.
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .task { await run() }
    }

    private func run() async {
        guard !reduceMotion else {
            isPresented = false
            return
        }

        // A damped spring reaches its target at roughly four fifths of its
        // response, so that is where the haptic sets the mark down. Both come
        // off the same number and stay in step if it is ever retuned.
        Haptics.launched(landing: Self.rise * 0.8)
        withAnimation(.spring(response: Self.rise, dampingFraction: 0.82)) {
            hasArrived = true
        }

        try? await Task.sleep(for: .seconds(Self.rise) + Self.hold)
        dismiss()
    }

    private func dismiss() {
        guard isPresented else { return }
        withAnimation(.easeOut(duration: Self.fade)) { isPresented = false }
    }

    private static var year: String {
        String(Calendar.current.component(.year, from: Date()))
    }
}

#Preview {
    LaunchVeil(isPresented: .constant(true))
}
