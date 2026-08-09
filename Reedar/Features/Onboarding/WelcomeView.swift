import SwiftUI

/// Two screens before the app, and the only part of onboarding that is a
/// screen at all.
///
/// The first says hello and thank you — somebody has just paid for this and
/// opened it, and the least it can do is introduce itself before asking for
/// anything. The second says what it is for, with the case doing the talking.
/// Then it hands over to the add flow, which is four big questions asked one at
/// a time and teaches more than a tour could.
///
/// **Nothing animates itself.** Earlier versions had the three reeds rise into
/// place one after another, and a mark that sprang up with a band of light
/// sweeping across it. Both were motion for its own sake — the kind of thing
/// that looks designed for one second and looks cheap for ever after. A poster
/// does not assemble itself in front of you. It is already there, and good.
struct WelcomeView: View {
    /// Bound, not owned. See `RootView.welcomePage` for why: state kept in here
    /// outlives the cover it belongs to, and the welcome reopened on page two.
    @Binding var page: Page

    var begin: () -> Void
    var skip: () -> Void

    enum Page { case hello, what }

    var body: some View {
        // Two readers. The outer one sits inside the safe area purely to be
        // told where it is — a view that ignores the safe area is told its
        // insets are zero and can't ask. The inner one ignores it and so is
        // given the whole screen, which is what everything here is measured
        // from: both pages are laid out in fractions of the screen, because a
        // fixed inset that is a gap on a Pro Max is a third of an SE.
        GeometryReader { outer in
            GeometryReader { geo in
                ZStack {
                    Backdrop()
                    pages(in: geo.size, topInset: outer.safeAreaInsets.top)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .ignoresSafeArea()
        }
        .background { Backdrop() }
    }

    /// Both pages, side by side, and the screen is a window onto one of them.
    ///
    /// Not a view that is swapped for another with a transition. That was the
    /// first attempt and it had a fault you could only see mid-slide: SwiftUI
    /// re-evaluates the outgoing view while it leaves, so for a few frames the
    /// page on its way out was drawing the page that was arriving, and you got
    /// two copies of the same screen passing each other. Laid out side by side
    /// there is nothing to swap and nothing to re-evaluate — the only thing
    /// that changes is which half you are looking at, and the direction takes
    /// care of itself in both directions.
    private func pages(in size: CGSize, topInset: CGFloat) -> some View {
        HStack(spacing: 0) {
            page(.hello, in: size, topInset: topInset)
            page(.what, in: size, topInset: topInset)
        }
        .frame(width: size.width * 2, alignment: .leading)
        .offset(x: page == .hello ? 0 : -size.width)
        // Pinned back to one screen's width and clipped: without it the pair is
        // a child twice as wide as the phone, and a child that size drags the
        // layout of everything beside it out with it.
        .frame(width: size.width, alignment: .leading)
        .clipped()
    }

    private func turn(to next: Page) {
        Haptics.tick()
        // Even at both ends and over in under half a second: long enough not to
        // be a cut, short enough that nobody waits for it.
        withAnimation(.easeInOut(duration: 0.4)) { page = next }
    }

    @ViewBuilder
    private func page(_ page: Page, in size: CGSize,
                      topInset: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            // Each page carries its own ground now that the two of them sit
            // side by side. Sharing one behind both left the second page
            // transparent, and what showed through was the first page's reeds.
            Backdrop()

            if page == .hello {
                hero(in: size)
                    .frame(width: size.width, height: size.height)
                    // Flattened to a single picture.
                    //
                    // The field is around eighty views of gradient and type,
                    // and the page change slides the whole thing across the
                    // screen — which, live, is eighty things to lay out and
                    // draw every frame of the slide, and it showed. Drawn once
                    // into one layer, the slide moves a picture. The field
                    // never changes, so there is nothing lost by fixing it.
                    .drawingGroup()

                // The reeds run the whole height, so the words need their own
                // ground to stand on.
                scrim(for: size.height)
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                // The case is part of the block, not a picture floating behind
                // it.
                //
                // It used to be its own full-screen layer, hung from the top by
                // a fraction — which meant the gap between it and the words was
                // whatever was left over, and on an iPad that was a void. Set
                // here it keeps one measured gap on every screen, takes the
                // column's width rather than a phone's, and the slack collects
                // above it where slack belongs.
                if page == .what {
                    theCase
                        .frame(maxHeight: size.height * 0.40)
                        // The gap under the case is what lifts it: the block is
                        // anchored to the bottom, so padding here pushes the
                        // case up the screen and leaves the words where they
                        // are.
                        .padding(.bottom, size.height * 0.11)
                }

                words(for: page)
                footer(for: page).padding(.top, 20)
            }
            .padding(.horizontal, Metrics.screenMargin)
            // Near the glass, not on it. The words used to respect the bottom
            // safe area, which held the key a home indicator's height clear of
            // the edge — correct for a screen you scroll, and too timid for the
            // one screen that is a poster. This is the other side of that:
            // close enough to be the last thing on the page, far enough not to
            // look like it is falling off it.
            .padding(.bottom, 46)
            .column()

            if page == .what {
                bar(topInset: topInset)
            }
        }
        .frame(width: size.width, height: size.height)
        // A row of reeds is several screens long and runs off both edges. Off
        // the edge of the *screen* is the point; off the edge of the page and
        // into the one parked beside it is not, and that is what it did.
        .clipped()
    }

    /// The second page's two ways out: back to the first, or past the lot.
    ///
    /// Both at the top, where a screen's escapes belong, and both quiet. They
    /// used to be a second key under the first, which pushed the orange one
    /// 40pt up the page — so tapping through moved the very thing you had just
    /// pressed. Up here the key lands in the same place on both pages.
    private func bar(topInset: CGFloat) -> some View {
        HStack {
            BareToolbarButton(symbol: "chevron.left", label: "Back") {
                turn(to: .hello)
            }

            Spacer()

            Button("Skip") { skip() }
                .font(.heading(14))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Capsule().fill(Palette.surfaceRaised))
                .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 1))
                .buttonStyle(.plain)
        }
        .padding(.horizontal, Metrics.screenMargin)
        .padding(.top, topInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// The ground the words stand on: one fade across the full width, tight
    /// enough to be under the block and nothing more.
    ///
    /// Measured up from the bottom in points, not as a fraction of the screen.
    /// The block is about the same height in points wherever it is shown, so a
    /// fraction that is a tight fade under a Pro Max leaves an SE's heading
    /// sitting on cane and swallows half of an iPad in landscape.
    ///
    /// It was briefly a pool — an ellipse sized to the column, so the reeds
    /// could carry on out to the edges either side of the words. It solved the
    /// right problem and looked like a smudge: a soft dark oval sitting on top
    /// of the picture, which is exactly what it was. A shape you can see the
    /// edge of is worse than a band you can't.
    private func scrim(for height: CGFloat) -> some View {
        let height = max(height, 1)
        let stop = { (points: CGFloat) in max(0, min(1, 1 - points / height)) }
        return LinearGradient(
            stops: [
                .init(color: .clear, location: stop(430)),
                .init(color: Palette.ground.opacity(0.35), location: stop(360)),
                .init(color: Palette.ground.opacity(0.9), location: stop(300)),
                .init(color: Palette.ground, location: stop(255)),
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    // MARK: The picture

    /// The reed field: rows of reeds laid on a diagonal, running off every
    /// edge of whatever screen it is given.
    ///
    /// A row is several reeds end to end, not one long one. That is the whole
    /// trick. A reed is 4.4 times as long as it is wide and cannot be talked
    /// out of it, so a *single* reed made to span a screen has to be as thick
    /// as that screen is wide over 4.4 — fine on a phone, and on a landscape
    /// iPad it means two colossal reeds and nothing else. Laid in runs, the
    /// reeds stay the size a reed should be and the row covers any width you
    /// like by simply containing more of them.
    ///
    /// Everything is struck from the height, so there is no number in here with
    /// a screen it happens to be wrong on.
    private func hero(in size: CGSize) -> some View {
        let radians = Self.angle * .pi / 180
        // Floored at a point: a `GeometryReader`'s first proposal can be zero,
        // and a zero-length reed is a zero pitch, which is a division by zero
        // and a count of NaN reeds.
        let height = max(size.height, 1)
        // Struck from the shorter side, and not in step with it.
        //
        // Off the height, seven rows is seven rows whatever the screen — which
        // on an iPad is a field of reeds and on a phone is a close-up of three.
        // The shorter side is what "how big does this feel" actually tracks,
        // and it is the same number in both orientations, so an iPad doesn't
        // change its mind when you turn it.
        //
        // But straight off the shorter side, an iPad gets reeds twice a phone's
        // and four rows of them. The power is what stops that: the screen grows
        // and the reeds grow with it, only slower, so a bigger screen holds
        // more of them rather than the same few blown up. Not much slower —
        // past a point you stop reading a field of reeds and start reading a
        // pattern, and a pattern that dense is unpleasant to look at.
        let phone: CGFloat = 440
        let ruler = max(min(size.width, height), 1)
        let length = 0.8 * phone * pow(ruler / phone, 0.7)
        let depth = length / Metrics.reedLyingAspect
        // Vertical spacing, not perpendicular: the rows are stacked straight
        // down, so a reed of thickness `depth` at 25° needs `depth / cos 25°`
        // of height, and the rest of the 1.34 is the daylight between them.
        let pitch = depth * 1.34
        let gap = depth * 0.26
        // A row's right-hand end sits lower than its left by the width times
        // the tangent of the angle, so a stack tall enough for the screen still
        // leaves the top-right corner bare — which is exactly what it did, most
        // visibly on an iPad in landscape where that drop is over half the
        // height. The field is grown by the drop and re-centred, so the corners
        // are covered instead of the middle being covered twice.
        let drop = size.width * tan(radians)
        let rows = Int(ceil((height + drop) / pitch)) + 1
        // How far a row has to reach to cross the screen corner to corner at
        // this angle, plus a reed's slack at each end for the stagger and for
        // the ends to be off the screen rather than on it.
        let span = size.width / cos(radians) + height * sin(radians) + length * 2.5
        let perRow = max(1, Int(ceil(span / (length + gap))))

        return ZStack {
            ForEach(0..<rows, id: \.self) { row in
                run(row: row, of: perRow, rows: rows, length: length,
                    depth: depth, gap: gap, pitch: pitch)
            }
        }
    }

    /// One row: a run of reeds end to end, turned, and set down at its height.
    ///
    /// Its own function because the chain — printing, size, shadow, stagger,
    /// rotation, position — is more than the type-checker will infer inside a
    /// `ForEach` inside a `ZStack` inside a `GeometryReader`.
    private func run(row: Int, of count: Int, rows: Int, length: CGFloat,
                     depth: CGFloat, gap: CGFloat, pitch: CGFloat) -> some View {
        HStack(spacing: gap) {
            ForEach(0..<count, id: \.self) { index in
                ReedRow(reed: Self.reeds[(row * 2 + index) % Self.reeds.count],
                        estimate: Self.estimate,
                        isNextUp: row == 0 && index == 0,
                        // Printed in proportion to the reed, with no ceiling.
                        // `ReedRow.scale(for:)` caps at 1.55, which is right
                        // inside the app — past that a name stops being
                        // printing on cane and becomes a heading that happens
                        // to sit on some. On a poster it is the other way
                        // round: the reed is the size it is, and the name has
                        // to be the size that reed would really carry.
                        scale: length / 380)
                    .frame(width: length, height: depth)
                    .shadow(color: .black.opacity(0.5), radius: 24, y: 16)
            }
        }
        // Slid along the row's own axis — the offset is applied before the
        // rotation, so it turns with it — by a different amount every third
        // row, so the joins between reeds don't line up into a seam running
        // down the picture.
        .offset(x: CGFloat(row % 3) * length * 0.37)
        .rotationEffect(.degrees(Self.angle))
        // Straight down, never along the perpendicular. The perpendicular has a
        // sideways component, so each row would step left of the one above and
        // the rows would march across the picture like a staircase.
        .offset(y: (CGFloat(row) - CGFloat(rows - 1) / 2) * pitch)
    }

    /// Four bays, not three: three reeds and an empty one, which is the case as
    /// anybody's actually looks and the only way to show that a slot is a place
    /// you put something.
    private var theCase: some View {
        VStack(spacing: 9) {
            ForEach(0..<4, id: \.self) { index in
                SlotMoulding(index: index, isEmpty: index == 3) {
                    if index < 3 {
                        ReedRow(reed: Self.reeds[index], estimate: Self.estimate,
                                isNextUp: index == 0)
                    }
                }
                .aspectRatio(Metrics.reedLyingAspect, contentMode: .fit)
            }
        }
        .shadow(color: .black.opacity(0.5), radius: 30, y: 18)
    }

    /// The angle every reed is laid at: falling to the right, the way reeds
    /// land when you tip a box of them out.
    private static let angle: Double = 25

    // MARK: The words

    /// Ranged left, both pages. Centred, the sentence under a big heading sets
    /// as a diamond and every line begins somewhere new; against a left margin
    /// the eye has one place to return to, which is what makes a poster read.
    @ViewBuilder private func words(for page: Page) -> some View {
        switch page {
        case .hello:
            VStack(alignment: .leading, spacing: 13) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to")
                        .font(.title(24))
                        .foregroundStyle(Palette.inkSecondary)

                    HStack(spacing: 13) {
                        // The mark leads, struck to the name's own line so the
                        // two read as one lockup rather than a badge with a
                        // caption after it.
                        LogoMark(size: 52)
                        Text("Reedar")
                            .font(.brand(48))
                            .foregroundStyle(Palette.ink)
                    }
                }

                Text("Thank you for buying it. No account, no subscription, no "
                     + "adverts, and nothing leaves your phone.")
                    .font(.copy(15.5))
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .what:
            VStack(alignment: .leading, spacing: 11) {
                Text("This is your case")
                    .font(.title(30))
                    .foregroundStyle(Palette.ink)

                Text("Log what you play and retire a reed when it's done. Reedar "
                     + "works out what your reeds really last you — by brand, "
                     + "model and strength.")
                    .font(.copy(15.5))
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Onward

    /// One key on the first page, two on the second.
    ///
    /// The first page asks one thing and offers one way on. The second is where
    /// a way past belongs, because that is the page that ends in doing
    /// something — and it is set small and quiet underneath, since it is the
    /// answer nobody is being encouraged to give.
    private func footer(for page: Page) -> some View {
        PrimaryKey(title: page == .hello ? "What is it?" : "Add my first reed",
                   symbol: page == .hello ? nil : "plus") {
            if page == .hello {
                turn(to: .what)
            } else {
                begin()
            }
        }
    }

    // MARK: The reeds in the case

    /// Plain `Reed` values, never inserted into a context: the picture needs
    /// reeds and the player's store must not gain any.
    /// `playedDaysAgo` because a case where every reed says "Played today" is a
    /// case nobody has: reeds are rotated precisely so they get a day or two to
    /// dry out, and the resting line is half of what the app is for. One played
    /// today, the rest at the various stages of coming back round.
    private static func reed(_ brand: String, _ model: String, _ strength: String,
                             _ nickname: String, minutes: Int,
                             playedDaysAgo: Int) -> Reed {
        let reed = Reed(brandID: "welcome", brandName: brand,
                        modelID: "welcome", modelName: model,
                        strength: Strength(label: strength, value: 0, scale: .halfStep),
                        instrument: .altoSax, nickname: nickname)
        let played = Calendar.current.date(byAdding: .day, value: -playedDaysAgo,
                                           to: Date()) ?? Date()
        reed.sessions = [PlaySession(date: played, totalMinutes: minutes,
                                     playingMinutes: minutes, reed: reed)]
        return reed
    }

    /// The first three are the ones the second page puts in the case; the rest
    /// are only ever seen at an angle, and are there so a screenful of reeds
    /// doesn't repeat every fifth one.
    private static let reeds = [
        reed("Vandoren", "Java Red", "2½", "Java #3", minutes: 348, playedDaysAgo: 0),
        reed("D'Addario", "Select Jazz", "2M", "Sunday", minutes: 192, playedDaysAgo: 1),
        reed("Rigotti", "Gold", "3 Light", "Gig reed", minutes: 402, playedDaysAgo: 3),
        reed("Vandoren", "V16", "3", "Bright one", minutes: 88, playedDaysAgo: 2),
        reed("Marca", "Superieure", "2½", "Spare", minutes: 130, playedDaysAgo: 5),
        reed("D'Addario", "Reserve", "3", "Big band", minutes: 265, playedDaysAgo: 2),
        reed("Vandoren", "Traditional", "3½", "Lesson reed", minutes: 174, playedDaysAgo: 4),
        reed("Légère", "Signature", "2¾", "Rainy day", minutes: 520, playedDaysAgo: 1),
        reed("Rico", "Royal", "2", "Break-in", minutes: 41, playedDaysAgo: 6),
        reed("Gonzalez", "Local 627", "3", "Sunday night", minutes: 233, playedDaysAgo: 3),
        reed("Vandoren", "ZZ", "2½", "Loud one", minutes: 311, playedDaysAgo: 7),
        reed("Marca", "American Vintage", "3", "Ballads", minutes: 156, playedDaysAgo: 2),
        reed("Steuer", "Classic", "3½", "Quartet", minutes: 208, playedDaysAgo: 5),
        reed("Rigotti", "Gold", "2½ Medium", "Warm-up", minutes: 97, playedDaysAgo: 1),
    ]

    private static let estimate = LifespanEstimate(minutes: 540, sampleCount: 3,
                                                   source: "your Vandoren Java Red")
}

#Preview {
    WelcomeView(page: .constant(.hello), begin: {}, skip: {})
        .preferredColorScheme(.dark)
        .tint(Palette.accent)
}
