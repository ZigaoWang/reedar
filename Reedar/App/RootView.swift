import SwiftData
import SwiftUI

/// There is one screen: the case. Everything else is reached through a reed,
/// or through the single button in the corner.
struct RootView: View {
    /// Cold launch only. `RootView` is built once per process, so this starting
    /// value can't come back after the veil has gone — returning from the
    /// background doesn't rebuild the view, and so doesn't show it again.
    @State private var showingVeil = true

    var body: some View {
        CaseView()
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
    }
}

#Preview {
    RootView()
        .modelContainer(ModelContainer.preview())
}
