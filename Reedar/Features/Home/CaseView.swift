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
            VStack(spacing: 14) {
                header
                caseBody
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            LogoMark(size: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text("Reedar")
                    .font(.title(24))
                    .foregroundStyle(Palette.ink)
                Text(subtitle)
                    .font(.copy(13))
                    .foregroundStyle(Palette.inkSecondary)
            }

            Spacer()

            Button {
                showingData = true
            } label: {
                Image(systemName: "chart.bar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Palette.surfaceRaised)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Palette.hairline, lineWidth: 1)
                    )
            }
            .buttonStyle(.sink)
            .accessibilityLabel("Lifespan data")
        }
        .padding(.top, 4)
    }

    private var subtitle: String {
        if carry?.isLifted == true { return "Drop it in any slot" }
        if activeReeds.isEmpty { return "Tap a slot to add your first reed" }
        if let next = nextUp { return "\(next.slotTitle) has rested longest" }
        return weekMinutes > 0
            ? "You played \(Format.duration(minutes: weekMinutes)) this week"
            : "You haven't logged anything this week"
    }

    /// The reed that has rested longest, if there's a useful answer.
    private var nextUp: Reed? { Rotation.nextUp(among: activeReeds) }

    // MARK: The case

    private var caseBody: some View {
        GeometryReader { geo in
            let height = (geo.size.height - slotGap * CGFloat(slotCount - 1)) / CGFloat(slotCount)
            // The slot the carried reed would drop into, if one is in hand.
            let hovered: Int? = carry.flatMap {
                $0.isLifted ? hoverSlot($0, height: height) : nil
            }
            let occupied = occupiedSlots(height: height)

            ZStack(alignment: .top) {
                // The mouldings never move.
                VStack(spacing: slotGap) {
                    ForEach(0..<slotCount, id: \.self) { index in
                        SlotMoulding(index: index,
                                     isEmpty: !occupied.contains(index),
                                     isTarget: hovered == index) { Color.clear }
                            .frame(height: height)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard carry == nil, slots[index] == nil else { return }
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
                        expectation: LifespanStats.expectation(for: reed, among: allReeds),
                        isNextUp: reed.id == nextUp?.id
                    )
                    .padding(4)
                    .frame(height: height)
                    .scaleEffect(isCarried ? 1.03 : 1)
                    .rotationEffect(.degrees(isCarried ? -0.7 : 0))
                    // A reed resting in its slot still touches the floor of it:
                    // a tight contact shadow, which grows and softens the
                    // moment the reed is lifted into the hand.
                    //
                    // Flattened first, or the shadow reaches every view inside
                    // and each letter printed on the cane casts its own.
                    .compositingGroup()
                    .shadow(color: .black.opacity(isCarried ? 0.6 : 0.55),
                            radius: isCarried ? 16 : 3, y: isCarried ? 10 : 1.5)
                    .offset(y: base + (isCarried ? (carry?.translation ?? 0) : 0))
                    // Settled reeds glide to their new slot; the carried one
                    // tracks the finger with no animation in the way.
                    .animation(isCarried ? nil : .spring(response: 0.3, dampingFraction: 0.8),
                               value: base)
                    .zIndex(isCarried ? 1 : 0)
                    .onTapGesture {
                        guard carry == nil else { return }
                        Haptics.reedLifted()
                        path.append(reed)
                    }
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
        .padding(7)
        .background { tray }
        .padding(6)
        .frame(maxHeight: .infinity)
        .background { caseShell }
    }

    /// The shell: the outside of the case, the only part of it that catches
    /// the light square on.
    private var caseShell: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.radiusCase, style: .continuous)
        return shape
            .fill(Palette.caseFace)
            .overlay { Light.bevel(shape, highlight: 0.11, shade: 0.4) }
            .overlay { shape.strokeBorder(Palette.hairline, lineWidth: 1) }
            .clipShape(shape)
            .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
    }

    /// The tray the slots are cut into, sunk into the shell. Three depths —
    /// shell, tray, slot — is what makes the slots read as machined out of
    /// something solid rather than drawn on top of it.
    private var tray: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.radiusCase - 6, style: .continuous)
        return shape
            .fill(Palette.trayFace)
            .overlay { Light.topShade(shape, radius: 3, width: 4, opacity: 0.6) }
            .overlay { Light.bottomCatch(shape, width: 1.2, opacity: 0.05) }
            .clipShape(shape)
    }

    // MARK: Carrying

    private func carryGesture(for reed: Reed, at index: Int, height: CGFloat) -> some Gesture {
        LongPressGesture(minimumDuration: 0.2)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .updating($carry) { value, state, transaction in
                switch value {
                case .first(true):
                    // Held long enough — the reed is in your hand.
                    state = Carry(id: reed.id, from: index, isLifted: true)
                    transaction.animation = .spring(response: 0.25, dampingFraction: 0.65)
                case .second(true, let drag):
                    state = Carry(id: reed.id, from: index,
                                  translation: drag?.translation.height ?? 0,
                                  isLifted: true)
                default:
                    state = nil
                }
            }
            .onEnded { value in
                guard case .second(true, let drag) = value else { return }
                drop(reed, from: index, translation: drag?.translation.height ?? 0, height: height)
            }
    }

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
    var isTarget: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.radiusSlot, style: .continuous)
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
                    Light.topShade(shape, radius: 3, width: 3.5, opacity: 0.85)
                    Light.bottomCatch(shape, width: 1.4, opacity: 0.07)

                    shape.strokeBorder(isTarget ? Palette.accent.opacity(0.8) : Palette.hairline,
                                       lineWidth: isTarget ? 2 : 1)
                }
                .clipShape(shape)
                .animation(.mechanical, value: isTarget)
            }
            .contentShape(Rectangle())
    }

    /// An empty slot isn't nothing — it's a numbered bay. Marked faintly, in
    /// one flat tone: at this size a cut-in letter is a smudge, not a letter.
    private var engraving: some View {
        HStack {
            Text(indexLabel(index + 1))
                .font(.numeric(13, weight: .bold))
                .tracking(1)
            Spacer()
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(Color.white.opacity(0.07))
        .padding(.horizontal, 16)
        .opacity(isTarget ? 0 : 1)
        .animation(.mechanical, value: isTarget)
    }
}

/// A reed lying in a slot: name and hours on the planed end, brand printed on
/// the bark. No background of its own — the slot provides it.
struct ReedRow: View {
    var reed: Reed
    var expectation: LifespanSummary?
    /// The reed that has rested longest — the one to play next.
    var isNextUp: Bool = false

    private var wear: Double {
        guard let expectation, expectation.averageMinutes > 0 else { return 0 }
        return Double(reed.playingMinutes) / expectation.averageMinutes
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

    private var status: ReedStatus { reed.status(against: expectation) }

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
