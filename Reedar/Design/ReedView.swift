import SwiftUI

/// Which way the reed is lying.
enum ReedAxis {
    /// Lying down, tip to the right.
    case horizontal
    /// Lying down, tip to the left, heel on the right.
    case horizontalReversed
    /// Standing up, tip at the top.
    case vertical

    var isHorizontal: Bool { self != .vertical }
}

/// Normalised coordinates: `u` runs 0 at the heel to 1 at the tip, `v` runs 0
/// to 1 across the width. One definition serves every orientation.
private func pointMapper(axis: ReedAxis, rect: CGRect) -> (Double, Double) -> CGPoint {
    { u, v in
        switch axis {
        case .horizontal:
            CGPoint(x: rect.minX + rect.width * u, y: rect.minY + rect.height * v)
        case .horizontalReversed:
            CGPoint(x: rect.maxX - rect.width * u, y: rect.minY + rect.height * v)
        case .vertical:
            CGPoint(x: rect.minX + rect.width * v, y: rect.maxY - rect.height * u)
        }
    }
}

/// The outline: straight parallel sides, a perfectly flat heel with square
/// corners, and a generously rounded tip with a gentle convex curve across it.
struct ReedShape: Shape {
    var axis: ReedAxis = .horizontal
    /// How far to break the square corners at the heel, in points.
    ///
    /// A reed's heel is cut square and stays that way. The case's bays are
    /// moulded, and a moulded corner has a radius on it — which also keeps the
    /// last bay's sharp corner from running into the shell's own rounding.
    var heelRadius: CGFloat = 0

    /// How deep the thumb relief is cut, in points, or 0 for none.
    ///
    /// A reed lying flush in a moulded bay can't be picked up — there's nothing
    /// to get a nail under — so a case that holds them this way scallops the
    /// near wall away at one end. It's the detail that explains what the bay is
    /// for, and the reason a bay reads as tooling rather than as a rounded
    /// rectangle. Only the bay has one; a reed doesn't have a bite out of it.
    ///
    /// Depth is the number that matters, because the wall it eats into is only
    /// as thick as the gap between two bays. Cut deeper than that and the
    /// scallop breaks through into the bay below, which is what the first
    /// attempt did — it read as a spike between them rather than as a scoop.
    var thumbRelief: CGFloat = 0

    /// A relief is far wider than it is deep — a scoop for a thumb, not a
    /// notch. Held at a fixed ratio so the one number above sets both.
    private static let reliefSpread: CGFloat = 5

    /// Where along the bay the relief sits, 0 at the heel and 1 at the tip.
    /// Near the heel: that's the sturdy end, and the end you'd actually lift
    /// from rather than the shaved tip you'd break.
    ///
    /// Static, not a stored property — a private stored property drags the
    /// synthesised memberwise initialiser down to private with it.
    private static let reliefAt: Double = 0.24

