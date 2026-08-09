import SwiftUI

/// Depth vocabulary: raised off the ground, cut into it, or flush.
enum Depth {
    case low, medium, high

    var shadowRadius: CGFloat {
        switch self {
        case .low: 4
        case .medium: 10
        case .high: 20
        }
    }

    var shadowOffset: CGFloat {
        switch self {
        case .low: 2
        case .medium: 5
        case .high: 10
        }
    }
}

extension View {
    /// A surface sitting above the ground: one lit top edge, one soft shadow.
    func raised(radius: CGFloat = Metrics.radius, depth: Depth = .medium) -> some View {
        modifier(RaisedSurface(radius: radius, depth: depth))
    }

    /// Cut into the surface behind it.
    func milled(radius: CGFloat = Metrics.radiusInner) -> some View {
        modifier(MilledSurface(radius: radius))
    }

    /// A whisper of grain. Nothing manufactured is perfectly flat, and a matte
    /// surface without it reads as a filled rectangle rather than a material.
    func grained(_ opacity: Double = 0.035) -> some View {
        overlay { Grain(opacity: opacity) }
    }
}

// MARK: - Light

/// The light in this app comes from above, always. Every bevel, catch and
/// shadow below is derived from that one fact, which is what keeps the
/// mouldings looking machined rather than decorated.
///
/// None of the geometry here knows about the appearance, and that is the point:
/// a recess is shaded along its near wall and catches light along its far one
/// whether it is cut in black plastic or bone. What the two materials disagree
/// about is only how hard they take the light, and that lives in `Palette` as a
/// pair of colours. Everything below simply strokes whichever one it is given.
enum Light {
    /// A ring of shadow that only shows along the top inside edge — the wall of
    /// a recess, lit from above.
    ///
    /// "Only" is doing real work here, and for a long time it wasn't true. This
    /// strokes the whole shape and offsets the ring down by less than it blurs
    /// it, so a band of shade survived along the sides and the bottom as well:
    /// a recess lit from everywhere, which is a recess lit from nowhere. On
    /// black plastic that band is black on black and nobody could see it. On
    /// pale plastic it reads as a grey halo drawn all the way round whatever is
    /// lying in the bay, which makes a bright reed look like it is floating in
    /// smoke.
    ///
    /// The mask is the fix, not a smaller number: the wall that faces the light
    /// is at the top, so the shade is at the top and gone by halfway down.
    static func topShade<S: Shape>(_ shape: S,
                                   radius: CGFloat = 2.5,
                                   width: CGFloat = 3,
                                   color: Color = Palette.recessShade) -> some View {
        shape
            .stroke(color, lineWidth: width)
            .blur(radius: radius)
            .offset(y: width * 0.42)
            .mask { wall(from: .top) }
            .clipShape(shape)
    }

    /// The opposite: a fine catch of light along the bottom inside edge, where
    /// the far wall of a recess turns back up toward the light.
    static func bottomCatch<S: Shape>(_ shape: S,
                                      width: CGFloat = 1.2,
                                      color: Color = Palette.recessCatch) -> some View {
        shape
            .stroke(color, lineWidth: width)
            .blur(radius: width * 0.5)
            .offset(y: -width)
            .mask { wall(from: .bottom) }
            .clipShape(shape)
    }

    /// One wall of a recess and not the other three: solid at the edge the
    /// light comes from, gone by the middle.
    private static func wall(from edge: UnitPoint) -> some View {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: 0.18),
                .init(color: .clear, location: 0.5),
            ],
            startPoint: edge,
            endPoint: edge == .top ? .bottom : .top
        )
    }

    /// A bevel on a raised surface: bright along the top edge, dark along the
    /// bottom, both inside the shape.
    static func bevel<S: Shape>(_ shape: S,
                                highlight: Color = Palette.bevelHighlight,
                                shade: Color = Palette.bevelShade) -> some View {
        ZStack {
            shape
                .stroke(highlight, lineWidth: 1.4)
                .blur(radius: 0.7)
                .offset(y: 0.8)
            shape
                .stroke(shade, lineWidth: 1.4)
                .blur(radius: 0.7)
                .offset(y: -0.8)
        }
        .clipShape(shape)
    }
}

// MARK: - Grain

/// One small tile of monochrome noise, generated once and reused everywhere.
/// Tiling an image costs nothing at draw time; drawing thousands of dots per
/// frame in a Canvas does.
enum Texture {
    static let grain: Image? = makeGrain()

    private static func makeGrain(size: Int = 96) -> Image? {
        let space = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil,
                                      width: size, height: size,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
              let data = context.data
        else { return nil }

        let stride = context.bytesPerRow
        let bytes = data.bindMemory(to: UInt8.self, capacity: stride * size)
        // A plain LCG: the grain is identical on every launch and every device.
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        for y in 0..<size {
            for x in 0..<size {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                // Pulled toward mid-grey so the overlay blend stays gentle.
                let value = UInt8(96 + (seed >> 40) % 64)
                let offset = y * stride + x * 4
                bytes[offset] = value
                bytes[offset + 1] = value
                bytes[offset + 2] = value
            }
        }
        return context.makeImage().map { Image(decorative: $0, scale: 1) }
    }
}

struct Grain: View {
    var opacity: Double = 0.035

    /// Overlay noise reads much louder on a pale face than on a black one —
    /// the same tile that says "moulded" on black ABS says "dirty" on bone.
    /// Pulled back rather than switched off: a matte surface with no grain at
    /// all is a filled rectangle in either material.
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if let grain = Texture.grain {
            grain
                .resizable(resizingMode: .tile)
                .blendMode(.overlay)
                .opacity(scheme == .light ? opacity * 0.25 : opacity)
                .allowsHitTesting(false)
        }
    }
}

struct RaisedSurface: ViewModifier {
    var radius: CGFloat
    var depth: Depth

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            .background {
                shape
                    .fill(Palette.surfaceFace)
                    .overlay { Light.bevel(shape) }
                    .overlay { shape.strokeBorder(Palette.hairline, lineWidth: 1) }
                    .grained(0.03)
                    .clipShape(shape)
            }
            .compositingGroup()
            .shadow(color: Palette.dropShadow,
                    radius: depth.shadowRadius,
                    y: depth.shadowOffset)
    }
}

struct MilledSurface: ViewModifier {
    var radius: CGFloat

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            .background {
                shape
                    .fill(Palette.recessFace)
                    .overlay { Light.topShade(shape) }
                    .overlay { Light.bottomCatch(shape) }
                    .overlay { shape.strokeBorder(Palette.hairline, lineWidth: 1) }
                    .grained(0.025)
                    .clipShape(shape)
            }
    }
}

/// The app's general-purpose container.
struct Panel<Content: View>: View {
    var padding: CGFloat = Metrics.gutter
    var depth: Depth = .medium
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .raised(depth: depth)
    }
}

/// A recess cut into a panel.
struct Well<Content: View>: View {
    var padding: CGFloat = Metrics.gutter
    var radius: CGFloat = Metrics.radiusInner
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .milled(radius: radius)
    }
}

struct Backdrop: View {
    var body: some View {
        Palette.backdrop.ignoresSafeArea()
    }
}
