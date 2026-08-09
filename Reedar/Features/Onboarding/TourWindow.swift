import SwiftUI
import UIKit

/// The tour's card, in a window of its own above everything else.
///
/// It used to be an overlay on the app with a second copy embedded inside every
/// sheet the tour could send you into. That is two of the same thing, and it
/// showed. A `UIWindow` above `.alert` level is the one place in iOS genuinely
/// on top of everything — sheets, alerts, the lot — so the card is built once,
/// lives in one place, and never moves.
///
/// The whole difficulty is touches. The window covers the screen, so it has to
/// let almost every touch through to the app the tour is describing, while
/// still catching the ones that land on the card.
@MainActor
final class TourWindow {
    private var window: PassthroughWindow?
    /// Where the card is, in screen coordinates. The only region of this
    /// window that takes a touch.
    private let hitBox = HitBox()

    func show(_ tour: Tour) {
        guard window == nil else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }

        let window = PassthroughWindow(windowScene: scene)
        window.hitBox = hitBox
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear

        let host = UIHostingController(rootView: TourLayer(tour: tour, hitBox: hitBox))
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

/// Where the card is. A class so the window and the SwiftUI layer share one.
@MainActor
final class HitBox {
    var rect: CGRect = .zero
}

/// A window that takes only the touches landing on the card.
///
/// The obvious test — "did this hit the root view?" — does not work. SwiftUI
/// hosts an entire hierarchy inside a single `UIView`, so that test is true
/// everywhere, including on top of the card, and every button in the tour goes
/// dead while looking perfectly alive. Asking the geometry instead is the only
/// reliable answer.
private final class PassthroughWindow: UIWindow {
    weak var hitBox: HitBox?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hitBox, hitBox.rect.contains(point) else { return nil }
        return super.hitTest(point, with: event)
    }
}

/// What the window contains: the card, at the bottom, and nothing else.
private struct TourLayer: View {
    @Bindable var tour: Tour
    let hitBox: HitBox

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            if tour.isRunning {
                TourCard(tour: tour)
                    // Report where it is, every time it moves or resizes, so
                    // the window knows which touches are meant for it.
                    .background {
                        GeometryReader { proxy in
                            Color.clear
                                .onAppear { hitBox.rect = proxy.frame(in: .global) }
                                .onChange(of: proxy.frame(in: .global)) { _, frame in
                                    hitBox.rect = frame
                                }
                        }
                    }
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