    func path(in rect: CGRect) -> Path {
        let p = pointMapper(axis: axis, rect: rect)
        let along = axis.isHorizontal ? rect.width : rect.height
        let across = axis.isHorizontal ? rect.height : rect.width

        // Tip geometry scales with the reed's WIDTH, so the tip looks the same
        // whether the reed stands up or lies long and thin in a slot.
        //
        // The whole end is ONE smooth arch: a single cubic from one side to the
        // other, shallow and low. Rounding the corners separately and then
        // bulging the middle is what put a point on the end before.
        let depth = across * 0.26
        let dd = along > 0 ? depth / along : 0.12
        let start = 1 - dd
        // Places the crown of the arch exactly on the tip edge.
        let control = 1 + dd / 3

        // The heel break, expressed in each axis's own normalised units so it
        // comes out round rather than oval on a reed drawn long and thin.
        let du = along > 0 ? min(heelRadius / along, 0.2) : 0
        let dv = across > 0 ? min(heelRadius / across, 0.45) : 0

        // The relief, in each axis's own units so the scoop keeps its
        // proportions on a bay drawn long and thin.
        let ru = along > 0 ? min(thumbRelief * Self.reliefSpread / along, 0.2) : 0
        let rv = across > 0 ? min(thumbRelief / across, 0.2) : 0

        var path = Path()
        path.move(to: p(du, 0))
        path.addLine(to: p(start, 0))               // straight parallel side
        path.addCurve(to: p(start, 1),
                      control1: p(control, 0.06),
                      control2: p(control, 0.94))
        if ru > 0 {
            // Running back along the near wall toward the heel, the wall gives
            // way for a moment. A cubic with both handles standing straight off
            // the ends at 4/3 of the depth is the usual approximation of a
            // half-round; a single quadratic through the middle, which is what
            // this was, draws a parabola and comes to a point.
            path.addLine(to: p(Self.reliefAt + ru, 1))
            path.addCurve(to: p(Self.reliefAt - ru, 1),
                          control1: p(Self.reliefAt + ru, 1 + rv * 4 / 3),
                          control2: p(Self.reliefAt - ru, 1 + rv * 4 / 3))
        }
        path.addLine(to: p(du, 1))
        if du > 0 {
            path.addQuadCurve(to: p(0, 1 - dv), control: p(0, 1))
            path.addLine(to: p(0, dv))
            path.addQuadCurve(to: p(du, 0), control: p(0, 0))
        } else {
            path.addLine(to: p(0, 1))               // square heel corner
        }
        path.closeSubpath()
        return path
    }
}

/// The scraped area, as a rounded U opening toward the tip. Pale cane sits
/// inside it; the two lower corners outside the U stay bark.
private struct VampShape: Shape {
    var axis: ReedAxis = .horizontal

    /// Roughly where the scrape begins, for shading that has to key off it.
    static let barkLine = 0.38
    /// Where the U's walls meet the edges, as a fraction of the length.
    private let wall = 0.43
    /// How far the middle of the U reaches back past the walls, as a fraction
    /// of the reed's WIDTH.
    private let reach = 0.27

    func path(in rect: CGRect) -> Path {
        let p = pointMapper(axis: axis, rect: rect)
        let along = axis.isHorizontal ? rect.width : rect.height
        let across = axis.isHorizontal ? rect.height : rect.width

        // Like the tip, the scrape is set by the reed's WIDTH. Held as a
        // fraction of the length instead, a reed drawn long and thin in a slot
        // gets a long lazy arc and one drawn true to life gets a tight deep
        // one — the same code, two different objects.
        let base = wall - (along > 0 ? across * reach / along : 0.08)

        var path = Path()
        path.move(to: p(1.05, -0.05))
        path.addLine(to: p(wall, -0.05))
        path.addCurve(to: p(wall, 1.05),
                      control1: p(base, 0.34),
                      control2: p(base, 0.66))
        path.addLine(to: p(1.05, 1.05))
        path.closeSubpath()
        return path
    }
}

/// A reed. Cane is a tube split lengthways, so the bark side is gently domed
/// across its width, and the scraped vamp is planed flat with a heart left
/// standing down the spine. Four clean layers say that — dome, vamp, heart,
/// fibre — and nothing is blurred. Softening the edges of cane is what makes
/// it look like mud rather than a reed.
struct ReedView: View {
    var axis: ReedAxis = .horizontal
    /// 0 = fresh, 1 = at its expected lifespan, beyond that it's on borrowed time.
    var wear: Double = 0
    var stamp: String = ""
    var strengthStamp: String = ""
    var isRetired: Bool = false

    // Hardcoded, identical in every appearance. Clean cane tones: bright
    // golden bark, warm bone vamp. Everything here is either a flat colour or
    // one clean gradient — stacked blurs turn cane into mud.
    private let bark = Color(hex: 0xD9AA4F)
    /// The vamp, from the bark line to the tip: thick coloured cane, then the
    /// working middle, then bone where there is almost nothing left of it.
    private let vampThick = Color(hex: 0xE0CB94)
    private let vamp = Color(hex: 0xEDE0BA)
    private let vampThin = Color(hex: 0xF6EFDA)
    /// The spine of cane left standing down the middle of the vamp.
    private let heartTone = Color(hex: 0xC7A661)
    private let fibre = Color(hex: 0xA07E3C)
    private let outline = Color(hex: 0x8C6A28)
    private let worn = Color(hex: 0x8A7346)

