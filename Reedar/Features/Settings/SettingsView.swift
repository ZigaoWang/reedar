import SwiftUI

/// Everything the player gets to decide.
///
/// Which is, for now, one thing. The screen exists anyway rather than waiting
/// until there are three: the introduction can be shown again, and an app that
/// shows you something once and then has no way back to it has taken a decision
/// on your behalf. The accessibility choices land here next.
struct SettingsView: View {
    @AppStorage(Intro.seenKey) private var hasSeenIntro = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                section("Introduction") {
                    Button {
                        Haptics.tick()
                        hasSeenIntro = false
                        dismiss()
                    } label: {
                        row(symbol: "play.circle",
                            title: "Show the introduction again",
                            detail: "Three screens, then back to your case")
                    }
                    .buttonStyle(.sink)
                }
            }
            .padding(.horizontal, Metrics.screenMargin)
            .column()
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background { Backdrop() }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    /// A labelled group, matching About's — the two screens are siblings now
    /// and should not each have invented their own idea of a section.
    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .microLabel()
                .padding(.leading, 4)
            Panel(padding: 0) { content() }
        }
    }

    private func row(symbol: String, title: String, detail: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.inkSecondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.heading(15))
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(.copy(12))
                    .foregroundStyle(Palette.inkTertiary)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .preferredColorScheme(.dark)
        .tint(Palette.accent)
}
