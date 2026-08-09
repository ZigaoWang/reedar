import SwiftData
import SwiftUI

/// Adding a reed is one question per page: saxophone, brand, model, strength.
/// Picking an answer moves you on, so the whole thing is four taps. Nothing
/// scrolls off, nothing animates for the sake of it.
struct AddReedView: View {
    /// The slot the player tapped. The new reed goes there.
    var slot: Int = 0

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private enum Page {
        case instrument, brand, model, strength, custom
    }

    @State private var page: Page = .instrument
    @State private var instrument: Instrument = .altoSax
    @State private var brand: ReedBrand?
    @State private var model: ReedModel?
    @State private var strength: Strength?
    @State private var nickname = ""

    @State private var isCustom = false
    @State private var customBrand = ""
    @State private var customModel = ""
    @State private var customScale: StrengthScale = .halfStep

    private var brands: [ReedBrand] { ReedCatalog.brands(for: instrument) }
    private var models: [ReedModel] { brand?.models(for: instrument) ?? [] }
    private var scale: StrengthScale { isCustom ? customScale : (model?.scale ?? .halfStep) }

    private var canSave: Bool {
        guard strength != nil else { return false }
        return isCustom
            ? !customBrand.trimmed.isEmpty && !customModel.trimmed.isEmpty
            : model != nil
    }

    @Environment(Tour.self) private var tour: Tour?

