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

    // MARK: Faces

    /// A raised surface seen straight on. Moulded plastic never returns one
    /// flat value: the top of a face is nearer the light than the bottom.
    static var surfaceFace: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x1B1B1E), Color(hex: 0x121214)],
                       startPoint: .top, endPoint: .bottom)
    }

    /// The floor of a recess, which darkens toward the top where the near wall
    /// keeps the light off it.
    static var recessFace: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x030304), Color(hex: 0x0A0A0C)],
                       startPoint: .top, endPoint: .bottom)
    }

    /// A key standing proud of the case floor. Cut from lighter stock than
    /// `trayFace`, or it reads as a recess however it's lit — but only just.
    /// With the shell gone it is the one piece of hardware on an otherwise bare
    /// floor, and struck any brighter it takes the eye off the reeds, which are
    /// the only thing on this screen anybody opened it to look at.
    static var keyFace: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x2A2A30), Color(hex: 0x1F1F25)],
                       startPoint: .top, endPoint: .bottom)
    }

    /// The floor of the case, which the slots are cut into. There is no shell
    /// above it any more — a wall drawn round the display has the bezel on the
    /// other side of it, and reads as a stripe rather than as material.
    static var trayFace: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x101013), Color(hex: 0x17171B)],
                       startPoint: .top, endPoint: .bottom)
    }

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
