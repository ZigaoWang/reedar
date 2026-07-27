import SwiftUI

/// A number, set large in a recess. The unit and caption stay small so the
/// figure carries the row.
struct Display: View {
    var value: String
    var unit: String?
    var label: String?
    var size: CGFloat = 28
    var tint: Color = Palette.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.numeric(size))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                if let unit {
                    Text(unit)
                        .font(.numeric(size * 0.5, weight: .medium))
                        .foregroundStyle(tint.opacity(0.55))
                }
            }
            if let label {
                Text(label)
                    .font(.copy(12))
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .milled(radius: Metrics.radiusInner)
    }
}

/// A segmented bar. Discrete steps, because a reed's life is measured in
/// sessions, not in a continuous trickle.
struct LEDBar: View {
    /// 0…1+, where 1 is the average lifespan for that model.
    var progress: Double
    var segments: Int = 12
    var height: CGFloat = 6
    var spacing: CGFloat = 3

    private var litCount: Int {
        Int((min(max(progress, 0), 1) * Double(segments)).rounded(.up))
    }

    private func tint(for index: Int) -> Color {
        switch Double(index + 1) / Double(segments) {
        case ..<0.6: Palette.signalGreen
        case ..<0.85: Palette.signalAmber
        default: Palette.signalRed
        }
    }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<segments, id: \.self) { index in
                let isLit = index < litCount
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(isLit ? tint(for: index) : Color.white.opacity(0.07))
                    .shadow(color: isLit ? tint(for: index).opacity(0.5) : .clear, radius: 3)
            }
        }
        .frame(height: height)
        .animation(.mechanical, value: litCount)
    }
}

/// A single indicator lamp.
struct LED: View {
    var isOn: Bool
    var tint: Color = Palette.accent
    var size: CGFloat = 7

    var body: some View {
        Circle()
            .fill(isOn ? tint : Color.white.opacity(0.10))
            .frame(width: size, height: size)
            .shadow(color: isOn ? tint.opacity(0.7) : .clear, radius: 4)
            .animation(.mechanical, value: isOn)
    }
}

/// A small outlined marker.
struct Tag: View {
    var text: String
    var symbol: String?
    var tint: Color = Palette.inkSecondary

    var body: some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 9, weight: .semibold))
            }
            Text(text).font(.copy(12, weight: .medium))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule().fill(tint.opacity(0.12))
        }
    }
}

/// A section rule: small caps label, hairline, optional value.
struct RuleHeader: View {
    var title: String
    var trailing: String?

    init(_ title: String, trailing: String? = nil) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(title).microLabel()
            Rectangle().fill(Palette.hairline).frame(height: Metrics.hairline)
            if let trailing {
                Text(trailing)
                    .font(.numeric(12, weight: .medium))
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
    }
}
