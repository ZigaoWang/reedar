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

/// The app's name, set the way a reed maker's is.
///
/// The bark on every reed in this app carries its brand in a bold serif —
/// Vandoren, D'Addario, Rigotti — because that is how cane is stamped.
/// Setting Reedar the same way puts it in the same company: the case has a
/// maker too, and its name belongs on it in the same hand.
///
/// It was the interface font at semibold, which is not a wordmark, it's a
/// title label. Nothing was wrong with it except that it looked like every
/// other piece of type on the screen, which for the one word that isn't
/// interface is the whole problem.
///
/// Drawn from one place so the launch screen, the case and the about page
/// can't drift apart — same reason `LogoMark` exists.
struct Wordmark: View {
    var size: CGFloat = 24

    var body: some View {
        Text("Reedar")
            .font(.brand(size))
            // A whisper of tracking. A serif set tight at display sizes closes
            // up around the double e.
            .tracking(size * 0.012)
            .foregroundStyle(Palette.ink)
    }
}

#Preview {
    VStack(spacing: 20) {
        LogoMark(size: 28)
        LogoMark(size: 44)
        LogoMark(size: 96)
        Wordmark(size: 24)
    }
    .padding(40)
    .background(Palette.ground)
}
