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
            // The depth in the hand-off belongs to the veil, not to the case.
            //
            // The case used to be held back at 0.98 and released as the veil
            // lifted, which looked right and laid out wrong: a scale is a
            // geometry effect, and under one SwiftUI stops honouring the
            // `ignoresSafeArea(edges: .bottom)` the case is built on. The case
            // spent the whole veil 34pt short, and the frame the scale reached
            // 1 it grew into the home indicator — mouldings snapping to their
            // new height while the reeds sprang after them. That was the jolt
            // a moment after the splash.
            //
            // The veil carries the motion instead. Nothing under it is
            // transformed, so nothing under it is ever laid out twice.
            .overlay {
                if showingVeil {
                    LaunchVeil(isPresented: $showingVeil)
                        // It withdraws toward the viewer as it goes, which
                        // reads as the case settling forward without moving
                        // the case at all.
                        .transition(.opacity.combined(with: .scale(scale: 1.03)))
                        // Same reason, from the other side: the veil's own
                        // black is laid out to the glass here rather than
                        // inside it, so the transform can't leave a hairline
                        // of case showing along an edge.
                        .ignoresSafeArea()
                }
            }
    }
}

#Preview {
    RootView()
        .modelContainer(ModelContainer.preview())
}
