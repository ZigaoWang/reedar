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
            // The case is already there behind the veil, held just barely back.
            // It settles forward as the veil lifts — enough to read as depth,
            // not enough to notice as an effect.
            .scaleEffect(showingVeil ? 0.98 : 1)
            .animation(.easeOut(duration: 0.5), value: showingVeil)
            .overlay {
                if showingVeil {
                    LaunchVeil(isPresented: $showingVeil)
                        .transition(.opacity)
                }
            }
    }
}

#Preview {
    RootView()
        .modelContainer(ModelContainer.preview())
}