    /// The heel is cut square, but a cut edge is never a perfect right angle
    /// and a hard 90° corner nested inside a moulded bay pinches the clearance
    /// at the corners to nothing. Five points reads as square and sits
    /// concentric inside the bay's own nine.
    private var shape: ReedShape { ReedShape(axis: axis, heelRadius: 5) }

    var body: some View {
        GeometryReader { geo in
            let across = axis.isHorizontal ? geo.size.height : geo.size.width

            ZStack {
                // Bark: the whole reed starts as this.
                bark

                // The dome. Bark is the outside of a split tube, so it carries
                // the tube's curvature — and only it does. Drawn before the
                // vamp so the planed area covers it.
                curvature

                // The vamp: scraped cane, thick and still coloured where the
                // bark ends, thinning to bone at the tip.
                VampShape(axis: axis).fill(lengthwise([
                    .init(color: vampThick, location: VampShape.barkLine),
                    .init(color: vamp, location: 0.72),
                    .init(color: vampThin, location: 1),
                ]))

                // The heart: the ridge of cane left standing down the spine,
                // with a thinner rail either side of it. This is the shading
                // that says "planed" rather than "tinted lozenge".
                heart

                fibres

                // Where the blade stopped. One clean line, no smear: this is a
                // cut, and a cut has an edge.
                VampShape(axis: axis)
                    .stroke(outline.opacity(0.5), lineWidth: 0.75)

                // Wear: only the vamp dulls. Tinting past the cut line put a
                // hard edge across the bark and left it looking two-toned.
                if wear > 0 {
                    VampShape(axis: axis)
                        .fill(worn.opacity(min(max(wear, 0), 1.2) * 0.4))
                        .animation(.settle, value: wear)
                }

                if !stamp.isEmpty {
                    stampText(across: across)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: stampAlignment)
                        .padding(stampEdge, across * 0.4)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .compositingGroup()
            .clipShape(shape)
            .overlay { shape.stroke(outline.opacity(0.55), lineWidth: 1) }
            .saturation(isRetired ? 0.4 : 1)
        }
    }

    // MARK: Material

    /// A gradient running heel to tip, whichever way the reed lies.
    private func lengthwise(_ stops: [Gradient.Stop]) -> LinearGradient {
        let (start, end): (UnitPoint, UnitPoint) = switch axis {
        case .horizontal: (.leading, .trailing)
        case .horizontalReversed: (.trailing, .leading)
        case .vertical: (.bottom, .top)
        }
        return LinearGradient(stops: stops, startPoint: start, endPoint: end)
    }

    /// A gradient running across the width.
    private func widthwise(_ stops: [Gradient.Stop]) -> LinearGradient {
        let (start, end): (UnitPoint, UnitPoint) = axis.isHorizontal
            ? (.top, .bottom)
            : (.leading, .trailing)
        return LinearGradient(stops: stops, startPoint: start, endPoint: end)
    }

    /// The heart, and the two rails either side of it. Strongest just above
    /// the bark line where the cane is thickest, gone by the tip.
    private var heart: some View {
        widthwise([
            // The rails are thin, but they are also the part of the reed
            // turning away from the light, so they go down, not up.
            .init(color: .black.opacity(0.16), location: 0),
            .init(color: .clear, location: 0.17),
            .init(color: heartTone.opacity(0.26), location: 0.38),
            .init(color: heartTone.opacity(0.32), location: 0.5),
            .init(color: heartTone.opacity(0.26), location: 0.62),
            .init(color: .clear, location: 0.83),
            .init(color: .black.opacity(0.18), location: 1),
        ])
        .mask {
            VampShape(axis: axis).fill(lengthwise([
                .init(color: .white, location: VampShape.barkLine),
                .init(color: .white.opacity(0.85), location: 0.7),
                .init(color: .white.opacity(0.45), location: 1),
            ]))
        }
    }

    /// The dome. Deliberately asymmetric — the crown of the arch sits nearer
    /// the light than the middle, which is what stops it reading as a tube
    /// drawn with a symmetrical airbrush.
    private var curvature: some View {
        widthwise([
            .init(color: .black.opacity(0.20), location: 0),
            .init(color: .clear, location: 0.16),
            .init(color: .white.opacity(0.13), location: 0.34),
            .init(color: .clear, location: 0.64),
            .init(color: .black.opacity(0.07), location: 0.86),
            .init(color: .black.opacity(0.22), location: 1),
        ])
    }

    /// Fine fibre running the full length, through vamp and bark alike. It
    /// fades as the cane thins, because there is less of it left to see.
    private var fibres: some View {
        Canvas { context, size in
            let span = axis.isHorizontal ? size.height : size.width
            let count = max(16, Int(span / 1.1))
            for i in 0..<count {
                let t = (Double(i) + 0.5) / Double(count)
                // Deterministic, so the grain is identical every launch.
                let h = Double((i &* 2654435761) % 1000) / 1000
                // Fibre near the domed edges is turning away from us, so it
                // foreshortens into a fainter, finer line.
                let facing = 0.45 + 0.55 * sin(t * .pi)
                var line = Path()
                if axis.isHorizontal {
                    let y = span * t
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: size.width, y: y))
                } else {
                    let x = span * t
                    line.move(to: CGPoint(x: x, y: 0))
                    line.addLine(to: CGPoint(x: x, y: size.height))
                }
                context.stroke(line,
                               with: .color(fibre.opacity((0.03 + h * 0.10) * facing)),
                               lineWidth: h > 0.9 ? 0.9 : 0.5)
            }
        }
        .mask {
            // Bark hides most of the grain; the scrape exposes it. It fades
            // again right at the tip, where there is barely any cane left.
            lengthwise([
                .init(color: .white.opacity(0.45), location: 0),
                .init(color: .white.opacity(0.5), location: VampShape.barkLine),
                .init(color: .white, location: 0.55),
                .init(color: .white.opacity(0.55), location: 1),
            ])
        }
        .allowsHitTesting(false)
    }

    private var stampAlignment: Alignment {
        switch axis {
        case .horizontal: .leading
        case .horizontalReversed: .trailing
        case .vertical: .bottom
        }
    }

    private var stampEdge: Edge.Set {
        switch axis {
        case .horizontal: .leading
        case .horizontalReversed: .trailing
        case .vertical: .bottom
        }
    }

    /// Printing on the bark. Reads left to right whichever way the reed lies.
    private func stampText(across: CGFloat) -> some View {
        HStack(spacing: across * 0.1) {
            Text(stamp)
            if !strengthStamp.isEmpty {
                Text(strengthStamp)
            }
        }
        .font(.system(size: max(6, across * (axis.isHorizontal ? 0.16 : 0.14)),
                      weight: .semibold))
        .foregroundStyle(Color(hex: 0x6B4A20).opacity(0.55))
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .padding(.horizontal, across * 0.08)
    }
}

/// Pressing a reed lifts it out of its slot rather than shrinking it — you're
/// picking a reed up, not tapping a button.
struct ReedLiftStyle: ButtonStyle {
    var axis: ReedAxis = .horizontalReversed

    func makeBody(configuration: Configuration) -> some View {
        let lifted = configuration.isPressed
        return configuration.label
            .offset(x: lifted ? (axis == .horizontalReversed ? 3 : -3) : 0,
                    y: lifted ? -4 : 0)
            .scaleEffect(lifted ? 1.015 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: lifted)
    }
}

extension ButtonStyle where Self == ReedLiftStyle {
    static var reedLift: ReedLiftStyle { ReedLiftStyle() }
}
