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
                    .fill(Palette.surface)
                    .overlay { shape.strokeBorder(Palette.hairline, lineWidth: 1) }
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
                    .fill(Palette.recess)
                    .overlay { shape.strokeBorder(Palette.hairline, lineWidth: 1) }
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
