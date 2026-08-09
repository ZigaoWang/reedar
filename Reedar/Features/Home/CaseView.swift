import SwiftData
import SwiftUI

/// Home is the case: eight slots, a reed lying in each one you've filled.
/// Tap a reed to open it, tap any empty slot to put a reed there, press and
/// hold a reed to pick it up and move it.
struct CaseView: View {
    /// Raised by the introduction when it ends on "Add your first reed". The
    /// case owns the add flow, so the hand-off is a flag it lowers rather than
    /// a sheet somebody else tries to present over it.
    var startAdding: Binding<Bool> = .constant(false)

    @Query(sort: \Reed.addedAt, order: .reverse) private var allReeds: [Reed]

    @State private var addingTo: SlotTarget?

    /// Whether this player has ever had a reed in the case.
    ///
    /// The line telling you to tap a slot is for somebody who has never done
    /// it. An empty case a year in means a player who retired their last reed
    /// on Sunday and knows perfectly well how to add another; telling them
    /// again is the app forgetting who it is talking to.
    @AppStorage("hasAddedAReed") private var hasAddedAReed = false
    /// Whether the hint has been waved away by hand. Separate from
    /// `hasAddedAReed` because they are different facts: one is "you've done
    /// it", the other is "I heard you the first time".
    @AppStorage("dismissedSlotHint") private var dismissedSlotHint = false
    /// Everything this screen can push, in one stack.
    ///
    /// It was a typed `[Reed]` path plus two `navigationDestination(isPresented:)`
    /// booleans, which is two mechanisms describing one stack. Open the archive
    /// by boolean and `path` is still empty; tap a reed in there and SwiftUI is
    /// asked to reconcile a path of one reed against a stack showing a screen
    /// that isn't in the path at all. That's the glitch — the tap doesn't
    /// "not work", it lands somewhere incoherent.
    ///
    /// `NavigationPath` is type-erased on purpose: the archive can keep pushing
    /// plain `Reed` values without having to know what routes home has.
    @State private var path = NavigationPath()

    /// The screens that hang off the plate. Retired reeds were two taps deep
    /// behind Lifespan, which is a strange place to keep half the collection.
    /// Not private: Settings pushes About, and it does it by value like
    /// everything else on this stack rather than by handing a view to a
    /// `NavigationLink` — see the note on `path` for what mixing the two
    /// mechanisms cost the last time.
    enum Destination: Hashable {
        case lifespan
        case archive
        case settings
        /// What this is, who made it, where to say something about it — and
        /// where any settings will go, when there are any.
        case about
    }

    /// Everything about carrying a reed lives in gesture state, which SwiftUI
    /// resets on its own the moment the gesture ends or is cancelled. Storing
    /// it in `@State` is what left reeds stuck in the air.
    @GestureState private var carry: Carry?

    /// Whether the case is the screen or an object on it — see `fit(in:)`.
    ///
    /// Width, not height, and the size class rather than a number of points: a
    /// compact width is the system saying "this is being held in one hand",
    /// which is exactly the condition the full-bleed case was drawn for. A
    /// threshold in points had to be guessed, and guessed wrong — a 6.9" phone
    /// is 440pt wide and wants every one of them.
    @Environment(\.horizontalSizeClass) private var widthClass

    private static let slotCount = 8
    /// The wall between two bays, and so also the only material the thumb
    /// scoop has to be cut out of — see `ReedShape.thumbRelief`.
    ///
    /// It was 8, from when a reed sat 4pt inside its bay: half the scoop was in
    /// the clearance above the cane, so half of it was spent where you couldn't
    /// see it. A reed fills its bay now, so every point of the scoop's depth
    /// shows below the cane — which means the scoop did not need to get bigger,
    /// the wall needed to stop being the thing that limited it.
    ///
    /// 12 rather than 8, and the scoop stays at 5: seven points of wall left
    /// under it, and a clear line of case between one bay and the next.
    private static let slotGap: CGFloat = 12

    /// The mark and the stats key are struck to one size, from one number, so
    /// the two ends of the plate can't drift apart again.
    private static let plateKeySize: CGFloat = 42

    /// The name on the plate. Named because its optical drop is struck from it.
    private static let wordmarkSize: CGFloat = 21

    /// One margin, both sides, for everything in the case.
    ///
    /// The bays used to be inset 17 on the left and 25 on the right — an
    /// optical correction, and a real one: a bay is a reed's outline, so its
    /// arched tip curves away from the wall where the square heel doesn't, and
    /// even margins leave the tip end looking loose.
    ///
    /// It cost more than it bought. Everything in the case inherits that inset,
    /// so nothing could share a centre or an edge with anything else: the mark
    /// couldn't be centred on the phone and between the keys at once, and a key
    /// couldn't line up with the reeds under it and its opposite number at the
    /// same time. Three separate things looked wrong and they were all this.
    ///
    /// Square, everything agrees — keys, reeds, mark, screen, one grid. The
    /// tip end gives back a few points of apparent slack, which is a smaller
    /// price than every alignment on the screen being off by four.
    private static let caseInset: CGFloat = 21

    private struct Carry: Equatable {
        var id: UUID
        var from: Int
        /// Both axes. It was the vertical alone while the case was a single
        /// column and there was nowhere sideways to go.
        var translation: CGSize = .zero
        var isLifted = false
        /// Where along the reed the finger landed: 0 at the tip, 1 at the heel.
        /// Fixed for the life of the carry — it's where you took hold of it.
        var grip: CGFloat = 0.5
        /// How fast it's travelling, in points per second.
        var speed: CGFloat = 0
    }

    private var activeReeds: [Reed] { allReeds.filter { !$0.isRetired } }

    /// The case laid out: one entry per slot, in the player's own order.
    private var slots: [Reed?] {
        var result = [Reed?](repeating: nil, count: Self.slotCount)
        var overflow: [Reed] = []

        for reed in activeReeds.sorted(by: { $0.slotIndex < $1.slotIndex }) {
            if result.indices.contains(reed.slotIndex), result[reed.slotIndex] == nil {
                result[reed.slotIndex] = reed
            } else {
                overflow.append(reed)
            }
        }
        for reed in overflow {
            if let free = result.firstIndex(where: { $0 == nil }) {
                result[free] = reed
            }
        }
        return result
    }

