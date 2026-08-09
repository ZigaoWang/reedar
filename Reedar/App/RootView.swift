import SwiftData
import SwiftUI

/// There is one screen: the case. Everything else is reached through a reed,
/// or through the single button in the corner.
struct RootView: View {
    /// Cold launch only. `RootView` is built once per process, so this starting
    /// value can't come back after the veil has gone — returning from the
    /// background doesn't rebuild the view, and so doesn't show it again.
    @State private var showingVeil = true

    /// Whether the welcome has been seen.
    ///
    /// Kept in `UserDefaults` rather than in the store on purpose: it is a fact
    /// about this installation, not about the player's reeds, and it has no
    /// business syncing to another device that has its own first launch to do.
    @AppStorage(Intro.seenKey) private var hasSeenIntro = false

    @State private var showingWelcome = false
    /// Set when the welcome hands over, and read once by the case, which owns
    /// the add flow.
    @State private var startAdding = false

    var body: some View {
        CaseView(startAdding: $startAdding)
            // One appearance, always. A reed case is black.
            .preferredColorScheme(.dark)
            .tint(Palette.accent)
            .task { Haptics.warmUp() }
            // Nothing here transforms the case, and nothing here transforms the
            // veil's black either. Both were tried and both were wrong: a scale
            // is a geometry effect, and under one SwiftUI stops honouring the
            // `ignoresSafeArea(edges: .bottom)` the case is built on. The case
            // spent the whole veil 34pt short and grew into the home indicator
            // the frame the scale reached 1 — mouldings snapping to their new
            // height, reeds springing after them. That was the jolt a moment
            // after the splash.
            //
            // So the veil is mounted and unmounted, nothing more. It runs its
            // own fade internally and only asks to be taken down once it is
            // already invisible, which is why there is no transition here.
            .overlay {
                if showingVeil {
                    LaunchVeil(isPresented: $showingVeil)
                }
            }
            // One screen, and then the app. It restates what somebody has just
            // paid for and hands them to the only thing there is to do with an
            // empty case: put a reed in it.
            //
            // There was a guided tour here for a while — a case of borrowed
            // reeds, a light on the thing to press, a card that followed you
            // into every sheet. It came to eight hundred lines and hooks in
            // nine files to explain an app with one screen and two gestures,
            // and the add flow it finally handed you to is already four big
            // questions asked one at a time. That flow is the teaching. This
            // is only the door.
            .fullScreenCover(isPresented: $showingWelcome) {
                WelcomeView {
                    finish(addReed: true)
                } skip: {
                    finish(addReed: false)
                }
                .preferredColorScheme(.dark)
                .tint(Palette.accent)
            }
            // After the veil, not under it.
            .onChange(of: showingVeil) { _, veiled in
                guard !veiled, !hasSeenIntro else { return }
                showingWelcome = true
            }
            // And whenever the flag is cleared, which is what Settings does.
            // Watching only the veil meant "Show the welcome again" set a flag
            // nobody was listening to any more: it worked perfectly on the next
            // cold launch and did nothing at all when you pressed it.
            .onChange(of: hasSeenIntro) { _, seen in
                guard !seen, !showingVeil else { return }
                showingWelcome = true
            }
    }

    private func finish(addReed: Bool) {
        showingWelcome = false
        hasSeenIntro = true
        startAdding = addReed
    }
}

/// Where the one preference lives, named once so the view that writes it and
/// the screen that offers to show it again can't disagree about the spelling.
enum Intro {
    static let seenKey = "hasSeenIntro"
}

#Preview {
    RootView()
        .modelContainer(ModelContainer.preview())
}
