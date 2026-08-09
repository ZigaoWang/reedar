import SwiftUI

/// The screen that says whose reeds these are, before you ever see them.
///
/// It was a pill floating over the case. A caption is the wrong shape for this:
/// somebody opening a paid app for the first time and finding three saxophone
/// reeds they didn't put there needs a sentence, not a badge — and the badge
/// covered the app's own name to deliver it.
///
/// So it gets a screen of its own, between the welcome and the tour, and then
/// nothing has to nag about it afterwards.
struct DemoNoticeView: View {
    var begin: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // The case in miniature, drawn by the case's own components, so the
            // thing being described is the thing you're about to see.
            VStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { index in
                    SlotMoulding(index: index, isEmpty: index == 2) {
                        if index < 2 {
                            ReedRow(reed: Self.reeds[index], estimate: Self.estimate)
                        }
                    }
                    .aspectRatio(Metrics.reedLyingAspect, contentMode: .fit)
                }
            }
            .frame(maxWidth: 320)
            .padding(.bottom, 34)

            VStack(spacing: 14) {
                Text("Here's a practice case")
                    .font(.title(27))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)

                Text("None of these reeds are yours.")
                    .font(.heading(16))
                    .foregroundStyle(Palette.accent)

                Text("Play with them however you like — move them, log a session, "
                     + "retire one. They vanish when the tour ends, and then you "
                     + "put your own reeds in.")
                    .font(.copy(15))
                    .foregroundStyle(Palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            PrimaryKey(title: "Start the tour") { begin() }
        }
        .padding(.horizontal, Metrics.screenMargin)
        .padding(.vertical, 40)
        .column()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { Backdrop() }
    }

    // Unsaved, uninserted: the picture needs reeds and the store must not.
    private static func reed(_ brand: String, _ model: String, _ strength: String,
                             _ nickname: String, minutes: Int) -> Reed {
        let reed = Reed(brandID: "demo", brandName: brand,
                        modelID: "demo", modelName: model,
                        strength: Strength(label: strength, value: 0, scale: .halfStep),
                        instrument: .altoSax, nickname: nickname)
        reed.sessions = [PlaySession(totalMinutes: minutes, playingMinutes: minutes,
                                     reed: reed)]
        return reed
    }

    private static let reeds = [
        reed("Vandoren", "Java Red", "2½", "Java #3", minutes: 95),
        reed("D'Addario", "Select Jazz", "2M", "", minutes: 190),
    ]
    private static let estimate = LifespanEstimate(minutes: 540, sampleCount: 3,
                                                   source: "your Vandoren Java Red")
}

#Preview {
    DemoNoticeView {}
        .preferredColorScheme(.dark)
        .tint(Palette.accent)
}
