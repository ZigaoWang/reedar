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

        var path = Path()
        path.move(to: p(0, 0))                      // square heel corner
        path.addLine(to: p(start, 0))               // straight parallel side
        path.addCurve(to: p(start, 1),
                      control1: p(control, 0.06),
                      control2: p(control, 0.94))
        path.addLine(to: p(0, 1))                   // square heel corner
        path.closeSubpath()
        return path
    }
}

/// The scraped area, as a rounded U opening toward the tip. Pale cane sits
/// inside it; the two lower corners outside the U stay bark.
private struct VampShape: Shape {
    var axis: ReedAxis = .horizontal

    /// Where the bark ends, as a fraction of the length from the heel.
    static let barkLine = 0.31
    /// Where the U's walls meet the bark line at the edges.
    private let wall = 0.43
    /// The rounded bottom of the U, sitting just above the bark line.
    private let base = 0.35

    func path(in rect: CGRect) -> Path {
        let p = pointMapper(axis: axis, rect: rect)

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

/// A reed. Flat colours only — bark below the cut line, pale cane inside the
/// vamp, palest at the tip — with fine fibre running the full length.
struct ReedView: View {
    var axis: ReedAxis = .horizontal
    /// 0 = fresh, 1 = at its expected lifespan, beyond that it's on borrowed time.
    var wear: Double = 0
    var stamp: String = ""
    var strengthStamp: String = ""
    var isRetired: Bool = false

    // Flat, hardcoded, identical in every appearance.
    private let bark = Color(hex: 0xD2A85F)
    private let vamp = Color(hex: 0xEFE2BE)
    private let fibre = Color(hex: 0x9A7C42)
    private let outline = Color(hex: 0xA9853F)
    private let worn = Color(hex: 0x8A7346)

    private var shape: ReedShape { ReedShape(axis: axis) }

    var body: some View {
        GeometryReader { geo in
            let p = pointMapper(axis: axis, rect: CGRect(origin: .zero, size: geo.size))
            let across = axis.isHorizontal ? geo.size.height : geo.size.width

            ZStack {
                // Bark: the whole reed starts as this.
                bark

                // The vamp: pale scraped cane inside the U.
                VampShape(axis: axis).fill(vamp)

                // Fine fibre, running the full length through vamp and bark alike.
                Canvas { context, size in
                    let span = axis.isHorizontal ? size.height : size.width
                    let count = max(16, Int(span / 1.1))
                    for i in 0..<count {
                        let t = (Double(i) + 0.5) / Double(count)
                        // Deterministic, so the grain is identical every launch.
                        let h = Double((i &* 2654435761) % 1000) / 1000
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
                                       with: .color(fibre.opacity(0.06 + h * 0.13)),
                                       lineWidth: h > 0.86 ? 1.1 : 0.6)
                    }
                }
                .allowsHitTesting(false)

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