    /// Which slot the carried reed is currently over.
    ///
    /// A reed changes bay once it has travelled most of the way into the next
    /// one, not half of it. Half puts the switching point exactly where a
    /// finger comes to rest between two bays, and the reeds behind it then
    /// flip between two layouts on every pixel of hand tremor.
    ///
    /// The same rule now runs on both axes. Sideways it matters more, not
    /// less: the columns are far apart, so a reed carried up a column passes
    /// nowhere near the next one, and only a deliberate move across changes
    /// which column it belongs to.
    private func hoverSlot(_ carry: Carry, in grid: Grid) -> Int {
        let row = grid.row(of: carry.from) + Self.steps(carry.translation.height, over: grid.step.height)
        let column = grid.column(of: carry.from) + Self.steps(carry.translation.width, over: grid.step.width)
        return grid.index(row: min(max(row, 0), grid.rows - 1),
                          column: min(max(column, 0), grid.columns - 1))
    }

    /// How many whole bays a drag of `distance` has crossed, with the hysteresis
    /// that keeps a hand resting on a boundary from flickering between two.
    private static func steps(_ distance: CGFloat, over step: CGFloat) -> Int {
        guard step > 0 else { return 0 }
        let exact = distance / step
        return Int(exact > 0 ? (exact + 0.38).rounded(.down) : (exact - 0.38).rounded(.up))
    }

    /// The case as it would look with one reed moved from one slot to another.
    ///
    /// Nothing moves that doesn't have to. Dropping into a free slot disturbs
    /// nothing at all; dropping onto an occupied one pushes reeds along only as
    /// far as the nearest empty slot, so a reed at the other end of the case
    /// stays exactly where you left it.
    private func arrangement(moving reed: Reed, from: Int, to: Int) -> [Reed?] {
        var result = slots
        guard result.indices.contains(from), result.indices.contains(to), from != to else {
            return result
        }

        result[from] = nil

        // A free slot takes the reed on its own.
        guard result[to] != nil else {
            result[to] = reed
            return result
        }

        if to > from {
            // The nearest gap below the target absorbs the shift.
            let gap = (from..<to).last { result[$0] == nil } ?? from
            for slot in gap..<to {
                result[slot] = result[slot + 1]
            }
        } else {
            let gap = ((to + 1)...from).first { result[$0] == nil } ?? from
            for slot in stride(from: gap, to: to, by: -1) {
                result[slot] = result[slot - 1]
            }
        }

        result[to] = reed
        return result
    }

    /// Where a reed sits while a carry is in progress. The carried reed keeps
    /// its own slot — it's drawn floating above, offset by the drag — and the
    /// rest shift along to open a space for it.
    private func displaySlot(of reed: Reed, in grid: Grid) -> Int {
        let settled = slots.firstIndex { $0?.id == reed.id } ?? reed.slotIndex
        guard let carry, carry.isLifted,
              let carried = activeReeds.first(where: { $0.id == carry.id })
        else { return settled }

        if carry.id == reed.id { return carry.from }

        let hover = hoverSlot(carry, in: grid)
        let preview = arrangement(moving: carried, from: carry.from, to: hover)
        return preview.firstIndex { $0?.id == reed.id } ?? settled
    }

    /// Which slots have a reed lying in them at this moment. A reed held in
    /// the hand has left its slot, so that slot is bare and says so — waiting
    /// for the drop to admit it left a numbered bay looking occupied.
    private func occupiedSlots(in grid: Grid) -> Set<Int> {
        var result: Set<Int> = []
        for reed in activeReeds {
            let isCarried = reed.id == carry?.id && carry?.isLifted == true
            guard !isCarried else { continue }
            result.insert(displaySlot(of: reed, in: grid))
        }
        return result
    }

    // MARK: The grid of bays

    /// Where every bay is. One column on a phone; on a display wide enough to
    /// hold them, two of four — which is what an eight-reed case is, and what
    /// one column of eight stops being once there's a screen's width spare.
    ///
    /// Numbering runs down a column and then back to the top of the next, so
    /// bays 01–04 are the same four bays in the same order whichever shape the
    /// case is in, and a reed doesn't change its number when the iPad turns.
    private struct Grid {
        var columns: Int
        var rows: Int
        var slot: CGSize
        var gap: CGFloat
        var columnGap: CGFloat

        /// Centre-to-centre, the distance a reed travels to reach the next bay.
        var step: CGSize {
            CGSize(width: slot.width + columnGap, height: slot.height + gap)
        }

        func row(of index: Int) -> Int { index % rows }
        func column(of index: Int) -> Int { index / rows }
        func index(row: Int, column: Int) -> Int { column * rows + row }

