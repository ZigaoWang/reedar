import SwiftUI
import UIKit

/// One case, moulded in two materials.
///
/// This file used to open by saying there was only one appearance, because a
/// reed case is black. That is still the case the app is drawn as, and still
/// what it ships set to — but "the object is black" is an argument about the
/// object, not about the room. People read this on a music stand in daylight,
/// and an app that can only be black is an app that is sometimes unreadable
/// where it is actually used.
///
/// So there are two materials, and the light is the same in both. Everything in
/// `Surfaces` derives from one fact — the light comes from above — and none of
/// that changes here. What changes is what the plastic is made of: black ABS
/// with a hard specular top edge and deep shadow, or bone-grey ABS where both
/// the shadow and the lit edge are shallow. Inverting the dark values would
/// have given a grey app with black shadows painted on it, which is what a
/// light mode looks like when nobody has held the object.
///
/// The catches were near-white to begin with, on the theory that pale plastic
/// throws a hard specular. It does — against a dark surround. Here the surface
/// the highlight lands on is already near-white, so the highlight adds no
/// brightness at all and the only part of it you can see is the blur spilling
/// past the edge: a white halo round every bay, and round every reed lying in
/// one. On a pale material the lit edge has almost nowhere to go, and saying
/// so quietly is the whole of it.
///
/// Every value resolves through `UIColor`'s own trait lookup, so there is no
/// global to keep in step and nothing to force a redraw: the appearance the
/// player picked is set once on the root as `preferredColorScheme`, and every
/// colour under it resolves itself.
enum Palette {
    // MARK: Ground

    /// Behind everything.
    static let ground = dynamic(dark: 0x0A0A0B, light: 0xEFEFF2)
    /// A surface sitting on the ground: panels, rows, sheets.
    static let surface = dynamic(dark: 0x151517, light: 0xF8F8FA)
    /// A surface on top of a surface.
    static let surfaceRaised = dynamic(dark: 0x1D1D20, light: 0xFFFFFF)
    /// Cut into a surface: slots, wells, displays.
    static let recess = dynamic(dark: 0x060607, light: 0xE8E8EC)

    // MARK: Ink

    static let ink = dynamic(dark: 0xF6F6F4, light: 0x1A1A1E)
    static let inkSecondary = dynamic(dark: 0x9E9EA4, light: 0x5B5B64)

    /// The quietest ink: versions, captions, chevrons, the second half of a
    /// row that already said the important part.
    ///
    /// It was 0x646469, which measured 2.86 : 1 against a raised panel — under
    /// half the 4.5 : 1 that normal-sized text is meant to hold, and it carries
    /// real sentences ("Faded means fewer than 3 reeds so far"). Quiet is a
    /// judgement about hierarchy; unreadable is a judgement about eyesight, and
    /// this had crossed from one into the other.
    ///
    /// Both values clear 4.5 : 1 on every surface in the app with a little in
    /// hand, and are still plainly the third voice on the screen.
    static let inkTertiary = dynamic(dark: 0x8A8A90, light: 0x6D6D77)

    // MARK: Accent

    /// The light accent is not the dark one. 0xFF6A1A on white measures
    /// 2.6 : 1, and this colour carries sentences — "About 8h 45m left",
    /// the playing figure on the log sheet, every value that matters. Burnt
    /// down to 0xC24705 it clears 5 : 1 on a white panel and still reads as
    /// the same orange family on a key.
    static let accent = dynamic(dark: 0xFF6A1A, light: 0xC24705)
    static let accentDeep = dynamic(dark: 0xE0530A, light: 0xA53B03)
    /// The legend on an accent-filled key: near-black on the bright orange,
    /// near-white on the burnt one.
    static let onAccent = dynamic(dark: 0x1A0C02, light: 0xFFF4EC)

    // MARK: Signals

    static let signalGreen = dynamic(dark: 0x4ECB71, light: 0x1E7F3E)
    static let signalAmber = dynamic(dark: 0xF2B23C, light: 0x8A5D0B)
    static let signalRed = dynamic(dark: 0xF05A4E, light: 0xC0342A)

    // MARK: Faces

    /// A raised surface seen straight on. Moulded plastic never returns one
    /// flat value: the top of a face is nearer the light than the bottom.
    static var surfaceFace: LinearGradient {
        gradient(dark: (0x1B1B1E, 0x121214), light: (0xFFFFFF, 0xF6F6F9))
    }

    /// The floor of a recess, which darkens toward the top where the near wall
    /// keeps the light off it.
    static var recessFace: LinearGradient {
        gradient(dark: (0x030304, 0x0A0A0C), light: (0xE4E4EA, 0xEDEDF1))
    }

    /// A key standing proud of the case floor. Cut from lighter stock than
    /// `trayFace`, or it reads as a recess however it's lit — but only just.
    /// With the shell gone it is the one piece of hardware on an otherwise bare
    /// floor, and struck any brighter it takes the eye off the reeds, which are
    /// the only thing on this screen anybody opened it to look at.
    static var keyFace: LinearGradient {
        gradient(dark: (0x2A2A30, 0x1F1F25), light: (0xFFFFFF, 0xF1F1F5))
    }

    /// The floor of the case, which the slots are cut into. There is no shell
    /// above it any more — a wall drawn round the display has the bezel on the
    /// other side of it, and reads as a stripe rather than as material.
    static var trayFace: LinearGradient {
        gradient(dark: (0x101013, 0x17171B), light: (0xECECF0, 0xF4F4F7))
    }

    // MARK: Edges

