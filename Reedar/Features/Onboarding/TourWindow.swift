import SwiftUI
import UIKit

/// The tour's card, in a window of its own above everything else.
///
/// It used to be an overlay on the app, with a second copy embedded inside the
/// log and retire sheets. That is two of the same thing, and it showed: a sheet
/// covers an overlay, so the guidance had to be rebuilt inside every screen the
/// tour could send you into, and each one had its own idea of where the card
/// sat. Somebody new to the app would watch the tour disappear and reappear
/// somewhere else.
///
/// A `UIWindow` above `.alert` level is the one place in iOS that is genuinely
/// on top of everything — sheets, alerts, the lot — so the card is built once,
/// lives in one place, and never moves. Touches fall straight through it except
/// where the card actually is, so the app underneath stays as usable as it was
/// when the tour was an overlay.
@MainActor
final class TourWindow {
    private var window: UIWindow?

    func show(_ tour: Tour) {
        guard window == nil else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }

        let window = PassthroughWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        // Never the key window: taking key status would pull the keyboard and
        // the focus out of the app the tour is describing.
        window.isUserInteractionEnabled = true

        let host = UIHostingController(rootView: TourLayer(tour: tour))
        host.view.backgroundColor = .clear
        host.safeAreaRegions = []
        window.rootViewController = host
        window.isHidden = false

        self.window = window
    }

    func hide() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
    }
}

/// A window that only claims the touches that land on something in it.
private final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        // The hosting controller's own view is the empty space around the card.
        return hit === rootViewController?.view ? nil : hit
    }
}

/// What the window contains: the card, at the bottom, and nothing else.
private struct TourLayer: View {
    @Bindable var tour: Tour

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            if tour.isRunning {
                TourCard(tour: tour)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
        .tint(Palette.accent)
        .animation(.settle, value: tour.isRunning)
    }
}
