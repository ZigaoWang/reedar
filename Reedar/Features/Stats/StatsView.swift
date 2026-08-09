import SwiftData
import SwiftUI

/// The payoff: how long the player's reeds actually last, by model and strength.
struct StatsView: View {
    @Query private var reeds: [Reed]
    @State private var grouping: Grouping = .model
    @State private var showingWorking = false

    enum Grouping: String, CaseIterable, Identifiable {
        case model, strength
        var id: String { rawValue }
        var title: String { self == .model ? "By model" : "By strength" }
    }

    private var retiredReeds: [Reed] { reeds.filter(\.isRetired) }

    private var activeReeds: [Reed] { reeds.filter { !$0.isRetired } }

    /// Playing time left in the case. Every reed has an estimate now, so
    /// nothing is silently dropped; what varies is how much of it is the
    /// player's own history and how much is the standard figure.
    private var remaining: (minutes: Double, guessed: Int) {
        var total: Double = 0
        var guessed = 0
        for reed in activeReeds {
            let estimate = LifespanStats.estimate(for: reed, among: reeds)
            if !estimate.isPersonal { guessed += 1 }
            total += max(0, estimate.minutes - Double(reed.playingMinutes))
        }
        return (total, guessed)
    }

    private var allSessions: [PlaySession] { reeds.flatMap { $0.sessions ?? [] } }

