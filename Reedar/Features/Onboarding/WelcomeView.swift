import SwiftUI

/// The one screen before the app, and the only part of onboarding that is a
/// screen at all.
///
/// It earns that by doing the job the app can't do for itself: somebody who has
/// just paid for this deserves the promise restated in a sentence before being
/// asked to do anything. Everything after it is the app — the add flow is four
/// big questions asked one at a time, which teaches more than a tour could.
///
/// The hero is the case, drawn by the case's own components, with the reeds
/// laid into it one after another as the screen arrives. It is the app's one
/// piece of theatre and it lasts under a second: three reeds going into a case,
/// which is exactly what the app is for. Nothing is faked for it — those are
/// `SlotMoulding` and `ReedRow`, the same views the case itself is built from,
/// so the first thing anybody sees is the thing they are about to use.
struct WelcomeView: View {
    var begin: () -> Void
    var skip: () -> Void

    /// How many reeds have been laid in. Drives the whole screen's arrival.
    @State private var laid = 0

    private var settled: Bool { laid >= Self.reeds.count }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            hero.padding(.bottom, 32)

            VStack(spacing: 12) {
                Wordmark(size: 29)

                Text("Know how long your reeds really last")
                    .font(.title(25))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)

                Text("Log what you play, retire a reed when it's done, and Reedar "
                     + "works out what your reeds actually last you — by brand, "
                     + "model and strength.")
                    .font(.copy(15))
                    .foregroundStyle(Palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(settled ? 1 : 0)
            .animation(.settle.delay(0.1), value: settled)

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                PrimaryKey(title: "Add my first reed", symbol: "plus") { begin() }
                Button("Have a look round first") { skip() }
                    .font(.copy(14))
                    .foregroundStyle(Palette.inkSecondary)
            }
            .opacity(settled ? 1 : 0)
            .animation(.settle.delay(0.22), value: settled)
        }
        .padding(.horizontal, Metrics.screenMargin)
        .padding(.vertical, 40)
        .column()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { Backdrop() }
        .task { lay() }
    }

    /// Three bays, filling up.
    private var hero: some View {
        VStack(spacing: 8) {
            ForEach(Array(Self.reeds.enumerated()), id: \.offset) { index, reed in
                SlotMoulding(index: index, isEmpty: index >= laid) {
                    if index < laid {
                        ReedRow(reed: reed, estimate: Self.estimate,
                                isNextUp: index == 0)
                            // In from the tip end — a reed is laid into a case,
                            // not dropped into it.
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .aspectRatio(Metrics.reedLyingAspect, contentMode: .fit)
            }
        }
        .frame(maxWidth: 330)
    }

    /// One reed, then the next. Slow enough to watch, over before anybody
    /// waiting for a button has begun to mind.
    private func lay() {
        guard laid == 0 else { return }
        for index in Self.reeds.indices {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(280 + index * 160))
                withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                    laid = index + 1
                }
                Haptics.slotTapped()
            }
        }
    }

    // MARK: The reeds in the picture

    /// Plain `Reed` values, never inserted into a context: the picture needs
    /// reeds and the player's store must not gain any.
    private static func reed(_ brand: String, _ model: String, _ strength: String,
                             _ nickname: String, minutes: Int) -> Reed {
        let reed = Reed(brandID: "welcome", brandName: brand,
                        modelID: "welcome", modelName: model,
                        strength: Strength(label: strength, value: 0, scale: .halfStep),
                        instrument: .altoSax, nickname: nickname)
        reed.sessions = [PlaySession(totalMinutes: minutes, playingMinutes: minutes,
                                     reed: reed)]
        return reed
    }

    private static let reeds = [
        reed("Vandoren", "Java Red", "2½", "Java #3", minutes: 348),
        reed("D'Addario", "Select Jazz", "2M", "", minutes: 192),
        reed("Vandoren", "V16", "3", "", minutes: 14),
    ]

    private static let estimate = LifespanEstimate(minutes: 540, sampleCount: 3,
                                                   source: "your Vandoren Java Red")
}

#Preview {
    WelcomeView(begin: {}, skip: {})
        .preferredColorScheme(.dark)
        .tint(Palette.accent)
}