        /// The top-left corner of a bay, measured from the bed's own.
        func origin(of index: Int) -> CGSize {
            CGSize(width: CGFloat(column(of: index)) * step.width,
                   height: CGFloat(row(of: index)) * step.height)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            // The reader is laid out inside the safe area purely to be told
            // where it is: the case then ignores it and runs to the glass on
            // all four sides, and the insets come back as padding on what's
            // printed inside. A view that ignores the safe area is told its
            // insets are zero, so it can't ask for them itself.
            GeometryReader { proxy in
                caseBody(fitting: proxy.size, safeArea: proxy.safeAreaInsets)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
            }
            .background { Backdrop() }
            .navigationBarHidden(true)
            .sheet(item: $addingTo) { AddReedView(slot: $0.index) }
            .navigationDestination(for: Reed.self) { ReedDetailView(reed: $0) }
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .lifespan: StatsView()
                case .archive: ArchiveView()
                case .about: AboutView()
                case .settings: SettingsView()
                }
            }
            // The introduction has finished and asked for a reed. It goes in
            // the first free bay rather than a chosen one: the case is empty,
            // every bay is the first bay, and being asked to pick one is a
            // question with no wrong answer, which is the worst kind.
            .onChange(of: startAdding.wrappedValue) { _, wants in
                guard wants else { return }
                startAdding.wrappedValue = false
                addingTo = SlotTarget(index: slots.firstIndex { $0 == nil } ?? 0)
            }
            // Any reed at all, ever, retires the hint for good — including
            // reeds that arrive from another device by iCloud, and reeds that
            // are all subsequently retired or deleted.
            .task(id: allReeds.isEmpty) {
                if !allReeds.isEmpty { hasAddedAReed = true }
            }
            .task {
                normalizeSlots()
                let arguments = ProcessInfo.processInfo.arguments
                // The query may not have delivered yet when this first runs.
                if arguments.contains("-openReed") || arguments.contains("-openStats") {
                    try? await Task.sleep(for: .milliseconds(400))
                }
                if arguments.contains("-openReed"),
                   let first = activeReeds.first(where: { $0.isBreakingIn }) ?? activeReeds.first {
                    path.append(first)
                }
                if arguments.contains("-openAdd") { addingTo = SlotTarget(index: 0) }
                if arguments.contains("-openStats") { path.append(Destination.lifespan) }
                // It used to be opened from the Lifespan screen, which is where
                // the way into About used to be.
                if arguments.contains("-openAbout") { path.append(Destination.about) }
                if arguments.contains("-openSettings") { path.append(Destination.settings) }
            }
        }
    }

    // MARK: The head plate

    /// The plate at the head of the case, where a real one carries the maker's
    /// name stamped into the shell.
    ///
    /// This is where the app's title bar went. A title bar spends the best
    /// 60pt on screen saying which app you have open, which you knew, and which
    /// the launch screen told you a second earlier. The case needs that height
    /// more than the name does — so the name went, and the plate took over the
    /// one job the header was actually doing.
    ///
    /// It carries the name. That was cut once, on the grounds that a title bar
    /// spends the best 60pt on screen telling you which app you have open —
    /// which is true of the app and false of everything around it. This is the
    /// screen people screenshot and share, and a screenshot with no name on it
    /// is a screenshot of nothing in particular. The name earns its 20pt there,
    /// not here.
    ///
    /// It deliberately does not name the reed to play next. The case says that
    /// itself, printed on the cane, forty points below; a plate repeating it
    /// would be the screen saying one thing twice instead of two things once.
    ///
    /// Left-aligned rather than centred: every other thing on this screen —
    /// bay numbers, reed names, statuses — reads off the left margin. It works
    /// here because it is the maker's mark on the lid: the one thing on the
    /// screen that isn't part of the rotation, and the one thing a screenshot
    /// needs. A key at each end holds it there.
    ///
    /// The lockup is centred on the plate, not on the space between the two
    /// keys — a `ZStack`, not the middle of an `HStack`. Centred between them
    /// it would only look centred while both keys stayed the same width.
    private var headPlate: some View {
        ZStack {
            VStack(spacing: 0) {
                // A jump, not a menu. There was a menu here for a while, on
                // the grounds that the one pressable thing on the case had two
                // places to go and shouldn't hide either behind the other —
                // which put a two-item sheet between a finger and both of them.
                //
                // They aren't two places. One is where you change things and
                // the other is a page about the app, which is a thing settings
                // screens have carried at the bottom for as long as there have
                // been settings screens. The mark goes where you were going,
                // and About is the last row of it.
                Button {
                    path.append(Destination.settings)
                } label: {
                    HStack(spacing: 9) {
                        // Struck to the wordmark's own line, so the mark and
                        // the name read as one size rather than as a big badge
                        // with a caption next to it.
                        // The mark carries slightly more than its share. Set to
                        // the wordmark's exact line height it reads smaller
                        // than the word beside it — a solid shape and a run of
                        // letters at the same measure never look the same size,
                        // because the letters only fill part of theirs.
                        LogoMark(size: 32)
                        // One lockup, drawn from one place — it should be the
                        // same on the way in as on the screen it hands over to.
                        Wordmark(size: Self.wordmarkSize)
                            // Dropped onto the mark's optical centre rather than
                            // its measured one. A line of type is centred by its
                            // box, and a box reserves room under the baseline
                            // for descenders — which "Reedar" hasn't got a
                            // single one of. So the letters sit in the top of
                            // their own box and the word rides high against a
                            // square mark that fills all of its.
                            //
                            // The correction is the gap between the two
                            // centres, which for this face is close enough to a
                            // fourteenth of the type size to take that as the
                            // rule, and stays right if the wordmark is ever set
                            // larger.
                            .offset(y: Self.wordmarkSize * 0.07)
                    }
                    // Nothing drawn behind it. A nameplate was tried here — a
                    // flat fill and a hairline, no bevel, no shadow — and it
                    // still came out as a third outlined shape in a row of
                    // three, which is the plate reading as a toolbar.
                    //
                    // The mark is pressable and doesn't say so. It doesn't
                    // need to: it's the app's own name, the one thing on the
                    // screen a finger goes to out of curiosity rather than
                    // instruction, and it answers under the thumb.
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.sink)
                .accessibilityLabel("Reedar, settings")

            }
            // Clear of the keys at both ends, so a long line shortens rather
            // than running under them.
            .padding(.horizontal, Self.plateKeySize + 12)
            // Back onto the phone's centre line — see `plateCentring` — and a
            // shade high of the keys' own centre. "Reedar" has no descenders,
            // so its visual mass sits above the line the two keys are centred
            // on, and setting all three on the same axis leaves the name
            // looking like it has sunk.
            .offset(y: -1.5)

            HStack {
                plateKey("archivebox", label: "Retired reeds", key: "r") {
                    path.append(Destination.archive)
                }
                Spacer()
                plateKey("chart.bar", label: "Lifespan data", key: "d") {
                    path.append(Destination.lifespan)
                }
            }
        }
        // A reed fills its bay exactly, so the plate sits on the bays' own
        // edges and the keys land on the reeds' edges with it. It used to
        // carry a 4pt inset here to match a 4pt clearance around the reeds;
        // both are gone together.
        //
        // The outer margin is `caseInset`, and it's even on both sides — which
        // is the whole reason the mark can simply be centred here. While the
        // case was lopsided there were two centres 4pt apart, the screen's and
        // the midpoint between the keys; centre the mark on either and it
        // reads off against the other, which is why nudging it never fixed it.

        .frame(height: 52)
    }

    /// A key on the plate. Both ends of the head are the same object, cut from
    /// lighter stock than the floor so they stand above it — milled into it,
    /// which was the first attempt, just reads as a hole punched in the case.
    /// - Parameter key: the letter that reaches it from a keyboard. Both plate
    ///   keys are one press away on an iPad with a keyboard attached, because
    ///   both are one press away without one.
    private func plateKey(_ symbol: String,
                          label: String,
                          key: KeyEquivalent,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: Self.plateKeySize, height: Self.plateKeySize)
                .background {
                    let shape = RoundedRectangle(cornerRadius: Metrics.radiusKey,
                                                 style: .continuous)
                    shape
                        .fill(Palette.keyFace)
                        .overlay { Light.bevel(shape,
                                               highlight: Palette.keyHighlight,
                                               shade: Palette.keyShade) }
                        .overlay { shape.strokeBorder(Palette.hairline, lineWidth: 1) }
                        .clipShape(shape)
                        .shadow(color: Palette.dropShadow, radius: 5, y: 2)
                }
        }
        .buttonStyle(.sink)
        .accessibilityLabel(label)
        .keyboardShortcut(key, modifiers: .command)
        .hoverEffect(.lift)
    }

    /// A line under the name, and only when there is something to teach.
    ///
    /// It used to carry the week's playing time on every launch. That's gone —
    /// the plate is the maker's mark, and a running total sitting under it
    /// turned it into a dashboard. The number still lives on the Lifespan
    /// screen, which is the screen for numbers.
    ///
    /// The empty case keeps its line, because it has to. With the `+` gone from
    /// the bays and the disclosure arrow gone from the reeds, this sentence is
    /// now the only thing on a first launch that says a bay can be tapped.
    ///
    /// It deliberately doesn't cover the carry. A line appearing while a reed
    /// is in the air would grow the plate, and the bed below it would shrink —
    /// every bay resizing under the reed you're holding.
    /// The reed that has rested longest, if there's a useful answer.
    private var nextUp: Reed? { Rotation.nextUp(among: activeReeds) }

    // MARK: The case

    /// The case: not an object on the screen, the object the screen is.
    ///
    /// There is no shell. A wall drawn round the display was a wall with
    /// nothing on the other side of it — every real case wall is there to be
    /// seen against something, and here the something is the bezel. However
    /// carefully it was lit it stayed a stripe of lighter grey hugging the
    /// phone. So the tray is the ground now: you are looking into the case with
    /// its walls out of frame, which is how you look into a case you are
    /// holding anyway.
    ///
    /// That leaves two depths instead of three — ground and slot — and the
    /// mouldings carry the whole illusion. They already did most of it.
    ///
    /// The ground runs on under the status bar and the home indicator; only
    /// what's printed on it is held clear of them.
    ///
    /// On a display too wide for eight reeds, only what's printed on the ground
    /// narrows — see `bayWidth`. The ground itself always runs to the glass.
    private func caseBody(fitting available: CGSize, safeArea: EdgeInsets) -> some View {
        let bed = Self.bed(in: available, safeArea: safeArea, width: widthClass)
        return VStack(spacing: Self.plateGap) {
            headPlate
            // Capped to the bays' own height, then given the rest of the screen
            // back so it sits in the middle of it. The plate stays at the top
            // where the lid's stamp belongs; it's the bed that centres.
            slotBed(columns: bed.columns)
                .frame(maxHeight: bed.height)
                .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, Self.caseInset)
        // The bays, and only the bays. `nil` on a phone, where the cap doesn't
        // exist and this frame does nothing.
        .frame(maxWidth: bed.width)
        .frame(maxWidth: .infinity)
        .padding(.top, max(13, safeArea.top + 4))
        .padding(.bottom, max(13, safeArea.bottom + 4))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { ground }
        .background { newReedShortcut }
        // The one line an empty case needs, and the only thing on a first
        // launch that says a bay can be tapped.
        //
        // An overlay, not a row. In the plate it made the lockup a stack of two
        // things and the mark rode up and down depending on how many reeds you
        // owned; between the plate and the bed it took height off every bay.
        // Laid over the foot of the case it costs nothing and moves nothing,
        // and the bays it covers are empty by definition.
        .overlay(alignment: .bottom) {
            if activeReeds.isEmpty, !hasAddedAReed, !dismissedSlotHint {
                HStack(spacing: 4) {
                    Text("Tap any slot to add your first reed")
                        .font(.copy(13))
                        .foregroundStyle(Palette.inkSecondary)

                    // A way to be rid of it.
                    //
                    // It goes for good, not until next time: somebody who has
                    // dismissed a hint has told you they don't need it, and an
                    // app that keeps offering it anyway is arguing.
                    Button {
                        Haptics.tick()
                        withAnimation(.smooth(duration: 0.3)) {
                            dismissedSlotHint = true
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Palette.inkTertiary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 14)
                .padding(.trailing, 2)
                .padding(.vertical, 5)
                .background {
                    Capsule().fill(Palette.surface.opacity(0.9))
                        .overlay { Capsule().strokeBorder(Palette.hairline, lineWidth: 1) }
                }
                .padding(.bottom, 26)
                .transition(.opacity)
            }
        }
    }

    /// ⌘N, and nothing to look at.
    ///
    /// Every other command on this screen hangs off something you can press, so
    /// the shortcut is just a letter added to a button that already exists.
    /// Adding a reed has no button — you tap the bay you want it in — so this
    /// is the one command that needs a place to live. It fills the first free
    /// bay, which is what a keyboard shortcut should do when the gesture it
    /// stands in for is "pick one".
    ///
    /// Drawn at zero size rather than hidden: a `.hidden()` view is out of the
    /// hierarchy and its shortcut goes with it.
    @ViewBuilder private var newReedShortcut: some View {
        if let free = slots.firstIndex(where: { $0 == nil }) {
            Button("Add a reed") { addingTo = SlotTarget(index: free) }
                .keyboardShortcut("n", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
        }
    }

    // MARK: Fitting the bays to the display

    /// How the bed is arranged on this display, and how much room it takes.
    ///
    /// Both measurements or neither. A bay's proportion is fixed, so capping
    /// the width without capping the height doesn't produce narrower reeds —
    /// it produces squat ones, the rows still dividing the whole display
    /// between them. Landscape is where that shows: the width runs out first,
    /// and the height has to be told to follow it down.
    private struct Bed {
        var columns: Int
        /// How wide the whole block of bays may be, insets included, or `nil`
        /// on a phone where it takes the screen.
        var width: CGFloat?
        var height: CGFloat?
    }

    /// Choose the arrangement that gets the most reed onto the glass.
    ///
    /// A bay is a reed's outline, so its proportion is not negotiable: eight of
    /// them dividing the height of a 13" iPad, each as wide as the iPad, are
    /// eight paddles. Given that, an arrangement is pinned either by the
    /// height it has to divide or by the width it has to fill, and the widest
    /// bay that comes out of it wins — which lands on one column of eight in
    /// portrait and two of four in landscape, without either being asked for
    /// by name. That's the same reasoning a case maker uses: eight reeds in a
    /// long thin box go in a row, eight in a squat one go in two.
    ///
    /// What is *not* negotiable is that the case is still the screen. The tray
    /// runs to the glass and takes its corners from the display on an iPad
    /// exactly as on a phone; only the bays stop short. Insetting the whole
    /// case instead draws a rounded rectangle on a ground of the same colour,
    /// which reads as a phone pasted onto an iPad however carefully it's lit.
    private static func bed(in available: CGSize,
                            safeArea: EdgeInsets,
                            width: UserInterfaceSizeClass?) -> Bed {
        // A phone, or a window as narrow as one: the case takes all of it.
        //
        // Small phones pay for that. Eight bays over an SE's 568 points of bed
        // come out 5.2 : 1 against a reed's 4.4, and the only lever that would
        // fix it is narrowing them — which was tried, and which trades a shape
        // nobody measures for width everybody sees. Full width wins. The reed
        // is a shade long on the smallest screens and that is the better bill.
        guard width == .regular else { return Bed(columns: 1, width: nil, height: nil) }

        // The reader is laid out inside the safe area and the case isn't, so
        // the height it actually gets is the reader's plus the insets — which
        // the padding then gives back.
        let total = available.height + safeArea.top + safeArea.bottom
        let chrome = plateHeight + plateGap
            + max(13, safeArea.top + 4) + max(13, safeArea.bottom + 4)
        let bedHeight = total - chrome

        var best = Bed(columns: 1, width: nil, height: nil)
        var widest: CGFloat = 0

        for columns in [1, 2] {
            let rows = slotCount / columns
            let stacked = slotGap * CGFloat(rows - 1)
            let between = columnGap * CGFloat(columns - 1)

            // Pinned by the height it divides, or by the width it fills.
            let byHeight = max((bedHeight - stacked) / CGFloat(rows), 0) * Metrics.reedLyingAspect
            let byWidth = (available.width - caseInset * 2 - between) / CGFloat(columns)
            let bay = min(maxBayWidth, byHeight, byWidth)

            if bay > widest {
                widest = bay
                best = Bed(
                    columns: columns,
                    width: bay * CGFloat(columns) + between + caseInset * 2,
                    height: bay / Metrics.reedLyingAspect * CGFloat(rows) + stacked
                )
            }
        }
        return best
    }

    /// Room above and below the bed: the plate and the gap under it.
    private static let plateHeight: CGFloat = 52
    private static let plateGap: CGFloat = 10
    /// The wall between two columns of bays. Wider than the wall between two
    /// stacked ones, because it separates two runs of reeds rather than two
    /// neighbours in the same run — and because the moulding's thumb relief is
    /// cut into the horizontal walls, not these.
    private static let columnGap: CGFloat = 14
    /// The widest the bays go. Set by the type printed on the cane rather than
    /// by the reed: past about this the name and the hours are a small line of
    /// text adrift in a very large piece of cane.
    private static let maxBayWidth: CGFloat = 720

    /// One bay, in its place. Its own function because the chain — moulding,
    /// size, tap target, hover shape, position — is more than the type-checker
    /// will infer inside a `ForEach` inside a `ZStack` inside a `GeometryReader`.
    private func bay(_ index: Int, in grid: Grid,
                     isEmpty: Bool, isTarget: Bool, scale: CGFloat) -> some View {
        SlotMoulding(index: index, isEmpty: isEmpty, isTarget: isTarget,
                     scale: scale) { Color.clear }
            .frame(width: grid.slot.width, height: grid.slot.height)
            .contentShape(Rectangle())
            .onTapGesture {
                guard carry?.isLifted != true, slots[index] == nil else { return }
                Haptics.slotTapped()
                addingTo = SlotTarget(index: index)
            }
            // Under a trackpad pointer an empty bay lights up the recess it
            // actually is, rather than the rectangle it's laid out in. A full
            // one doesn't light at all: the reed lying in it is the thing the
            // pointer is over, and it answers for itself.
            .contentShape(.hoverEffect, ReedShape.bay)
            .hoverEffect(isEmpty ? .highlight : .automatic, isEnabled: isEmpty)
            .offset(grid.origin(of: index))
    }

    private func slotBed(columns: Int) -> some View {
        GeometryReader { geo in
            let rows = Self.slotCount / columns
            let grid = Grid(
                columns: columns,
                rows: rows,
                slot: CGSize(
                    width: (geo.size.width - Self.columnGap * CGFloat(columns - 1)) / CGFloat(columns),
                    height: (geo.size.height - Self.slotGap * CGFloat(rows - 1)) / CGFloat(rows)
                ),
                gap: Self.slotGap,
                columnGap: Self.columnGap
            )
            // The slot the carried reed would drop into, if one is in hand.
            let hovered: Int? = carry.flatMap {
                $0.isLifted ? hoverSlot($0, in: grid) : nil
            }
            let occupied = occupiedSlots(in: grid)
            // What's printed on a bay, and on the reed lying in it, is sized to
            // the bay rather than to the phone the app was drawn on.
            let printScale = ReedRow.scale(for: grid.slot.width)

            ZStack(alignment: .topLeading) {
                // The mouldings never move. Placed by the grid rather than
                // stacked, because with two columns there is no stack to be in.
                ForEach(0..<Self.slotCount, id: \.self) { index in
                    bay(index, in: grid, isEmpty: !occupied.contains(index),
                        isTarget: hovered == index, scale: printScale)
                }

                // The reeds sit on top, each positioned over its slot. Moving
                // one is a change of offset, so it slides rather than redraws.
                ForEach(activeReeds) { reed in
                    let isCarried = carry?.id == reed.id && carry?.isLifted == true
                    // A finger resting on the reed, before it has moved far
                    // enough to lift it. The carry gesture already knows this —
                    // it tracks from the instant the touch lands — so a reed
                    // can answer a finger without a single line of new state.
                    let isPressed = carry?.id == reed.id && !isCarried
                    let index = displaySlot(of: reed, in: grid)
                    let base = grid.origin(of: index)

                    ReedRow(
                        reed: reed,
                        estimate: LifespanStats.estimate(for: reed, among: allReeds),
                        isNextUp: reed.id == nextUp?.id,
                        scale: printScale
                    )
                    .frame(width: grid.slot.width, height: grid.slot.height)
                    // A pointer over a reed lifts it, which is the one hover
                    // effect that means what it says here: this is a thing you
                    // pick up. Cut to the reed's own outline so the pointer
                    // takes hold of the cane rather than of a card behind it.
                    .contentShape(.hoverEffect, ReedShape(axis: .horizontalReversed))
                    .hoverEffect(.lift)
                    // Every reed lies at the same height. The one to play next
                    // was drawn a shade proud of its bay for a while, as if
                    // somebody had half-pulled it out for you, and the first
                    // thing anyone asked about it was why that reed was bigger
                    // than the others — which is the question `ReedRow` already
                    // says a reed should never provoke. It says "Play this
                    // next" on the cane. That's the whole marking it needs.
                    //
                    // Pressed, it goes the other way: a reed under a fingertip
                    // seats down into its bay. Not a button shrinking — the
                    // travel is a third of what a button would take, and what
                    // sells it is the shadow closing up underneath rather than
                    // the size changing.
                    .scaleEffect(isCarried ? 1.03 : (isPressed ? 0.994 : 1))
                    // Anchored where your finger is, not on the middle of the
                    // reed: that's the difference between something swinging
                    // from a grip and something being skewed.
                    .rotationEffect(.degrees(tilt(carried: isCarried)),
                                    anchor: UnitPoint(x: carry?.grip ?? 0.5, y: 0.5))
                    // Sprung, so it swings and settles rather than snapping to
                    // each new velocity reading. Damped to the house rule —
                    // see `Animation.mechanical`, which says in as many words
                    // that nothing in this app bounces.
                    .animation(.spring(response: 0.3, dampingFraction: 0.86),
                               value: tilt(carried: isCarried))
                    // Down in the bay it also loses a little light, because it
                    // is further into the shadow of the near wall.
                    .brightness(isPressed ? -0.025 : 0)
                    // A reed resting in its slot still touches the floor of it:
                    // a tight contact shadow, which grows and softens the
                    // moment the reed comes up off the mouldings.
                    //
                    // Flattened first, or the shadow reaches every view inside
                    // and each letter printed on the cane casts its own.
                    .compositingGroup()
                    // Black at 55%, which is a black-case value and was written
                    // when there was only a black case. On bone plastic it is
                    // the grey ring that appeared to be drawn around every
                    // reed: not a border, not the bay, just a dark-material
                    // shadow left switched on in a pale material.
                    .shadow(color: isCarried ? Palette.dropShadow : Palette.slotContact,
                            radius: isCarried ? 16 : (isPressed ? 1.5 : 3),
                            y: isCarried ? 10 : (isPressed ? 0.5 : 1.5))
                    // The seating is quick and damped, like anything with mass
                    // being pushed the last millimetre into a socket.
                    .animation(.mechanical, value: isPressed)
                    .offset(x: base.width + (isCarried ? (carry?.translation.width ?? 0) : 0),
                            y: base.height + (isCarried ? (carry?.translation.height ?? 0) : 0))
                    // Settled reeds glide to their new slot; the carried one
                    // tracks the finger with no animation in the way.
                    //
                    // Damped almost flat. These are the reeds shuffling aside
                    // to make room, and at 0.8 they overshot their new bay and
                    // came back — which is fine once, and reads as a shiver
                    // when a hand hovering near a boundary sends them off
                    // again before the last one has settled.
                    .animation(isCarried ? nil : .spring(response: 0.3, dampingFraction: 0.95),
                               value: base)
                    // Coming out of the carry, the reed settles into its bay
                    // rather than snapping there. Dropping it back where it
                    // started used to cut straight from wherever your finger
                    // was to the bay, in one frame.
                    .animation(.settle, value: isCarried)
                    .zIndex(isCarried ? 1 : 0)
                    // Opening the reed lives inside this too — see the comment
                    // on `carryGesture`.
                    .gesture(carryGesture(for: reed, at: index, in: grid))
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            // A reed coming off the mouldings should be felt, not just seen —
            // there was no telling the moment it was in hand.
            .onChange(of: carry?.isLifted == true) { _, lifted in
                if lifted { Haptics.reedLifted() }
            }
            // And a tick as it crosses into each new slot, so the case can be
            // counted through the fingertip. Only between slots: the pickup and
            // the drop have weightier haptics of their own.
            .onChange(of: hovered) { previous, current in
                if previous != nil, current != nil { Haptics.tick() }
            }
        }
        // A full-width bay tucked into a tray with a 40pt corner needs about
        // 12pt of margin before its own corner clears the arc. At 7 the first
        // and last bays were pushing out through the tray's rounding, which is
        // the overflow you can see even though nothing is clipped.
        //
        // Left and right are not equal on purpose. A bay is a reed's outline:
        // arched at the tip, square at the heel. Struck with even margins it
        // measures symmetrical and reads left-heavy, because the arch curves
        // away from the wall and the heel does not. The tip end gives back
        // four points, which is roughly what the arch takes.
    }

    /// The floor of the case, edge to edge — the one surface everything else
    /// on this screen is cut into.
    ///
    /// No inner shading and no edge light: both describe a wall, and the walls
    /// are out of frame.
    ///
    /// Not rounded, and deliberately so. The corners are meant to be struck by
    /// the phone rather than by a rectangle behind it — and since this surface
    /// runs to the glass on every edge, the display already does exactly that.
    /// Drawing a rounded rectangle to match it meant knowing the display's
    /// corner radius, which UIKit has never exposed; it was read through a
    /// private key with a hardcoded fallback, and any device the fallback
    /// guessed wrong for got the tray cut *inside* the glass, showing a sliver
    /// of the backdrop at all four corners. It could never have been right in
    /// an iPad window either, where the corners belong to the window and not to
    /// the screen.
    ///
    /// A rectangle is right everywhere, and needs to know nothing.
    ///
    /// The grain matters more here than anywhere. This is the largest single
    /// surface in the app by a long way, and at that size a flat fill stops
    /// being a material and becomes a rectangle.
    private var ground: some View {
        Rectangle()
            .fill(Palette.trayFace)
            .grained(0.025)
    }

    // MARK: Carrying

    /// One gesture for both things you can do to a reed: open it, or move it.
    ///
    /// It used to take a 0.2s press before a drag would start, which is a fifth
    /// of a second in which the reed sits there ignoring your finger. Reeds
    /// don't need arming — you can just pick one up. So the touch is tracked
    /// from the instant it lands and the reed comes with you the moment you've
    /// moved `liftDistance`; under that it never left its slot, and letting go
    /// opens it. Holding still no longer does anything on its own, but holding
    /// still and then moving carries exactly as it always did.
    ///
    /// Both outcomes live in the one gesture rather than in a `.gesture` and a
    /// separate `.onTapGesture`, because a drag that begins at zero distance
    /// claims the touch and the tap would never be told about it.
    private func carryGesture(for reed: Reed, at index: Int, in grid: Grid) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .updating($carry) { value, state, transaction in
                let lifted = state?.isLifted == true || travelled(value) > Self.liftDistance
                // Only on the frame it comes up, so the catch-up to the finger
                // is sprung and everything after it tracks with no lag.
                if lifted, state?.isLifted != true {
                    transaction.animation = .spring(response: 0.25, dampingFraction: 0.85)
                }
                state = Carry(id: reed.id,
                              from: index,
                              translation: lifted ? value.translation : .zero,
                              isLifted: lifted,
                              grip: grid.slot.width > 0
                                  ? min(max(value.startLocation.x / grid.slot.width, 0), 1)
                                  : 0.5,
                              speed: lifted ? value.velocity.height : 0)
            }
            .onEnded { value in
                guard travelled(value) > Self.liftDistance else {
                    // It never came out of its slot. That was a tap.
                    Haptics.reedLifted()
                    path.append(reed)
                    return
                }
                drop(reed, from: index, translation: value.translation, in: grid)
            }
    }

    /// How far the finger has gone since it landed. Measured on both axes: a
    /// reed dragged at a slight angle is still a reed being dragged.
    private func travelled(_ value: DragGesture.Value) -> CGFloat {
        hypot(value.translation.width, value.translation.height)
    }

    /// The distance that separates opening a reed from carrying it. Small
    /// enough that a deliberate drag feels immediate, wide enough that the
    /// wobble in a tap doesn't lift anything.
    private static let liftDistance: CGFloat = 10

    /// How far a carried reed leans, in degrees.
    ///
    /// It used to lean a flat −0.7° the whole time it was in the air, which is
    /// not a reed being carried, it's a reed that has been printed crooked.
    /// Nothing in the world tilts by a constant.
    ///
    /// So it comes off the two things that actually decide it. **Speed**: the
    /// far end lags when you move, and hangs level when you don't, so letting go
    /// of the drag mid-air brings it back to flat on its own. And **where you
    /// took hold of it**: a long thin object gripped at one end swings a lot,
    /// gripped dead centre doesn't swing at all, which is why the rotation is
    /// anchored on the grip rather than on the middle of the reed. Take it by
    /// the heel and flick it and you get the whole 3°; pinch it in the middle
    /// and it stays flat however fast you move.
    private func tilt(carried isCarried: Bool) -> Double {
        guard isCarried, let carry else { return 0 }
        let lag = min(max(carry.speed * 0.004, -3), 3)
        // −1 at the tip end, +1 at the heel, 0 in the middle.
        let arm = (carry.grip - 0.5) * 2
        return lag * arm
    }

    private func drop(_ reed: Reed, from: Int, translation: CGSize, in grid: Grid) {
        let target = hoverSlot(Carry(id: reed.id, from: from, translation: translation),
                               in: grid)
        guard target != from else { return }

        let moved = arrangement(moving: reed, from: from, to: target)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.95)) {
            for (index, occupant) in moved.enumerated() where occupant?.slotIndex != index {
                occupant?.slotIndex = index
            }
        }
        Haptics.reedAdded()
    }

    /// Writes the laid-out order back to the reeds, so positions stay stable
    /// after a reed is retired or added before slots existed.
    private func normalizeSlots() {
        for (index, reed) in slots.enumerated() where reed?.slotIndex != index {
            reed?.slotIndex = index
        }
    }
}

/// Identifies which slot the add flow should fill.
struct SlotTarget: Identifiable {
    var index: Int
    var id: Int { index }
}

// MARK: - Slot

extension ReedShape {
    /// The moulding a reed lies in.
    ///
    /// The bay is the reed's own outline, not a rounded box: a case is moulded
    /// to hold reeds, and a squared-off trough around an arched tip leaves a
    /// crescent of dead space that reads as a mistake.
    ///
    /// It is the reed's outline exactly — same heel break, same tip arch — so
    /// that a reed lying in a bay covers it precisely and the two read as one
    /// object. The only thing the bay has that a reed does not is the scoop,
    /// and that is the one part of it you are meant to see when a reed is in.
    ///
    /// The relief is cut 5pt deep into the 12pt wall between two bays. Depth
    /// is the number to be careful with twice over: it is all you can see of
    /// the scoop, since everything above the reed's edge is behind the reed —
    /// and it also sets the width, which is a multiple of it. Cut to 8 the
    /// scoop came out 80pt across with 2pt of wall under it, which is not a
    /// scoop in a case, it is a bite out of one.
    static let bay = ReedShape(axis: .horizontalReversed,
                               heelRadius: ReedShape.bayHeelRadius,
                               thumbRelief: 5)
}

/// The moulded recess in the case. Drawn once per slot, whether or not a reed
/// is lying in it.
struct SlotMoulding<Content: View>: View {
    var index: Int = 0
    var isEmpty: Bool = false
    var isTarget: Bool = false
    /// Matches the reeds' — see `ReedRow.scale`. A bay's number is stamped into
    /// the same plastic at the same size whatever else is going on.
    var scale: CGFloat = 1
    @ViewBuilder var content: Content

    var body: some View {
        let shape = ReedShape.bay
        // Color.clear guarantees the moulding has a size even when the slot is
        // empty — an empty conditional on its own lays out at zero height.
        return ZStack {
            Color.clear
            if isEmpty { engraving }
            content
        }
            // No clearance. A reed used to sit 4pt inside its bay, and every
            // attempt to make that ring look like something — a lit floor, a
            // darker floor, a contact shadow, a narrower gap — was an attempt
            // to style a gap between two outlines that were never going to
            // agree. They agree now, so there is nothing to style: the reed
            // covers its bay exactly, and a filled slot is a reed.
            .padding(0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    // The floor of the recess, in shadow under its near wall.
                    shape.fill(Palette.bayFloor)
                    // The walls: dark where they face away from the light,
                    // bright where the far one turns back toward it.
                    //
                    // Struck harder than they were. With the case shell gone
                    // these bays are the only depth left on the screen, and
                    // five of eight of them are empty on a typical case — so
                    // most of what anyone looks at is this, and at the old
                    // settings it was a black rectangle with a hairline on it.
                    // The far wall is where the work is: it's the one edge in a
                    // recess that catches light, and at 7% it caught none.
                    Light.topShade(shape, radius: 3.5, width: 4.5, color: Palette.bayShade)
                    Light.bottomCatch(shape, width: 1.8, color: Palette.bayCatch)

                    shape.stroke(Palette.hairline, lineWidth: 2)
                }
                .clipShape(shape)
            }
            // Above the reed, not under it. The wall of a bay is behind
            // whatever is lying in it, and now that a reed covers its bay
            // exactly, a highlight drawn back there is a highlight you cannot
            // see on any bay that has a reed to drop onto.
            .overlay {
                if isTarget {
                    shape.stroke(Palette.accent.opacity(0.8), lineWidth: 4)
                        .clipShape(shape)
                }
            }
            .animation(.mechanical, value: isTarget)
            .contentShape(Rectangle())
    }

    /// An empty bay isn't nothing — it's a numbered bay, and the number is the
    /// only thing on it.
    ///
    /// There used to be a `+` at the other end and, in the first free bay, the
    /// words "Add a reed". Both were interface printed onto moulded plastic. No
    /// reed case has a plus sign in the bottom of a bay, and the moment you put
    /// one there the bay stops being a bay and becomes a button that happens to
    /// be reed-shaped. The number stays because cases really are numbered.
    ///
    /// What's lost is the only on-screen hint that tapping a bay does anything.
    /// The plate covers it on an empty case — "Tap any slot to add your first
    /// reed" — which is the one time somebody needs telling.
    ///
    /// Cut in rather than printed on: a dark line above the figure and the pale
    /// face below it, which is what a stamp in dark plastic does under a light
    /// from above. It only works because the figure is bold — at hairline
    /// weights this really does come out a smudge.
    private var engraving: some View {
        Text(indexLabel(index + 1))
            .font(.numeric(13 * scale, weight: .bold))
            .tracking(1)
            .foregroundStyle(Palette.engravingInk)
            .shadow(color: Palette.engravingRelief, radius: 0.5, y: -0.7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16 * scale)
            .opacity(isTarget ? 0 : 1)
            .animation(.mechanical, value: isTarget)
    }
}

