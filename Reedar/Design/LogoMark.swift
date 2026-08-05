import SwiftUI

/// The app mark: the icon artwork, clipped to the same rounded square iOS uses
/// on the home screen. Drawn from one place so the header, the launch veil and
/// the about block can't drift apart.
///
/// The artwork is deliberately cropped — the reeds run off the bottom edge —
/// so it's clipped rather than fitted. Fitting it would letterbox the black
/// ground against whatever is behind it, which reads as a mistake.
struct LogoMark: View {
    var size: CGFloat = 28

    /// The corner of an iOS icon is a continuous curve at a little under a
    /// quarter of its width. Matching it keeps the mark recognisable at 28pt.
    private var radius: CGFloat { size * 0.2237 }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        Image("Logo")
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(shape)
            .overlay { shape.strokeBorder(Palette.hairline, lineWidth: 1) }
            // The mark carries no information the surrounding text doesn't.
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 20) {
        LogoMark(size: 28)
        LogoMark(size: 44)
        LogoMark(size: 96)
    }
    .padding(40)
    .background(Palette.ground)
}