    /// The one line that separates a surface from what's behind it.
    static let hairline = dynamic(dark: 0xFFFFFF, light: 0x000000,
                                  darkAlpha: 0.07, lightAlpha: 0.06)
    /// Black plastic on a black ground throws a shadow you can lose a panel in;
    /// bone plastic on a bone ground throws one you can barely see, and forcing
    /// the dark value into the light material is what makes a light theme look
    /// like a dark one with the paint scraped off.
    static let dropShadow = dynamic(dark: 0x000000, light: 0x000000,
                                    darkAlpha: 0.55, lightAlpha: 0.10)

    // MARK: Light on an edge
    //
    // The geometry of every bevel, recess wall and catch lives in `Surfaces`
    // and is identical in both materials — the light is above in both. Only
    // how hard the material takes that light lives here. Black ABS swallows
    // the highlight and holds a deep shadow; bone ABS throws a near-white
    // specular along its top edge and almost no shadow at all.

    /// The lit top edge of a raised face.
    static let bevelHighlight = dynamic(dark: 0xFFFFFF, light: 0xFFFFFF,
                                        darkAlpha: 0.09, lightAlpha: 0.45)
    /// Its shaded bottom edge.
    static let bevelShade = dynamic(dark: 0x000000, light: 0x000000,
                                    darkAlpha: 0.35, lightAlpha: 0.10)

    /// A key on the case plate, which is cut from lighter stock than the floor
    /// and so takes the light a little harder than an ordinary panel.
    static let keyHighlight = dynamic(dark: 0xFFFFFF, light: 0xFFFFFF,
                                      darkAlpha: 0.14, lightAlpha: 0.55)
    static let keyShade = dynamic(dark: 0x000000, light: 0x000000,
                                  darkAlpha: 0.30, lightAlpha: 0.09)

    /// The near wall of a recess, which is what the surface below is looking up
    /// into.
    static let recessShade = dynamic(dark: 0x000000, light: 0x000000,
                                     darkAlpha: 0.80, lightAlpha: 0.13)
    /// The far wall, turning back toward the light.
    static let recessCatch = dynamic(dark: 0xFFFFFF, light: 0xFFFFFF,
                                     darkAlpha: 0.055, lightAlpha: 0.28)

    /// The same two, struck harder, for the bays in the case floor. They are
    /// the only depth left on that screen and most of a typical case is empty,
    /// so most of what anybody looks at is these two edges.
    static let bayShade = dynamic(dark: 0x000000, light: 0x000000,
                                  darkAlpha: 0.95, lightAlpha: 0.14)
    static let bayCatch = dynamic(dark: 0xFFFFFF, light: 0xFFFFFF,
                                  darkAlpha: 0.14, lightAlpha: 0.30)

    /// The floor of a bay, which is not the floor of a well.
    ///
    /// A bay is deeper than the recesses cut into panels, and it has an object
    /// lying in it with a few points of clearance all round. Lit to the same
    /// value as the tray, that clearance stopped reading as a gap and started
    /// reading as a grey band painted around the reed. Struck darker, it is
    /// what it actually is: the bottom of a slot, in shadow.
    static var bayFloor: LinearGradient {
        gradient(dark: (0x030304, 0x0A0A0C), light: (0xDEDEE4, 0xE7E7ED))
    }

    /// Where the reed touches the floor of its bay. Tighter and darker than the
    /// ambient shadow a panel throws, because the two surfaces are touching —
    /// this is the line that says the reed is lying in the case rather than
    /// printed on it.
    static let slotContact = dynamic(dark: 0x000000, light: 0x000000,
                                     darkAlpha: 0.75, lightAlpha: 0.22)

    /// An unlit lamp: a dark well in a dark case, a grey one in a pale case.
    static let ledOff = dynamic(dark: 0xFFFFFF, light: 0x000000,
                                darkAlpha: 0.08, lightAlpha: 0.12)

    /// A number stamped into the floor of an empty bay. In black plastic the
    /// figure is the pale face of the stamp with a dark line cut above it; in
    /// pale plastic it is the other way round — the figure is the shadow, and
    /// the catch of light sits below it.
    static let engravingInk = dynamic(dark: 0xFFFFFF, light: 0x000000,
                                      darkAlpha: 0.17, lightAlpha: 0.17)
    static let engravingRelief = dynamic(dark: 0x000000, light: 0xFFFFFF,
                                         darkAlpha: 0.9, lightAlpha: 0.95)

    // MARK: Fills

    static var backdrop: LinearGradient {
        gradient(dark: (0x121214, 0x0A0A0B), light: (0xF6F6F8, 0xEFEFF2))
    }

    // MARK: Resolution

    /// One value that knows both materials. `UIColor`'s trait-aware
    /// initialiser does the choosing at draw time, which is why nothing in this
    /// app has to be told the appearance changed.
    private static func dynamic(dark: UInt32, light: UInt32,
                                darkAlpha: Double = 1, lightAlpha: Double = 1) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .light
                ? UIColor(hex: light, alpha: lightAlpha)
                : UIColor(hex: dark, alpha: darkAlpha)
        })
    }

    private static func gradient(dark: (UInt32, UInt32),
                                 light: (UInt32, UInt32)) -> LinearGradient {
        LinearGradient(colors: [dynamic(dark: dark.0, light: light.0),
                                dynamic(dark: dark.1, light: light.1)],
                       startPoint: .top, endPoint: .bottom)
    }
}

/// What the player picked. Kept next to the palette because it is the only
/// thing that decides which half of it is drawn.
enum Appearance: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    static let key = "appearance"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var symbolName: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    /// Nil hands the decision back to the system, which is what `.system` is.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
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

extension UIColor {
    convenience init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
