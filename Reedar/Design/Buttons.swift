import SwiftUI

/// A key that travels. The face sits on a darker side wall; pressing pushes it
/// down onto that wall and kills its shadow.
struct KeyButtonStyle: ButtonStyle {
    var tint: Color?
    var radius: CGFloat = Metrics.radiusKey
    /// Kept for call-site compatibility; presses no longer move anything.
    var travel: CGFloat = 0

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        return configuration.label
            .background {
                shape
                    .fill(tint == nil ? AnyShapeStyle(Palette.surfaceRaised)
                                      : AnyShapeStyle(tint!))
                    .overlay {
                        shape.strokeBorder(tint == nil ? Palette.hairline : .clear, lineWidth: 1)
                    }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.mechanical, value: configuration.isPressed)
    }
}

/// For rows and panels: they sink rather than travel.
struct SinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(configuration.isPressed ? 0.05 : 0)
            .animation(.mechanical, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == SinkButtonStyle {
    static var sink: SinkButtonStyle { SinkButtonStyle() }
}

extension ButtonStyle where Self == KeyButtonStyle {
    static var key: KeyButtonStyle { KeyButtonStyle() }
    static func key(tint: Color?) -> KeyButtonStyle { KeyButtonStyle(tint: tint) }
}

/// The primary action.
struct PrimaryKey: View {
    var title: String
    var symbol: String?
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol {
                    Image(systemName: symbol).font(.system(size: 14, weight: .bold))
                }
                Text(title)
                    .font(.heading(16))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(enabled ? Palette.onAccent : Palette.inkTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        // Disabled goes neutral rather than a faded orange, which just reads
        // as a muddy button.
        .buttonStyle(KeyButtonStyle(tint: enabled ? Palette.accent : nil,
                                    radius: Metrics.radiusKey))
        .disabled(!enabled)
    }
}

/// A square icon key.
struct IconKey: View {
    var symbol: String
    var tint: Color?
    var size: CGFloat = 52
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint == nil ? Palette.ink : Palette.onAccent)
                .frame(width: size, height: size)
        }
        .buttonStyle(KeyButtonStyle(tint: tint, radius: Metrics.radiusKey, travel: 2.5))
        .accessibilityLabel(label)
    }
}

/// A key with a word on it, used wherever the app asks a question. Selected
/// keys stay down and light up.
struct ChoiceKey: View {
    var title: String
    var symbol: String?
    var isSelected: Bool
    var height: CGFloat = 52
    /// Answers to a question fill with the accent; mode switches only light
    /// their legend, so the accent always means "press this".
    var filled: Bool = true
    var action: () -> Void

    private var legendColor: Color {
        if isSelected { return filled ? Palette.onAccent : Palette.accent }
        return Palette.ink
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol).font(.system(size: 15, weight: .medium))
                }
                Text(title)
                    .font(.heading(14))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(legendColor)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .padding(.horizontal, 6)
        }
        .buttonStyle(ChoiceKeyStyle(isSelected: isSelected, filled: filled))
    }
}

private struct ChoiceKeyStyle: ButtonStyle {
    var isSelected: Bool
    var filled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.radiusKey, style: .continuous)
        let isFilled = isSelected && filled

        return configuration.label
            .background {
                shape
                    .fill(isFilled ? AnyShapeStyle(Palette.accent)
                                   : AnyShapeStyle(Palette.surfaceRaised))
                    .overlay {
                        shape.strokeBorder(
                            isFilled ? .clear : (isSelected ? Palette.accent.opacity(0.6) : Palette.hairline),
                            lineWidth: 1
                        )
                    }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.mechanical, value: configuration.isPressed)
    }
}

/// A grid of choice keys where exactly one is selected.
struct KeySelector<Value: Hashable>: View {
    var values: [Value]
    @Binding var selection: Value
    var title: (Value) -> String
    var symbol: ((Value) -> String)? = nil
    var columns: Int = 3
    var height: CGFloat = 48

    private var rows: [[Value]] {
        stride(from: 0, to: values.count, by: columns).map {
            Array(values[$0..<min($0 + columns, values.count)])
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { value in
                        ChoiceKey(title: title(value),
                                  symbol: symbol?(value),
                                  isSelected: selection == value,
                                  height: height) {
                            selection = value
                            Haptics.tick()
                        }
                    }
                    if row.count < columns {
                        ForEach(0..<(columns - row.count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }
}

/// A toolbar button that doesn't come with a system capsule around it.
struct BareToolbarButton: View {
    var symbol: String
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Palette.surfaceRaised))
                .overlay(Circle().strokeBorder(Palette.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}


/// A full-width choice: a title, an optional line of detail, and a tick when
/// it's the one selected. Used wherever a list of options needs more than a
/// word to tell them apart.
struct ChoiceRow: View {
    var title: String
    var detail: String?
    var tag: String?
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.heading(15))
                            .foregroundStyle(isSelected ? Palette.onAccent : Palette.ink)
                        if let tag {
                            Text(tag)
                                .font(.copy(11, weight: .medium))
                                .foregroundStyle(isSelected ? Palette.onAccent.opacity(0.75)
                                                            : Palette.inkSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(
                                    isSelected ? Palette.onAccent.opacity(0.16)
                                               : Palette.ink.opacity(0.08)))
                        }
                    }
                    if let detail {
                        Text(detail)
                            .font(.copy(12))
                            .foregroundStyle(isSelected ? Palette.onAccent.opacity(0.8)
                                                        : Palette.inkSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Palette.onAccent)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(ChoiceRowStyle(isSelected: isSelected))
    }
}

private struct ChoiceRowStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.radiusKey, style: .continuous)
        return configuration.label
            .background {
                shape
                    .fill(isSelected ? AnyShapeStyle(Palette.accent)
                                     : AnyShapeStyle(Palette.surfaceRaised))
                    .overlay {
                        shape.strokeBorder(isSelected ? .clear : Palette.hairline, lineWidth: 1)
                    }
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.mechanical, value: configuration.isPressed)
    }
}