    /// What the tour's card says while each question is up.
    private var guidance: String {
        switch page {
        case .instrument: "Which saxophone this reed is for. Strengths are "
            + "numbered differently by instrument, so Reedar asks first."
        case .brand: "Who made it. Pick \"Something else\" at the bottom for a "
            + "reed the list has never heard of."
        case .model: "Which of theirs. The strengths on the next screen come "
            + "from this model's own scale."
        case .strength: "How hard it blows, in that maker's own numbering. A "
            + "nickname is optional — it's what the reed is called in your case."
        case .custom: "Type it in as it's printed on the box."
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                question
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { Backdrop() }
            .safeAreaInset(edge: .bottom) { footer }
            .onAppear { tour?.detail = guidance }
            .onChange(of: page) { _, _ in tour?.detail = guidance }
            .onDisappear { tour?.detail = nil }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if page == .instrument {
                        Button("Cancel") { dismiss() }
                            .font(.copy(15))
                            .foregroundStyle(Palette.inkSecondary)
                    } else {
                        Button {
                            back()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                                .font(.copy(15))
                                .foregroundStyle(Palette.inkSecondary)
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(stepLabel)
                        .font(.copy(13))
                        .foregroundStyle(Palette.inkTertiary)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: Chrome

    private var stepLabel: String {
        switch page {
        case .instrument: "Step 1 of 4"
        case .brand: "Step 2 of 4"
        case .model: "Step 3 of 4"
        case .strength: isCustom ? "Step 3 of 3" : "Step 4 of 4"
        case .custom: "Step 2 of 3"
        }
    }

    private var questionText: String {
        switch page {
        case .instrument: "Which saxophone?"
        case .brand: "Which brand?"
        case .model: "Which model?"
        case .strength: "Which strength?"
        case .custom: "What reed is it?"
        }
    }

    private var question: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(questionText)
                .font(.title(26))
                .foregroundStyle(Palette.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.copy(14))
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
        .padding(.horizontal, Metrics.screenMargin)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    /// A quiet reminder of what you've picked so far.
    private var subtitle: String? {
        switch page {
        case .instrument: nil
        case .brand: instrument.displayName
        case .model: brand?.name
        case .strength:
            isCustom
                ? "\(customBrand.trimmed) \(customModel.trimmed)".trimmed
                : [brand?.name, model?.name].compactMap { $0 }.joined(separator: " ")
        case .custom: instrument.displayName
        }
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case .instrument: instrumentPage
        case .brand: brandPage
        case .model: modelPage
        case .strength: strengthPage
        case .custom: customPage
        }
    }

    @ViewBuilder
    private var footer: some View {
        if page == .strength {
            VStack(spacing: 10) {
                if !nickname.isEmpty || strength != nil {
                    Well(padding: 12) {
                        TextField("Nickname (optional)", text: $nickname)
                            .font(.copy(15))
                            .tint(Palette.accent)
                    }
                }
                PrimaryKey(title: "Add to case", symbol: "plus", enabled: canSave) { save() }
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.bar)
        }
    }

    // MARK: Pages

    private var instrumentPage: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(Instrument.selectable) { option in
                    ChoiceRow(title: option.displayName, isSelected: false) {
                        instrument = option
                        go(to: .brand)
                    }
                }
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var brandPage: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(brands) { option in
                    ChoiceRow(title: option.name,
                              detail: brandDetail(option),
                              isSelected: false) {
                        brand = option
                        model = nil
                        strength = nil
                        go(to: .model)
                    }
                }

                Button {
                    isCustom = true
                    strength = customScale.defaultStrength
                    go(to: .custom)
                } label: {
                    Text("Not listed? Enter it by hand")
                        .font(.copy(14, weight: .medium))
                        .foregroundStyle(Palette.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.sink)
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var modelPage: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(models) { option in
                    ChoiceRow(title: option.name,
                              detail: option.blurb,
                              tag: option.isSynthetic ? "Synthetic" : nil,
                              isSelected: false) {
                        model = option
                        strength = option.scale.defaultStrength
                        go(to: .strength)
                    }
                }
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var strengthPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 10)], spacing: 10) {
                    ForEach(scale.strengths) { option in
                        ChoiceKey(title: option.label,
                                  isSelected: strength?.label == option.label
                                              && strength?.scale == option.scale,
                                  height: 54) {
                            strength = option
                            Haptics.tick()
                        }
                    }
                }
                Text(scale.shortName)
                    .font(.copy(13))
                    .foregroundStyle(Palette.inkTertiary)
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var customPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Well(padding: 14) {
                    TextField("Brand", text: $customBrand)
                        .font(.copy(16))
                        .tint(Palette.accent)
                        .textInputAutocapitalization(.words)
                }
                Well(padding: 14) {
                    TextField("Model", text: $customModel)
                        .font(.copy(16))
                        .tint(Palette.accent)
                        .textInputAutocapitalization(.words)
                }

                Text("How does this brand number its strengths?")
                    .font(.copy(14))
                    .foregroundStyle(Palette.inkSecondary)
                    .padding(.top, 6)

                ForEach(StrengthScale.allCases, id: \.self) { option in
                    ChoiceRow(title: option.shortName,
                              detail: option.strengths.prefix(4)
                                  .map(\.label).joined(separator: "  ") + "  …",
                              isSelected: customScale == option) {
                        customScale = option
                        strength = option.defaultStrength
                        Haptics.tick()
                    }
                }

                PrimaryKey(title: "Continue", symbol: "arrow.right",
                           enabled: !customBrand.trimmed.isEmpty && !customModel.trimmed.isEmpty) {
                    go(to: .strength)
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private func brandDetail(_ brand: ReedBrand) -> String {
        let names = brand.models(for: instrument).prefix(3).map(\.name)
        let extra = brand.models(for: instrument).count - names.count
        return names.joined(separator: ", ") + (extra > 0 ? " and \(extra) more" : "")
    }

    // MARK: Navigation

    private func go(to next: Page) {
        page = next
        Haptics.tick()
    }

    private func back() {
        switch page {
        case .instrument: break
        case .brand: page = .instrument
        case .model: page = .brand
        case .custom: page = .brand; isCustom = false
        case .strength: page = isCustom ? .custom : .model
        }
    }

    private func save() {
        guard let strength else { return }

        let reed: Reed
        if isCustom {
            reed = Reed(brandID: "", brandName: customBrand.trimmed,
                        modelID: "", modelName: customModel.trimmed,
                        strength: strength, instrument: instrument,
                        isCustom: true, nickname: nickname.trimmed,
                        slotIndex: slot)
        } else {
            guard let brand, let model else { return }
            reed = Reed(brandID: brand.id, brandName: brand.name,
                        modelID: model.id, modelName: model.name,
                        strength: strength, instrument: instrument,
                        isSynthetic: model.isSynthetic, nickname: nickname.trimmed,
                        slotIndex: slot)
        }

        context.insert(reed)
        Haptics.reedAdded()
        dismiss()
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

#Preview {
    AddReedView()
        .modelContainer(ModelContainer.preview())
}
