import SwiftUI

/// Everything the player gets to decide.
///
/// Which is, for now, two things: the material the case is moulded in, and
/// whether to see the introduction again. An app that shows you something once
/// and then has no way back to it has taken a decision on your behalf.
struct SettingsView: View {
    @AppStorage(Intro.seenKey) private var hasSeenIntro = false
    @AppStorage(Appearance.key) private var appearance: Appearance = .dark
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                appearanceSection

                section("Welcome") {
                    Button {
                        Haptics.tick()
                        hasSeenIntro = false
                        dismiss()
                    } label: {
                        row(symbol: "play.circle",
                            title: "Show the welcome again",
                            detail: "The one screen you saw on first launch")
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

    /// Three keys, and the case changes under them as you press.
    ///
    /// No preview swatch and no confirmation: the setting is the whole screen
    /// behind it, and it redraws before your finger is off the key. A picture
    /// of a theme, next to the theme, is a picture of what you are already
    /// looking at.
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Appearance")
                .microLabel()
                .padding(.leading, 4)
            Panel(padding: 14) {
                // Three words on three keys, and nothing else. The glyph over
                // each legend is the style this app uses for *answers* to a
                // question — a sun and a moon stacked above "Light" and "Dark"
                // illustrate the words rather than adding to them, and they
                // pushed the key tall enough to look like a form. A caption
                // under them said what the three words say.
                KeySelector(
                    values: Appearance.allCases,
                    selection: $appearance,
                    title: { $0.displayName },
                    columns: 3,
                    height: 46
                )
            }
        }
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
