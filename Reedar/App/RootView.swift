import SwiftData
import SwiftUI

/// There is one screen: the case. Everything else is reached through a reed,
/// or through the single button in the corner.
struct RootView: View {
    /// Cold launch only. `RootView` is built once per process, so this starting
    /// value can't come back after the veil has gone — returning from the
    /// background doesn't rebuild the view, and so doesn't show it again.
    @State private var showingVeil = true

    /// Whether the introduction has been seen.
    ///
    /// Kept in `UserDefaults` rather than in the store on purpose: it is a fact
    /// about this installation, not about the player's reeds, and it has no
    /// business syncing to another device that has its own first launch to do.
    @AppStorage(Intro.seenKey) private var hasSeenIntro = false

    @State private var showingIntro = false
    /// Set when the introduction ends on "Add your first reed", and read once
    /// by the case, which owns the add flow.
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
            // After the veil, not under it. Two things arriving over the case at
            // once is two things nobody watched.
            .onChange(of: showingVeil) { _, veiled in
                guard !veiled, !hasSeenIntro else { return }
                showingIntro = true
            }
            .fullScreenCover(isPresented: $showingIntro) {
                IntroView { addReed in
                    hasSeenIntro = true
                    showingIntro = false
                    startAdding = addReed
                }
            }
            .task {
                // Seeing it again on demand, from Settings or the simulator —
                // and getting past it, for looking at a first-run case that
                // still has its slip of paper in it.
                let arguments = ProcessInfo.processInfo.arguments
                if arguments.contains("-resetIntro") { hasSeenIntro = false }
                if arguments.contains("-skipIntro") { hasSeenIntro = true }
            }
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
