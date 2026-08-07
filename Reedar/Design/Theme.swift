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

    /// A reed lying down, shown on its own. Longer than life, because that is
    /// how a reed reads in a slot the width of the screen, but not as drawn
    /// out as an actual case row. At true proportions it looks like a fatter,
    /// different object next to the case; at full slot proportions it is a
    /// strip. Anywhere a reed lies down outside the case uses this, so it is
    /// the same reed from screen to screen.
    static let reedLyingAspect: CGFloat = 4.6
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
