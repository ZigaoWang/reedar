import SwiftData
import SwiftUI

/// There is one screen: the case. Everything else is reached through a reed,
/// or through the single button in the corner.
struct RootView: View {
    var body: some View {
        CaseView()
            // One appearance, always. A reed case is black.
            .preferredColorScheme(.dark)
            .tint(Palette.accent)
            .task { Haptics.warmUp() }
    }
}

#Preview {
    RootView()
        .modelContainer(ModelContainer.preview())
}