/// A reed lying in a slot: name and hours on the planed end, brand printed on
/// the bark. No background of its own — the slot provides it.
struct ReedRow: View {
    var reed: Reed
    var estimate: LifespanEstimate
    /// The reed that has rested longest — the one to play next.
    var isNextUp: Bool = false
    /// How much bigger this bay is than a phone's, from `ReedRow.scale(for:)`.
    ///
    /// What's printed on a reed is printed at a size that suits the reed. An
    /// iPad bay is half as wide again as a phone's, and a name set at the
    /// phone's 16pt across it isn't restrained, it's a caption that has lost
    /// its picture — the cane reads as empty and the whole case as a phone
    /// screen someone has stretched.
    var scale: CGFloat = 1

    /// The type scale for a bay of a given width.
    ///
    /// One below a phone's own bay and never less, so nothing on a phone can
    /// move by so much as a point; capped a little over half again, because
    /// past that the type stops being printing on a reed and starts being a
    /// heading that happens to sit on one.
    static func scale(for bayWidth: CGFloat) -> CGFloat {
        min(max(bayWidth / 400, 1), 1.55)
    }

    private var wear: Double {
        guard estimate.minutes > 0 else { return 0 }
        return Double(reed.playingMinutes) / estimate.minutes
    }

    /// Ink for text printed straight onto cane.
    private let caneInk = Color(hex: 0x4A3413)