    private func playedMinutes(inLast days: Int) -> Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return allSessions.filter { $0.date >= cutoff }.reduce(0) { $0 + $1.playingMinutes }
    }

    /// How much the player actually plays, averaged over the last four weeks.
    /// A single week swings too much to plan against.
    private var weeklyMinutes: Double { Double(playedMinutes(inLast: 28)) / 4 }

    private var totalMinutes: Int { allSessions.reduce(0) { $0 + $1.playingMinutes } }

    /// The single reed that lasted longest, so the figure can be tapped to see
    /// which one it was.
    private var bestReed: Reed? {
        counted.max { $0.playingMinutes < $1.playingMinutes }
    }

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

    /// Summaries come back sorted longest-lived first, so the winner is simply
    /// the first one.
    private var best: LifespanSummary? { summaries.first }

    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(Tour.self) private var tour: Tour?
    private var isWide: Bool { widthClass == .regular }

    /// One column on a phone; two where there's room.
    ///
    /// Left is the counting — what's left in the case, how much you play, the
    /// totals — and right is the finding, which is the one thing on this screen
    /// anybody came for: how long each model lasts you. In one column the
    /// finding is below three panels of arithmetic and you scroll past the
    /// question to reach the answer.
    ///
    /// The empty state stays a single column whatever the screen. It is one
    /// short paragraph explaining that there's nothing yet, and a paragraph set
    /// in the left half of an iPad with a column of nothing beside it is worse
    /// than the same paragraph in the middle.
    @ViewBuilder private var layout: some View {
        if counted.isEmpty {
            VStack(spacing: Metrics.stack) {
                pending
            }
        } else if isWide {
            HStack(alignment: .top, spacing: Metrics.gutter) {
                VStack(spacing: Metrics.stack) {
                    headline
                    playing
                    allTime
                }
                VStack(spacing: Metrics.stack) {
                    grouper
                    chart
                    confidenceNote
                }
            }
        } else {
            VStack(spacing: Metrics.stack) {
                headline
                playing
                allTime
                grouper
                chart
                confidenceNote
            }
        }
    }

    private var grouper: some View {
        KeySelector(values: Grouping.allCases, selection: $grouping,
                    title: \.title, symbol: nil, columns: 2)
    }

    /// Says so when the chart is drawn from too few reeds to trust.
    @ViewBuilder private var confidenceNote: some View {
        if summaries.contains(where: { !$0.isConfident }) {
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "hourglass")
                    .font(.system(size: 10, weight: .semibold))
                Text("Faded means fewer than 3 reeds so far.")
                    .font(.copy(11.5))
            }
            .foregroundStyle(Palette.inkSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.top, 2)
        }
    }

    var body: some View {
        ScrollView {
            layout
                .padding(.horizontal, Metrics.screenMargin)
                .column(isWide && !counted.isEmpty ? Metrics.spread : Metrics.column)
                .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background { Backdrop() }
        .onAppear { tour?.completed(.lifespan) }
        .navigationTitle("Lifespan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingWorking) { working }
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

    /// What a whole-case view can tell you that a single reed's page cannot:
    /// whether you are about to run out. Two figures, set large.
    private var headline: some View {
        let left = remaining
        let weeks = weeklyMinutes > 0 ? Int((left.minutes / weeklyMinutes).rounded()) : 0
        return Panel(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                // Estimates have to be able to show their working, or they are
                // just numbers the app made up.
                HStack(spacing: 10) {
                    Text("Left in the case").microLabel()
                    Rectangle().fill(Palette.hairline).frame(height: Metrics.hairline)
                    Button { showingWorking = true } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.inkSecondary)
                    }
                    .accessibilityLabel("How this is worked out")
                }
                HStack(spacing: 0) {
                    bigFigure(Format.hours(minutes: left.minutes), unit: "h", label: "Playing left")
                    divider
                    bigFigure(weeks > 0 ? "\(weeks)" : "—", label: "Weeks left")
                }
                if left.guessed > 0 {
                    Text("\(Format.count(left.guessed, "reed")) using a typical \(Format.hours(minutes: LifespanStats.typicalMinutes))h until you retire one.")
                        .font(.copy(12))
                        .foregroundStyle(Palette.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// How much the player actually plays. It is the other half of every
    /// number on this page and it was never shown.
    private var playing: some View {
        Panel(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                RuleHeader("How much you play")
                rows {
                    statRow("This week", Format.hours(minutes: Double(playedMinutes(inLast: 7))), unit: "h")
                    statRow("This month", Format.hours(minutes: Double(playedMinutes(inLast: 30))), unit: "h")
                    statRow("Weekly average", Format.hours(minutes: weeklyMinutes), unit: "h")
                }
            }
        }
    }

    private var allTime: some View {
        Panel(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                RuleHeader("All time")
                rows {
                    statRow("Playing time", Format.hours(minutes: Double(totalMinutes)), unit: "h")
                    statRow("Sessions", "\(allSessions.count)")
                    statRow("Reeds tracked", "\(reeds.count)")
                    if let bestReed {
                        NavigationLink { ReedDetailView(reed: bestReed) } label: {
                            statRow("Longest lasting reed",
                                    Format.hours(minutes: Double(bestReed.playingMinutes)),
                                    unit: "h", chevron: true)
                        }
                        .buttonStyle(.sink)
                    }
                    statRow("Average reed life", Format.hours(minutes: overallAverage), unit: "h")
                    NavigationLink { ArchiveView() } label: {
                        statRow("Retired reeds", "\(retiredReeds.count)", chevron: true)
                    }
                    .buttonStyle(.sink)
                    .disabled(retiredReeds.isEmpty)
                }
            }
        }
    }

    /// Rows in a recess, hairline between each. Three figures across a panel
    /// wrapped their own labels onto two lines, which is what made it cramped.
    private func rows<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        Well(padding: 0) {
            VStack(spacing: 0) { content() }
        }
    }

    private func statRow(_ label: String,
                         _ value: String,
                         unit: String? = nil,
                         chevron: Bool = false) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.copy(14))
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.numeric(17))
                    .foregroundStyle(Palette.ink)
                if let unit {
                    Text(unit)
                        .font(.numeric(11, weight: .medium))
                        .foregroundStyle(Palette.inkTertiary)
                }
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.inkTertiary)
                .opacity(chevron ? 1 : 0)
                .frame(width: chevron ? nil : 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.hairline)
                .frame(height: Metrics.hairline)
                .padding(.leading, 14)
        }
    }

    private var divider: some View {
        Rectangle().fill(Palette.hairline).frame(width: 1, height: 40)
    }

    private func bigFigure(_ value: String, unit: String? = nil, label: String) -> some View {
        VStack(spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.numeric(34))
                    .foregroundStyle(Palette.accent)
                if let unit {
                    Text(unit)
                        .font(.numeric(16, weight: .medium))
                        .foregroundStyle(Palette.accent.opacity(0.55))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Text(label).microLabel(Palette.inkTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    /// The sums behind the estimates, one line each. Anyone who wants this
    /// wants it exact, and anyone who does not never opens it.
    private var working: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("How this is worked out")
                .font(.heading(17))
                .foregroundStyle(Palette.ink)
            workingRow("Playing left",
                       "Each reed's average life, minus what it has already played, added up.")
            workingRow("Weeks left",
                       "Playing left, divided by how much you play in a week.")
            workingRow("Weekly average",
                       "The last 4 weeks of playing, divided by 4.")
            workingRow("Where the life figure comes from",
                       "Your retired reeds of the same model and strength, then that model at any strength, then everything you have retired. Until then, a typical \(Format.hours(minutes: LifespanStats.typicalMinutes))h reed.")
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { Backdrop() }
        .presentationDetents([.height(400)])
    }

    private func workingRow(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).microLabel()
            Text(detail)
                .font(.copy(13))
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// One chart, longest-lasting first. Which reed gets you the most playing
    /// time is a comparison, and a comparison wants bars — the same figures in
    /// a stack of cards make you do the ranking yourself.
    private var chart: some View {
        let longest = summaries.map(\.averageMinutes).max() ?? 1
        return Panel(padding: 16) {
            VStack(alignment: .leading, spacing: 16) {
                RuleHeader("How long each lasts you")
                ForEach(summaries) { summary in
                    LifespanBar(summary: summary, longest: longest)
                }
            }
        }
    }

    private var pending: some View {
        VStack(spacing: Metrics.stack) {
            Panel(padding: 16) {
                VStack(alignment: .leading, spacing: 9) {
                    RuleHeader("Nothing to compare yet")
                    Text("Retire a reed when it's done. After a few, Reedar can tell you when your case will run out.")
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

/// One model's average, as a bar against the longest-lived model. The number
/// on its own says how long; the bar says whether that is good.
struct LifespanBar: View {
    var summary: LifespanSummary
    /// The longest average on the page, which sets the full width.
    var longest: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(summary.key.displayName)
                    .font(.heading(14))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(Format.hours(minutes: summary.averageMinutes))
                        .font(.numeric(17))
                    Text("h")
                        .font(.numeric(11, weight: .medium))
                        .foregroundStyle(Palette.accent.opacity(0.6))
                }
                .foregroundStyle(Palette.accent)
            }

            GeometryReader { geo in
                let fraction = longest > 0 ? summary.averageMinutes / longest : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.recess)
                    Capsule()
                        .fill(Palette.accent.opacity(summary.isConfident ? 1 : 0.45))
                        .frame(width: max(6, geo.size.width * fraction))
                }
            }
            .frame(height: 8)

            Text(footnote)
                .font(.copy(11.5))
                .foregroundStyle(Palette.inkTertiary)
        }
    }

    /// Everything the old card spread across four columns of figures, said in
    /// one line. Shortest and longest read as data when a model had one reed
    /// behind it and both columns showed the same number.
    private var footnote: String {
        guard summary.sampleCount > 1 else { return "1 reed" }
        return "\(summary.sampleCount) reeds · \(Format.hours(minutes: summary.shortestMinutes))h to \(Format.hours(minutes: summary.longestMinutes))h"
    }
}

#Preview {
    StatsView()
        .modelContainer(ModelContainer.preview())
}
