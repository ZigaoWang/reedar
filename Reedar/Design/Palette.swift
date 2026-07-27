import SwiftUI

/// One palette, black. The app doesn't follow the system appearance — a reed
/// case is black, and this reads the same on a dark stage as it does at home.
///
/// Values are flat constants rather than dynamic colours: there is only one
/// mode, so there is nothing to resolve.
enum Palette {
    // MARK: Ground

    /// Behind everything.
    static let ground = Color(hex: 0x0A0A0B)
    /// A surface sitting on the ground: panels, rows, sheets.
    static let surface = Color(hex: 0x151517)
    /// A surface on top of a surface.
    static let surfaceRaised = Color(hex: 0x1D1D20)
    /// Cut into a surface: slots, wells, displays.
    static let recess = Color(hex: 0x060607)

    // MARK: Ink

    static let ink = Color(hex: 0xF6F6F4)
    static let inkSecondary = Color(hex: 0x9E9EA4)
    static let inkTertiary = Color(hex: 0x646469)

    // MARK: Accent

    static let accent = Color(hex: 0xFF6A1A)
    static let accentDeep = Color(hex: 0xE0530A)
    static let onAccent = Color(hex: 0x1A0C02)

    // MARK: Signals

    static let signalGreen = Color(hex: 0x4ECB71)
    static let signalAmber = Color(hex: 0xF2B23C)
    static let signalRed = Color(hex: 0xF05A4E)

    // MARK: Edges

    /// The one line that separates a surface from what's behind it.
    static let hairline = Color.white.opacity(0.07)
    static let dropShadow = Color.black.opacity(0.55)

    // MARK: Fills

    static var backdrop: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x121214), ground],
                       startPoint: .top, endPoint: .bottom)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
