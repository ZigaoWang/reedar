import SwiftUI

/// Everything the player gets to decide: what the case is moulded in, what
/// it's trimmed with, whether it answers your hand, and whether to see the
/// introduction again.
///
/// The last of those is why this screen existed before there was anything to
/// put on it — an app that shows you something once and then has no way back
/// to it has taken a decision on your behalf.
struct SettingsView: View {
    @AppStorage(Intro.seenKey) private var hasSeenIntro = false
    @AppStorage(Appearance.key) private var appearance: Appearance = .dark
    @AppStorage(Accent.key) private var accent: Accent = .orange
    @AppStorage(Haptics.key) private var haptics = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                appearanceSection
                accentSection

                section("Feedback") {
                    // A tick on the way on, nothing on the way off. Turning a
                    // feedback setting on is the one moment where feeling the
                    // thing you just enabled is the whole answer; turning it
                    // off and getting a buzz for your trouble is the app
                    // arguing with you.
                    Toggle(isOn: $haptics.animation(.mechanical)) {
                        HStack(spacing: 11) {
                            Image(systemName: "hand.tap")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Palette.inkSecondary)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Haptics")
                                    .font(.heading(15))
                                    .foregroundStyle(Palette.ink)
                                Text("A lid closing, a reed dropping into a slot")
                                    .font(.copy(12))
                                    .foregroundStyle(Palette.inkTertiary)
                            }
                        }
                    }
                    .tint(Palette.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .onChange(of: haptics) { _, on in
                        if on { Haptics.reedAdded() }
                    }
                }

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

    /// Six discs of the colour itself.
    ///
    /// No names on them. "Rust" and "Amber" are words for a colour you are
    /// already looking at, and six of them in a row is a list to read rather
    /// than a set to choose from — the swatch is the label. The names stay in
    /// `Accent` for the accessibility label, which is the one place a word is
    /// the only thing there is.
    private var accentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accent")
                .microLabel()
                .padding(.leading, 4)
            Panel(padding: 14) {
                HStack(spacing: 0) {
                    ForEach(Accent.allCases) { option in
                        Button {
                            accent = option
                            Haptics.tick()
                        } label: {
                            swatch(option)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(option.displayName)
                        .accessibilityAddTraits(accent == option ? [.isSelected] : [])
                    }
                }
            }
        }
    }

    /// The disc, and a ring standing off it when it's the one in use. A ring
    /// rather than a tick: a tick has to be drawn in something, and there is no
    /// colour that reads on all six.
    private func swatch(_ option: Accent) -> some View {
        let colour = Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .light
                    ? option.light.body : option.dark.body)
        })
        return Circle()
            .fill(colour)
            .frame(width: 30, height: 30)
            .overlay {
                Circle().strokeBorder(Palette.hairline, lineWidth: 1)
            }
            .padding(4)
            .overlay {
                Circle()
                    .strokeBorder(accent == option ? colour : .clear, lineWidth: 2)
            }
            .animation(.mechanical, value: accent)
            .contentShape(Circle())
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
