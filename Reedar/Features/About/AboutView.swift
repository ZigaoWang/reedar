import SwiftUI

/// What this is, who made it, and where to say something about it.
///
/// The last screen in the app and the only one that leaves it. Everything below
/// the masthead is a link out, so each row names its destination rather than
/// leaving the arrow to imply one.
struct AboutView: View {
    private static let site = URL(string: "https://www.zigao.wang")!
    private static let repository = URL(string: "https://github.com/ZigaoWang/reedar")!
    private static let issues = URL(string: "https://github.com/ZigaoWang/reedar/issues/new")!

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 22) {
                    masthead
                    credit
                    project
                    Spacer(minLength: 12)
                    footer
                }
                .padding(.horizontal, Metrics.screenMargin)
                .padding(.top, 8)
                .padding(.bottom, 20)
                // There is not much on this screen. Filling the height rather
                // than stacking everything against the navigation bar is what
                // keeps it from reading as a page that failed to load.
                .frame(minHeight: geo.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
        }
        .background { Backdrop() }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: Masthead

    private var masthead: some View {
        VStack(spacing: 13) {
            LogoMark(size: 80)
                .shadow(color: .black.opacity(0.5), radius: 14, y: 7)

            VStack(spacing: 5) {
                Text("Reedar")
                    .font(.title(23))
                    .foregroundStyle(Palette.ink)

                Text(Self.versionLabel)
                    .font(.numeric(12, weight: .medium))
                    .foregroundStyle(Palette.inkTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
        .padding(.bottom, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reedar, \(Self.versionLabel)")
    }

    // MARK: Sections

    /// A face, because an app that quietly logs your practice should say who
    /// it came from. A photograph does that in a way a person glyph can't.
    ///
    /// The attribution is the section label rather than a line in the row, so
    /// the row itself is just the person.
    private var credit: some View {
        Section("Made by") {
            Link(destination: Self.site) {
                HStack(spacing: 13) {
                    Image("Portrait")
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                        .overlay { Circle().strokeBorder(Palette.hairline, lineWidth: 1) }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Zigao Wang")
                            .font(.heading(16))
                            .foregroundStyle(Palette.ink)
                        Text("zigao.wang")
                            .font(.copy(12.5))
                            .foregroundStyle(Palette.inkTertiary)
                    }

                    Spacer(minLength: 8)
                    OutwardArrow()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.sink)
            .accessibilityLabel("Made by Zigao Wang. zigao.wang")
            .accessibilityAddTraits(.isLink)
        }
    }

    private var project: some View {
        Section("Project") {
            VStack(spacing: 0) {
                LinkRow(
                    symbol: "chevron.left.forwardslash.chevron.right",
                    title: "Source code",
                    detail: "github.com/ZigaoWang/reedar",
                    url: Self.repository
                )
                Divider()
                    .overlay(Palette.hairline)
                    .padding(.leading, 47)
                LinkRow(
                    symbol: "exclamationmark.bubble",
                    title: "Report an issue or suggestion",
                    detail: "Opens a new issue on GitHub",
                    url: Self.issues
                )
            }
        }
    }

    private var footer: some View {
        Text("© \(Self.year) Zigao Wang")
            .font(.copy(11.5))
            .foregroundStyle(Palette.inkTertiary)
            .frame(maxWidth: .infinity)
    }

    // MARK: Bundle

    static var versionLabel: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    /// Just the marketing version, for rows too narrow to carry the build.
    static var shortVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private static var year: String {
        String(Calendar.current.component(.year, from: Date()))
    }
}

// MARK: - Parts

/// A labelled group of rows. The label sits outside the panel, in the app's
/// one small-caps style.
private struct Section<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .microLabel()
                .padding(.leading, 4)
            Panel(padding: 0) { content }
        }
    }
}

/// The mark on every row that leaves the app. The system's outward arrow, so
/// it doesn't read as another screen in the stack.
private struct OutwardArrow: View {
    var body: some View {
        Image(systemName: "arrow.up.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Palette.inkTertiary)
    }
}

private struct LinkRow: View {
    var symbol: String
    var title: String
    var detail: String
    var url: URL

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 11) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.inkSecondary)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.heading(15))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(detail)
                        .font(.copy(12))
                        .foregroundStyle(Palette.inkTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 8)
                OutwardArrow()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.sink)
        .accessibilityLabel("\(title). \(detail)")
        .accessibilityAddTraits(.isLink)
    }
}

#Preview {
    NavigationStack { AboutView() }
        .preferredColorScheme(.dark)
        .tint(Palette.accent)
}
