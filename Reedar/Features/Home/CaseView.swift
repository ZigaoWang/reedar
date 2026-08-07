import SwiftData
import SwiftUI

/// Home is the case: eight slots, a reed lying in each one you've filled.
/// Tap a reed to open it, tap any empty slot to put a reed there, press and
/// hold a reed to pick it up and move it.
struct CaseView: View {
    @Query(sort: \Reed.addedAt, order: .reverse) private var allReeds: [Reed]

    @State private var addingTo: SlotTarget?
    @State private var showingData = false
    @State private var path: [Reed] = []

    /// Everything about carrying a reed lives in gesture state, which SwiftUI
    /// resets on its own the moment the gesture ends or is cancelled. Storing
    /// it in `@State` is what left reeds stuck in the air.
    @GestureState private var carry: Carry?

    private let slotCount = 8
    private let slotGap: CGFloat = 8

    private struct Carry: Equatable {
        var id: UUID
        var from: Int
        var translation: CGFloat = 0
        var isLifted = false
    }

    private var activeReeds: [Reed] { allReeds.filter { !$0.isRetired } }

    /// The case laid out: one entry per slot, in the player's own order.
    private var slots: [Reed?] {
        var result = [Reed?](repeating: nil, count: slotCount)
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
    private func hoverSlot(_ carry: Carry, height: CGFloat) -> Int {
        let step = height + slotGap
        guard step > 0 else { return carry.from }
        let moved = Int((carry.translation / step).rounded())
        return min(max(carry.from + moved, 0), slotCount - 1)
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
    private func displaySlot(of reed: Reed, height: CGFloat) -> Int {
        let settled = slots.firstIndex { $0?.id == reed.id } ?? reed.slotIndex
        guard let carry, carry.isLifted,
              let carried = activeReeds.first(where: { $0.id == carry.id })
        else { return settled }

        if carry.id == reed.id { return carry.from }

        let hover = hoverSlot(carry, height: height)
        let preview = arrangement(moving: carried, from: carry.from, to: hover)
        return preview.firstIndex { $0?.id == reed.id } ?? settled
    }

    /// Which slots have a reed lying in them at this moment. A reed held in
    /// the hand has left its slot, so that slot is bare and says so — waiting
    /// for the drop to admit it left a numbered bay looking occupied.
    private func occupiedSlots(height: CGFloat) -> Set<Int> {
        var result: Set<Int> = []
        for reed in activeReeds {
            let isCarried = reed.id == carry?.id && carry?.isLifted == true
            guard !isCarried else { continue }
            result.insert(displaySlot(of: reed, height: height))
        }
        return result
    }

    /// The reed a given slot is showing right now, carry included.
    private func reed(inSlot index: Int, height: CGFloat) -> Reed? {
        activeReeds.first { reed in
            let isCarried = reed.id == carry?.id && carry?.isLifted == true
            return !isCarried && displaySlot(of: reed, height: height) == index
        }
    }

    private func slotY(_ index: Int, height: CGFloat) -> CGFloat {
        CGFloat(index) * (height + slotGap)
    }

    private var weekMinutes: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return allReeds
            .flatMap { $0.sessions ?? [] }
            .filter { $0.date >= cutoff }
            .reduce(0) { $0 + $1.playingMinutes }
    }

    var body: some View {
        NavigationStack(path: $path) {
            // The reader is laid out inside the safe area purely to be told
            // where it is: the case then ignores it and runs to the glass on
            // all four sides, and the insets come back as padding on what's
            // printed inside. A view that ignores the safe area is told its
            // insets are zero, so it can't ask for them itself.
            GeometryReader { proxy in
                caseBody(safeArea: proxy.safeAreaInsets)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
            }
            .background { Backdrop() }
            .navigationBarHidden(true)
            .sheet(item: $addingTo) { AddReedView(slot: $0.index) }
            .navigationDestination(isPresented: $showingData) { StatsView() }
            .navigationDestination(for: Reed.self) { ReedDetailView(reed: $0) }
            .task {
                normalizeSlots()
                let arguments = ProcessInfo.processInfo.arguments
                // The query may not have delivered yet when this first runs.
                if arguments.contains("-openReed") || arguments.contains("-openStats") {
                    try? await Task.sleep(for: .milliseconds(400))
                }
                if arguments.contains("-openReed"),
                   let first = activeReeds.first(where: { $0.isBreakingIn }) ?? activeReeds.first {
                    path = [first]
                }
                if arguments.contains("-openAdd") { addingTo = SlotTarget(index: 0) }
                if arguments.contains("-openStats") { showingData = true }
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
    /// bay numbers, reed names, statuses — reads off the left margin, and one
    /// centred element among them is an exception with nothing behind it. A
    /// centred name would also sit visibly off-centre next to the key, unless
    /// it were balanced by a spacer that exists only to be empty.
    private var headPlate: some View {
        HStack(alignment: .center, spacing: 11) {
            LogoMark(size: 26)

            VStack(alignment: .leading, spacing: 1) {
                // Same tracking as the launch veil sets it in. The mark and the
                // name are one lockup, and it should be the same lockup on the
                // way in as on the screen it hands over to.
                Text("Reedar")
                    .font(.title(17))
                    .tracking(0.4)
                    .foregroundStyle(Palette.ink)
                Text(plateDetail)
                    .font(.copy(12.5))
                    .foregroundStyle(Palette.inkSecondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            // The line changes as one piece of engraving rather than as a label
            // being swapped out.
            .animation(.settle, value: plateDetail)

            Spacer(minLength: 4)

            Button {
                showingData = true
            } label: {
                Image(systemName: "chart.bar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 42, height: 42)
                    .background {
                        // A key set into the plate, and the only thing on this
                        // screen that stands above the floor. It has to be cut
                        // from lighter stock than the floor to read that way —
                        // milled into it, which was the first attempt, just
                        // reads as a hole punched in the case.
                        let shape = RoundedRectangle(cornerRadius: Metrics.radiusKey,
                                                     style: .continuous)
                        shape
                            .fill(Palette.keyFace)
                            .overlay { Light.bevel(shape, highlight: 0.14, shade: 0.3) }
                            .overlay { shape.strokeBorder(Palette.hairline, lineWidth: 1) }
                            .clipShape(shape)
                            .shadow(color: .black.opacity(0.45), radius: 5, y: 2)
                    }
            }
            .buttonStyle(.sink)
            .accessibilityLabel("Lifespan data")
        }
        // Struck level with the reeds, not with the engraving inside the bays.
        // Those are two different left margins — 21 from the glass and 37 —
        // and the reeds' own edge is the one that matters, because eight of
        // them stack into the strongest vertical line on the screen. Set to
        // the inner one, the mark floated 16pt adrift of it.
        //
        // `ReedRow` is inset 4 inside its bay, so the plate matches that 4 and
        // the mark's left edge lands exactly on every reed's left edge.
        .padding(.leading, 4)
        .padding(.trailing, 4)
        .frame(height: 52)
    }

    /// The one line under the name. It carries the week, because that is the
    /// only thing on this screen the case itself can't show you: which reed to
    /// play is printed on the cane, and how each one is doing is printed beside
    /// it. How much you have actually played is nowhere else outside Lifespan.
    ///
    /// It used to say "3 reeds · 3 ready to play" as well, which is the screen
    /// counting something you can see eight bays of.
    private var plateDetail: String {
        if carry?.isLifted == true { return "Drop it in any slot" }
        if activeReeds.isEmpty { return "Tap any slot to add your first reed" }
        return weekMinutes > 0
            ? "\(Format.duration(minutes: weekMinutes)) this week"
            : "Nothing played this week"
    }

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
    private func caseBody(safeArea: EdgeInsets) -> some View {
        VStack(spacing: 10) {
            headPlate
            slotBed
        }
        .padding(.top, max(13, safeArea.top + 4))
        .padding(.bottom, max(13, safeArea.bottom + 4))
        // The margins the wall used to supply, kept to the point: every left
        // edge on this screen still lands on 37 from the glass, and every right
        // edge on 25, exactly as it did when there was a shell outside them.
        .padding(.leading, 17)
        .padding(.trailing, 25)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { ground }
    }

    private var slotBed: some View {
        GeometryReader { geo in
            let height = (geo.size.height - slotGap * CGFloat(slotCount - 1)) / CGFloat(slotCount)
            // The slot the carried reed would drop into, if one is in hand.
            let hovered: Int? = carry.flatMap {
                $0.isLifted ? hoverSlot($0, height: height) : nil
            }
            let occupied = occupiedSlots(height: height)

            ZStack(alignment: .top) {
                // The mouldings never move.
                // The first bare slot is the one that says what to do with a
                // bare slot. Saying it in all of them would be a column of the
                // same instruction; saying it in none of them, which is where
                // this started, left the only way to add a reed unmarked.
                //
                // Tested on `isLifted` rather than on there being a carry at
                // all: a carry now exists from the moment a finger lands on a
                // reed, and the invitation blinking out on touch-down — before
                // anything has actually been picked up — is a flicker.
                let inviting = carry?.isLifted == true
                    ? nil
                    : (0..<slotCount).first { !occupied.contains($0) }

                VStack(spacing: slotGap) {
                    ForEach(0..<slotCount, id: \.self) { index in
                        SlotMoulding(index: index,
                                     isEmpty: !occupied.contains(index),
                                     isInviting: index == inviting,
                                     isTarget: hovered == index) { Color.clear }
                            .frame(height: height)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard carry?.isLifted != true, slots[index] == nil else { return }
                                Haptics.slotTapped()
                                addingTo = SlotTarget(index: index)
                            }
                    }
                }

                // The reeds sit on top, each positioned over its slot. Moving
                // one is a change of offset, so it slides rather than redraws.
                ForEach(activeReeds) { reed in
                    let isCarried = carry?.id == reed.id && carry?.isLifted == true
                    let index = displaySlot(of: reed, height: height)
                    let base = slotY(index, height: height)

                    ReedRow(
                        reed: reed,
                        estimate: LifespanStats.estimate(for: reed, among: allReeds),
                        isNextUp: reed.id == nextUp?.id
                    )
                    .padding(4)
                    .frame(height: height)
                    // Every reed lies at the same height. The one to play next
                    // was drawn a shade proud of its bay for a while, as if
                    // somebody had half-pulled it out for you, and the first
                    // thing anyone asked about it was why that reed was bigger
                    // than the others — which is the question `ReedRow` already
                    // says a reed should never provoke. It says "Play this
                    // next" on the cane. That's the whole marking it needs.
                    .scaleEffect(isCarried ? 1.03 : 1)
                    .rotationEffect(.degrees(isCarried ? -0.7 : 0))
                    // A reed resting in its slot still touches the floor of it:
                    // a tight contact shadow, which grows and softens the
                    // moment the reed comes up off the mouldings.
                    //
                    // Flattened first, or the shadow reaches every view inside
                    // and each letter printed on the cane casts its own.
                    .compositingGroup()
                    .shadow(color: .black.opacity(isCarried ? 0.6 : 0.55),
                            radius: isCarried ? 16 : 3,
                            y: isCarried ? 10 : 1.5)
                    .offset(y: base + (isCarried ? (carry?.translation ?? 0) : 0))
                    // Settled reeds glide to their new slot; the carried one
                    // tracks the finger with no animation in the way.
                    .animation(isCarried ? nil : .spring(response: 0.3, dampingFraction: 0.8),
                               value: base)
                    .zIndex(isCarried ? 1 : 0)
                    // Opening the reed lives inside this too — see the comment
                    // on `carryGesture`.
                    .gesture(carryGesture(for: reed, at: index, height: height))
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
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
    /// are out of frame. Clipped to the display's own corner radius so the
    /// corners are struck by the phone rather than by a rectangle that happens
    /// to be behind it.
    ///
    /// The grain matters more here than anywhere. This is the largest single
    /// surface in the app by a long way, and at that size a flat fill stops
    /// being a material and becomes a rectangle.
    private var ground: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.radiusCase, style: .continuous)
        return shape
            .fill(Palette.trayFace)
            .grained(0.025)
            .clipShape(shape)
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
    private func carryGesture(for reed: Reed, at index: Int, height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .updating($carry) { value, state, transaction in
                let lifted = state?.isLifted == true || travelled(value) > Self.liftDistance
                // Only on the frame it comes up, so the catch-up to the finger
                // is sprung and everything after it tracks with no lag.
                if lifted, state?.isLifted != true {
                    transaction.animation = .spring(response: 0.25, dampingFraction: 0.65)
                }
                state = Carry(id: reed.id,
                              from: index,
                              translation: lifted ? value.translation.height : 0,
                              isLifted: lifted)
            }
            .onEnded { value in
                guard travelled(value) > Self.liftDistance else {
                    // It never came out of its slot. That was a tap.
                    Haptics.reedLifted()
                    path.append(reed)
                    return
                }
                drop(reed, from: index, translation: value.translation.height, height: height)
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

    private func drop(_ reed: Reed, from: Int, translation: CGFloat, height: CGFloat) {
        let target = hoverSlot(Carry(id: reed.id, from: from, translation: translation),
                               height: height)
        guard target != from else { return }

        let moved = arrangement(moving: reed, from: from, to: target)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
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

/// The moulded recess in the case. Drawn once per slot, whether or not a reed
/// is lying in it.
struct SlotMoulding<Content: View>: View {
    var index: Int = 0
    var isEmpty: Bool = false
    /// The one bare slot that spells out what a bare slot is for.
    var isInviting: Bool = false
    var isTarget: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        // The bay is the reed's own outline, not a rounded box: a case is
        // moulded to hold reeds, and a squared-off trough around an arched tip
        // leaves a crescent of dead space that reads as a mistake. The heel
        // corners get a radius the reed itself does not have, so the end bays
        // stop cutting across the shell's own rounding.
        let shape = ReedShape(axis: .horizontalReversed, heelRadius: 9)
        // Color.clear guarantees the moulding has a size even when the slot is
        // empty — an empty conditional on its own lays out at zero height.
        return ZStack {
            Color.clear
            if isEmpty { engraving }
            content
        }
            .padding(4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    // The floor of the recess, in shadow under its near wall.
                    shape.fill(Palette.recessFace)
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
                    Light.topShade(shape, radius: 3.5, width: 4.5, opacity: 0.95)
                    Light.bottomCatch(shape, width: 1.8, opacity: 0.14)

                    shape.stroke(isTarget ? Palette.accent.opacity(0.8) : Palette.hairline,
                                 lineWidth: isTarget ? 4 : 2)
                }
                .clipShape(shape)
                .animation(.mechanical, value: isTarget)
            }
            .contentShape(Rectangle())
    }

    /// An empty slot isn't nothing — it's a numbered bay. Marked in one flat
    /// tone: at this size a cut-in letter is a smudge, not a letter.
    ///
    /// It used to be marked at 7% white, which on a black moulding is a number
    /// you can only find if you already know it's there — and the `+` beside it
    /// was the only clue that tapping a slot does anything. A bay stamped too
    /// faint to read isn't restraint, it's a mark that failed to print.
    private var engraving: some View {
        HStack(spacing: 10) {
            Text(indexLabel(index + 1))
                .font(.numeric(13, weight: .bold))
                .tracking(1)
                .foregroundStyle(Color.white.opacity(0.16))

            if isInviting {
                Text("Add a reed")
                    .font(.copy(13))
                    .foregroundStyle(Color.white.opacity(0.3))
            }

            Spacer()

            Image(systemName: "plus")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(isInviting ? 0.3 : 0.16))
        }
        .lineLimit(1)
        .padding(.horizontal, 16)
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
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            if reed.isFavourite {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(caneInk.opacity(0.75))
                            }
                            Text(reed.slotTitle)
                                .font(.heading(16))
                                .foregroundStyle(caneInk)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        HStack(spacing: 5) {
                            Text(statusLabel)
                                .font(.copy(12.5, weight: isNextUp ? .bold : .semibold))
                                .foregroundStyle(caneInk.opacity(isNextUp ? 1 : 0.8))
                            if let total {
                                Text(total)
                                    .font(.copy(12.5))
                                    .foregroundStyle(caneInk.opacity(0.55))
                            }
                        }
                        .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    VStack(alignment: .trailing, spacing: 1) {
                        Text(reed.brandName)
                            .font(.system(size: 12, weight: .bold, design: .serif))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(reed.strengthLabel)
                            .font(.numeric(12, weight: .bold))
                    }
                    .foregroundStyle(caneInk.opacity(0.75))
                    .frame(width: 62, alignment: .trailing)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(caneInk.opacity(0.45))
                }
                .padding(.leading, 14)
                .padding(.trailing, 14)
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
