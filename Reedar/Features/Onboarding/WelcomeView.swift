import SwiftUI

/// One screen, before anything else, saying what the app is for.
///
/// It is the only part of onboarding that is a screen rather than the app
/// itself, and it earns that by doing the one job the app can't do for itself:
/// somebody who has just paid for this deserves the promise restated in a
/// sentence before being asked to do anything. Everything after it happens in
/// the real case, on real reeds — see `Tour`.
struct WelcomeView: View {
    var begin: () -> Void
    var skip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 18) {
                LogoMark(size: 92)
                    .shadow(color: .black.opacity(0.5), radius: 18, y: 9)
                Wordmark(size: 30)
            }

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                Text("Know how long your reeds really last")
                    .font(.title(26))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                Text("Log what you play, retire a reed when it's done, and Reedar "
                     + "works out what your reeds actually last you — by brand, "
                     + "model and strength.")
                    .font(.copy(15))
                    .foregroundStyle(Palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 6)

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                PrimaryKey(title: "Add my first reed", symbol: "plus") { begin() }
                Button("Have a look round first") { skip() }
                    .font(.copy(14))
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
        .padding(.horizontal, Metrics.screenMargin)
        .padding(.vertical, 40)
        .column()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { Backdrop() }
    }
}

#Preview {
    WelcomeView(begin: {}, skip: {})
        .preferredColorScheme(.dark)
        .tint(Palette.accent)
}