    var body: some View {
        // Every reed looks like a reed. With three states named in plain
        // words there is nothing left to encode in colour or dimming, and a
        // greyed-out row only ever raised the question of why.
        ReedView(axis: .horizontalReversed, wear: wear)
            .overlay {
                HStack(alignment: .center, spacing: 10 * scale) {
                    VStack(alignment: .leading, spacing: 2 * scale) {
                        HStack(spacing: 5 * scale) {
                            if reed.isFavourite {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 11 * scale, weight: .semibold))
                                    .foregroundStyle(caneInk.opacity(0.75))
                            }
                            Text(reed.slotTitle)
                                .font(.heading(16 * scale))
                                .foregroundStyle(caneInk)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        HStack(spacing: 5 * scale) {
                            Text(statusLabel)
                                .font(.copy(12.5 * scale, weight: isNextUp ? .bold : .semibold))
                                .foregroundStyle(caneInk.opacity(isNextUp ? 1 : 0.8))
                            if let total {
                                Text(total)
                                    .font(.copy(12.5 * scale))
                                    .foregroundStyle(caneInk.opacity(0.55))
                            }
                        }
                        .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    VStack(alignment: .trailing, spacing: 1 * scale) {
                        Text(reed.brandName)
                            .font(.brand(12 * scale))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(reed.strengthLabel)
                            .font(.numeric(12 * scale, weight: .bold))
                    }
                    .foregroundStyle(caneInk.opacity(0.75))
                    .frame(width: 62 * scale, alignment: .trailing)

                    // No chevron. Nothing is printed on a reed to tell you it
                    // can be picked up, and a disclosure arrow on cane is the
                    // interface leaking back onto the object — the same reason
                    // the bays lost their plus sign.
                }
                .padding(.horizontal, 14 * scale)
            }
    }

    private var status: ReedStatus { reed.status(against: estimate) }

    /// The reed that has rested longest says so, in place of "Ready". Every
    /// reed reading "Ready" answers what state they are in and none of them
    /// answers the only question the case is ever opened to settle.
    private var statusLabel: String {
        isNextUp && status == .ready ? "Play this next" : status.label
    }

    /// Hours only once there are any. "0.0h played" on a new reed is noise.
    private var total: String? {
        guard reed.playingMinutes > 0 else { return nil }
        return "· \(Format.hours(minutes: reed.playingMinutes))h"
    }
}

#Preview {
    CaseView()
        .modelContainer(ModelContainer.preview())
}
