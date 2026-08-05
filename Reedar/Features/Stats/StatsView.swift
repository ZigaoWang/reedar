import SwiftData
import SwiftUI

/// The payoff: how long the player's reeds actually last, by model and strength.
struct StatsView: View {
    @Query private var reeds: [Reed]
    @State private var grouping: Grouping = .model
    @State private var showingAbout = false

    enum Grouping: String, CaseIterable, Identifiable {
        case model, strength
        var id: String { rawValue }
        var title: String { self == .model ? "By model" : "By strength" }
    }

    private var retiredReeds: [Reed] { reeds.filter(\.isRetired) }

    private var counted: [Reed] {
        retiredReeds.filter { $0.retireReason?.countsTowardLifespan ?? true }
    }

    private var summaries: [LifespanSummary] {
        switch grouping {
        case .model: LifespanStats.byModel(reeds)
        case .strength: LifespanStats.byStrength(reeds)
        }
    }

    private var overallAverage: Double {
        guard !counted.isEmpty else { return 0 }
        return Double(counted.reduce(0) { $0 + $1.playingMinutes }) / Double(counted.count)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Metrics.stack) {
                    if counted.isEmpty {
                        pending
                    } else {
                        headline
                        KeySelector(values: Grouping.allCases, selection: $grouping,
                                    title: \.title, symbol: nil, columns: 2)
                        ForEach(summaries) { LifespanCard(summary: $0) }
                        if summaries.contains(where: { !$0.isConfident }) {
                            HStack(alignment: .top, spacing: 7) {
                                Image(systemName: "hourglass")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("Averages from fewer than three reeds are marked early. They settle as you retire more.")
                                    .font(.copy(11.5))
                            }
                            .foregroundStyle(Palette.inkSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                            .padding(.top, 2)
                        }
                    }
                    archiveLink
                    colophon
                }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background { Backdrop() }
        .navigationTitle("Lifespan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showingAbout) { AboutView() }
        .task {
            if ProcessInfo.processInfo.arguments.contains("-openAbout") {
                showingAbout = true
            }
        }
    }

    /// The way into About. An earlier pass styled this as a centred signature,
    /// which nobody read as a control — it has to look like the row above it
    /// to be found at all.
    private var colophon: some View {
        NavigationLink {
            AboutView()
        } label: {
            HStack(spacing: 11) {
                LogoMark(size: 22)
                Text("About Reedar")
                    .font(.heading(15))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text(AboutView.shortVersion)
                    .font(.numeric(14))
                    .foregroundStyle(Palette.inkSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.inkTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .raised(depth: .low)
        }
        .buttonStyle(.sink)
        .padding(.top, 2)
    }

    /// Retired reeds live one level down from the numbers they produced.
    private var archiveLink: some View {
        NavigationLink {
            ArchiveView()
        } label: {
            HStack(spacing: 11) {
                Image(systemName: "tray.full")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.inkSecondary)
                Text("Retired reeds")
                    .font(.heading(15))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("\(retiredReeds.count)")
                    .font(.numeric(14))
                    .foregroundStyle(Palette.inkSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.inkTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .raised(depth: .low)
        }
        .buttonStyle(.sink)
        .opacity(retiredReeds.isEmpty ? 0 : 1)
        .disabled(retiredReeds.isEmpty)
        .padding(.top, 2)
    }

    private var headline: some View {
        Panel(padding: 14) {
            VStack(alignment: .leading, spacing: 11) {
                RuleHeader("Everything retired")
                HStack(spacing: 8) {
                    Display(value: Format.hours(minutes: overallAverage), unit: "h",
                            label: "Average life", size: 30, tint: Palette.accent)
                    Display(value: "\(counted.count)", label: "Measured", size: 30)
                }
            }
        }
    }

    private var pending: some View {
        VStack(spacing: Metrics.stack) {
            Panel(padding: 16) {
                VStack(alignment: .leading, spacing: 9) {
                    RuleHeader("No data yet")
                    Text("Retire a reed once it's done and its playing hours land here. After three or four you'll know how long your setup actually lasts.")
                        .font(.copy(12.5))
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            let active = reeds.filter { !$0.isRetired }.sorted { $0.playingMinutes > $1.playingMinutes }
            if !active.isEmpty {
                Panel(padding: 14) {
                    VStack(alignment: .leading, spacing: 11) {
                        RuleHeader("In progress")
                        Well(padding: 0) {
                            VStack(spacing: 0) {
                                ForEach(Array(active.enumerated()), id: \.element.id) { index, reed in
                                    HStack {
                                        Text(reed.fullName)
                                            .font(.heading(12, weight: .medium))
                                            .foregroundStyle(Palette.ink)
                                        Spacer()
                                        Text(Format.duration(minutes: reed.playingMinutes))
                                            .font(.numeric(12, weight: .semibold))
                                            .foregroundStyle(Palette.inkSecondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)

                                    if index < active.count - 1 {
                                        Rectangle().fill(Palette.hairline)
                                            .frame(height: Metrics.hairline).padding(.leading, 12)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct LifespanCard: View {
    var summary: LifespanSummary

    var body: some View {
        Panel(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text((summary.key.strengthLabel.isEmpty
                              ? summary.key.modelDisplayName
                              : summary.key.fullDisplayName))
                            .font(.heading(13.5, weight: .bold))
                            .foregroundStyle(Palette.ink)
                        Text("from \(Format.count(summary.sampleCount, "retired reed"))")
                            .font(.copy(11))
                            .foregroundStyle(Palette.inkTertiary)
                    }
                    Spacer(minLength: 8)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(Format.hours(minutes: summary.averageMinutes))
                            .font(.numeric(26, weight: .semibold))
                            .foregroundStyle(Palette.accent)
                        Text("h")
                            .font(.numeric(13, weight: .medium))
                            .foregroundStyle(Palette.accent.opacity(0.6))
                    }
                }

                Rectangle().fill(Palette.hairline).frame(height: Metrics.hairline)

                HStack(spacing: 0) {
                    stat(Format.hours(minutes: summary.shortestMinutes) + "h", "Shortest")
                    stat(Format.hours(minutes: summary.longestMinutes) + "h", "Longest")
                    stat(String(format: "%.0f", summary.averageSessions), "Sessions")
                    stat(String(format: "%.0f", summary.averageDays) + "d", "In rotation")
                }

                HStack(spacing: 6) {
                    if let reason = summary.commonReason {
                        Tag(text: reason.displayName, symbol: reason.symbolName)
                    }
                    if !summary.isConfident {
                        Tag(text: "Early", symbol: "hourglass", tint: Palette.signalAmber)
                    }
                    if summary.excludedCount > 0 {
                        Tag(text: "\(summary.excludedCount) excluded", symbol: "minus.circle")
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.numeric(14, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Text(label).microLabel(Palette.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    StatsView()
        .modelContainer(ModelContainer.preview())
}
