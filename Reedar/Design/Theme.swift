import SwiftUI
import UIKit

/// Measurements and type.
enum Metrics {
    static let radius: CGFloat = 16
    static let radiusInner: CGFloat = 10
    static let radiusKey: CGFloat = 12
    static let radiusSlot: CGFloat = 8

    /// The case doesn't sit on the screen — it is the screen, with its walls
    /// out of frame. Its corners are the display's own corners, struck at the
    /// same radius, because there is nothing between the two to set one back
    /// from the other.
    static var radiusCase: CGFloat { Screen.cornerRadius }

    static let gutter: CGFloat = 16
    static let screenMargin: CGFloat = 16
    static let stack: CGFloat = 12

    /// A sax reed is about 2cm across and 7cm long — roughly 1 : 3.4. Anything
    /// narrower reads as a clarinet reed, or a chopstick.
    static let reedAspect: CGFloat = 3.4

    /// A reed lying down, shown on its own.
    ///
    /// Struck to match a bay in the case, which on the phones this runs on
    /// comes out around 4.4 — full width less the case margins, over an eighth
    /// of what's left after the plate. It was 4.6, a middle ground between true
    /// life and a case row, and the reed on the detail page came out visibly
    /// thinner than the same reed two taps earlier. There is one reed in this
    /// app and it should be the same object on every screen; a proportion of
    /// its own for one screen is how it stops being that.
    static let reedLyingAspect: CGFloat = 4.4
    static let hairline: CGFloat = 1
}

/// The type scale. Ordinary sentence case, real sizes — the interface should
/// be readable first and styled second.
extension Font {
    /// Screen titles.
    static func title(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold)
    }

    /// Row titles, panel headings, key legends.
    static func heading(_ size: CGFloat = 15, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }

    /// Sentences.
    static func copy(_ size: CGFloat = 14, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    /// Names that belong to makers.
    ///
    /// The one serif in the app, and it has exactly one job: the words that are
    /// printed on cane. Vandoren, D'Addario, Rigotti stamp their reeds in a
    /// serif, so the app sets a brand in a serif wherever it shows one — on the
    /// bark, on a reed's page, and on the case's own plate, because the case
    /// has a maker too.
    ///
    /// Nothing else takes it. A serif used for interface text is decoration,
    /// and one used for a single wordmark is an accident; used for every
    /// maker's name and only those, it's the app telling you which words came
    /// off the object rather than out of the app.
    static func brand(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Numbers: rounded and monospaced so they don't jitter as they count.
    static func numeric(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }

    /// The one small-caps style, used only for section rules.
    static func micro(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .semibold)
    }
}

extension View {
    /// A section label: small caps, wide, quiet.
    func microLabel(_ color: Color = Palette.inkSecondary) -> some View {
        self
            .font(.micro())
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

extension Animation {
    /// Quick and damped. Nothing in here bounces.
    static var mechanical: Animation { .spring(response: 0.28, dampingFraction: 0.85) }
    static var settle: Animation { .spring(response: 0.42, dampingFraction: 0.9) }
}

/// Two-digit slot numbers.
func indexLabel(_ n: Int) -> String {
    n < 10 ? "0\(n)" : "\(n)"
}

/// The display the app is running on.
enum Screen {
    /// The radius of the display's own rounded corners.
    ///
    /// UIKit has never exposed this. The private key is a plain read with a
    /// fallback, and the fallback is the radius of the phones this app is
    /// actually used on, so a rejected or renamed key costs a slightly-off
    /// curve rather than a broken layout.
    static let cornerRadius: CGFloat = {
        let screen = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen }
            .first
        let measured = screen?.value(forKey: "_displayCornerRadius") as? CGFloat
        return measured ?? 55
    }()
}
