import SwiftUI

/// The first thing anybody sees, once.
///
/// The app was built without one on the argument that a case explains itself,
/// and that is true of the case and not true of everything behind it: nothing
/// on a first launch says why you would log a session, and the one screen that
/// pays you back for logging them is empty until you have retired a reed. So
/// this restates the promise in a sentence, shows the two things you do to a
/// reed, and then gets out of the way by handing straight over to adding one.
///
/// Three rules it holds itself to. It is skippable from the first frame — the
/// Skip is in the bar, not buried on the last page. It never explains anything
/// twice, so the tour is three beats and not five. And it shows the real
/// components rather than pictures of them: the bay below is `SlotMoulding`,
/// the reed is `ReedRow`, both exactly as the case draws them, so what you
/// learn here is what you meet a second later.
struct IntroView: View {
    /// Called when the player is finished, with whether they want to go
    /// straight on to adding their first reed.
    var finish: (_ addReed: Bool) -> Void

    @State private var page: Page = Self.startPage

    private enum Page: Int, CaseIterable {
        case promise, theCase, logging, lifespan
    }

    /// `-introPage 2` opens straight onto the second screen, so a page can be
    /// looked at without walking through the ones before it. Same habit as the
    /// case's `-openStats` and friends.
    private static var startPage: Page {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-introPage"),
              arguments.indices.contains(flag + 1),
              let number = Int(arguments[flag + 1]),
              let page = Page(rawValue: number - 1)
        else { return .promise }
        return page
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                heading
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { Backdrop() }
            .safeAreaInset(edge: .bottom) { footer }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if page != .promise {
                        Button {
                            back()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                                .font(.copy(15))
                                .foregroundStyle(Palette.inkSecondary)
                        }
                    }
                }
                // Always, from the first frame. An introduction you can't leave
                // is a wall, and the people most likely to want out are the
                // ones who already know what a reed case is.
                ToolbarItem(placement: .confirmationAction) {
                    Button("Skip") { finish(false) }
                        .font(.copy(15))
                        .foregroundStyle(Palette.inkSecondary)
                }
                ToolbarItem(placement: .principal) { lamps }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Palette.accent)
    }

    // MARK: Where you are

    /// Three lamps rather than three dots. The app already has an `LED`, and a
    /// row of them is what the front of a piece of hardware uses to tell you
    /// which of three things it is doing.
    private var lamps: some View {
        HStack(spacing: 6) {
            ForEach(Page.allCases, id: \.rawValue) { step in
                LED(isOn: step == page, size: 6)
            }
        }
        .animation(.mechanical, value: page)
        .accessibilityLabel("Step \(page.rawValue + 1) of \(Page.allCases.count)")
    }

    // MARK: Words

    private var heading: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title(28))
                .foregroundStyle(Palette.ink)
            Text(blurb)
                .font(.copy(15))
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Metrics.screenMargin)
        .padding(.top, 4)
        .padding(.bottom, 22)
        .column()
    }

    private var title: String {
        switch page {
        case .promise: "Know how long your reeds really last"
        case .theCase: "Your case, on your phone"
        case .logging: "Log a session in three taps"
        case .lifespan: "Retire it, and it teaches the app"
        }
    }

    /// One sentence each. Anything longer is a manual, and nobody reads the
    /// manual for a box with eight reeds in it.
    private var blurb: String {
        switch page {
        case .promise:
            "Log what you play, retire a reed when it's done, and Reedar works "
            + "out how long your reeds actually last you — by brand, model and "
            + "strength."
        case .theCase:
            "Eight slots. Tap a reed to open it, press and drag to move it, and "
            + "tap any empty slot to put a new reed in."
        case .logging:
            "How long you played and what it was. A rehearsal isn't two hours of "
            + "wear on a reed, so Reedar counts the part you spent actually "
            + "blowing \u{2014} and you can always overrule it."
        case .lifespan:
            "Finished reeds go to the archive, and what they lasted becomes your "
            + "own average \u{2014} on the Lifespan screen, behind the chart key at "
            + "the top of your case."
        }
    }

    // MARK: Pictures, made of the real thing

    @ViewBuilder private var content: some View {
        switch page {
        case .promise: promisePicture
        case .theCase: casePicture
        case .logging: loggingPicture
        case .lifespan: lifespanPicture
        }
    }

    /// The mark, big, and nothing else. This page is a sentence; a diagram
    /// under it would be a diagram of a sentence.
    private var promisePicture: some View {
        VStack(spacing: 16) {
            LogoMark(size: 96)
                .shadow(color: .black.opacity(0.5), radius: 18, y: 9)
            Wordmark(size: 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Three bays with two reeds in them: the case, in miniature, drawn by the
    /// case's own components. The empty third bay is the point of the picture —
    /// it's the thing the sentence above tells you to tap.
    private var casePicture: some View {
        VStack(spacing: 8) {
            ForEach(Self.sample.indices, id: \.self) { index in
                SlotMoulding(index: index, isEmpty: Self.sample[index] == nil) {
                    if let reed = Self.sample[index] {
                        ReedRow(reed: reed, estimate: Self.estimate,
                                isNextUp: index == 0)
                    }
                }
                .aspectRatio(Metrics.reedLyingAspect, contentMode: .fit)
            }
        }
        .padding(.horizontal, Metrics.screenMargin)
        .column()
        .frame(maxHeight: .infinity, alignment: .center)
    }

    /// The log, as it appears on a reed's own page, and the key that fills it.
    private var loggingPicture: some View {
        VStack(spacing: Metrics.stack) {
            PrimaryKey(title: "Log session", symbol: "plus") {}
                .allowsHitTesting(false)

            Panel {
                VStack(alignment: .leading, spacing: 9) {
                    RuleHeader("Log", trailing: "3.4h total")
                    logRow("Rehearsal", "Thursday", "2h", playing: "54m")
                    Divider().overlay(Palette.hairline)
                    logRow("Practice", "Tuesday", "45m", playing: "38m")
                }
            }
        }
        .padding(.horizontal, Metrics.screenMargin)
        .column()
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private func logRow(_ kind: String, _ day: String,
                        _ total: String, playing: String) -> some View {
        HStack(spacing: 11) {
            VStack(alignment: .leading, spacing: 2) {
                Text(kind)
                    .font(.heading(14))
                    .foregroundStyle(Palette.ink)
                Text("\(day) · \(total) total")
                    .font(.copy(11.5))
                    .foregroundStyle(Palette.inkTertiary)
            }
            Spacer(minLength: 8)
            Text(playing)
                .font(.numeric(14))
                .foregroundStyle(Palette.ink)
        }
        .padding(.vertical, 2)
    }

    /// What the logging is *for*: a reed part-worn, with its life drawn on it,
    /// and the two keys that hold everything a finished reed leaves behind.
    private var lifespanPicture: some View {
        VStack(spacing: Metrics.stack) {
            SlotMoulding(index: 0, isEmpty: false) {
                ReedRow(reed: Self.wornReed, estimate: Self.estimate, isNextUp: true)
            }
            .aspectRatio(Metrics.reedLyingAspect, contentMode: .fit)

            Panel {
                VStack(alignment: .leading, spacing: 11) {
                    RuleHeader("Life", trailing: "9.0h expected")
                    LEDBar(progress: 0.62, segments: 18, height: 9)
                    Text("About 3h 25m left. 9h is the average for your Vandoren "
                         + "Java Red, from 3 reeds.")
                        .font(.copy(12))
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // The two keys as they sit on the plate, so the sentence above has
            // something to point at.
            HStack(spacing: 12) {
                keyLegend("archivebox", "Retired reeds")
                keyLegend("chart.bar", "Lifespan")
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, Metrics.screenMargin)
        .column()
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private func keyLegend(_ symbol: String, _ label: String) -> some View {
        HStack(spacing: 9) {
            IconKey(symbol: symbol, tint: nil, size: 42, label: label) {}
                .allowsHitTesting(false)
            Text(label)
                .font(.copy(12.5))
                .foregroundStyle(Palette.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Going on

    private var footer: some View {
        VStack(spacing: 10) {
            PrimaryKey(title: page == .lifespan ? "Add your first reed" : "Next",
                       symbol: page == .lifespan ? "plus" : nil) {
                advance()
            }
            // Only where it means something different from Skip: on the last
            // page, Skip in the bar and "not now" at the bottom are the same
            // answer, and the bottom one is the one a thumb reaches.
            if page == .lifespan {
                Button("I'll add one later") { finish(false) }
                    .font(.copy(14))
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
        .padding(.horizontal, Metrics.screenMargin)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .column()
        .background(.bar)
    }

    private func advance() {
        Haptics.tick()
        withAnimation(.mechanical) {
            if let next = Page(rawValue: page.rawValue + 1) {
                page = next
            } else {
                finish(true)
            }
        }
    }

    private func back() {
        Haptics.tick()
        withAnimation(.mechanical) {
            page = Page(rawValue: page.rawValue - 1) ?? .promise
        }
    }

    // MARK: The reeds in the pictures

    /// Plain `Reed` values, never inserted into a context. The pictures need
    /// reeds to draw and the player hasn't got any yet; building them here
    /// keeps the introduction from touching the store at all, so nothing it
    /// shows can end up in somebody's case.
    private static func reed(_ brand: String, _ model: String, _ strength: String,
                             nickname: String = "", minutes: Int = 0) -> Reed {
        let reed = Reed(
            brandID: "intro", brandName: brand,
            modelID: "intro", modelName: model,
            strength: Strength(label: strength, value: 0, scale: .halfStep),
            instrument: .altoSax,
            nickname: nickname
        )
        // Hours are the sum of a reed's sessions, so a part-worn reed has to be
        // shown the way a real one gets there: by having played.
        if minutes > 0 {
            reed.sessions = [PlaySession(totalMinutes: minutes, playingMinutes: minutes,
                                         reed: reed)]
        }
        return reed
    }

    private static let sample: [Reed?] = [
        reed("Vandoren", "Java Red", "2½", nickname: "Java #3", minutes: 95),
        reed("D'Addario", "Select Jazz", "2M", minutes: 190),
        nil,
    ]

    private static let wornReed = reed("Vandoren", "Java Red", "2½",
                                       nickname: "Java #3", minutes: 335)

    private static let estimate = LifespanEstimate(minutes: 540, sampleCount: 3,
                                                   source: "your Vandoren Java Red")
}

#Preview {
    IntroView { _ in }
        .preferredColorScheme(.dark)
}
