import Foundation

struct ReedBrand: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var models: [ReedModel]

    func models(for instrument: Instrument) -> [ReedModel] {
        models.filter { $0.instruments.contains(instrument) }
    }
}

struct ReedModel: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var scale: StrengthScale
    var instruments: Set<Instrument>
    /// Short note shown under the model name — cut, material, what it's for.
    var blurb: String
    var isSynthetic: Bool = false
}

/// The built-in reed catalog. Players pick brand → model → strength rather than
/// typing names, which is what makes the lifespan stats aggregate at all.
///
/// Adding clarinet later is additive: extend each model's `instruments` set (or
/// append clarinet-only models). Nothing else in the app needs to change.
enum ReedCatalog {
    static let sax: Set<Instrument> = [.sopranoSax, .altoSax, .tenorSax, .bariSax]

    static let brands: [ReedBrand] = [
        ReedBrand(id: "vandoren", name: "Vandoren", models: [
            ReedModel(id: "vandoren-traditional", name: "Traditional",
                      scale: .halfStep, instruments: sax,
                      blurb: "The classic blue box. Thin tip, classical staple."),
            ReedModel(id: "vandoren-java", name: "Java",
                      scale: .halfStep, instruments: sax,
                      blurb: "Green box. Thicker tip, flexible, jazz cut."),
            ReedModel(id: "vandoren-java-red", name: "Java Red",
                      scale: .halfStep, instruments: sax,
                      blurb: "Red box. Java cut on a thicker blank, warmer."),
            ReedModel(id: "vandoren-v16", name: "V16",
                      scale: .halfStep, instruments: sax,
                      blurb: "Longer palette, thick heart. Big jazz sound."),
            ReedModel(id: "vandoren-zz", name: "ZZ",
                      scale: .halfStep, instruments: sax,
                      blurb: "Jazz cut with a traditional thick heart. Quick response."),
            ReedModel(id: "vandoren-v21", name: "V21",
                      scale: .halfStep, instruments: sax,
                      blurb: "56 rue Lepic blank with a V12 profile. Even across registers."),
        ]),
        ReedBrand(id: "daddario", name: "D'Addario", models: [
            ReedModel(id: "daddario-select-jazz-filed", name: "Select Jazz Filed",
                      scale: .daddarioJazz, instruments: sax,
                      blurb: "Filed. Bright, immediate, unfiled's louder sibling."),
            ReedModel(id: "daddario-select-jazz-unfiled", name: "Select Jazz Unfiled",
                      scale: .daddarioJazz, instruments: sax,
                      blurb: "Unfiled. Darker and a little more resistant."),
            ReedModel(id: "daddario-reserve", name: "Reserve",
                      scale: .halfStep, instruments: sax,
                      blurb: "Classical. Thick blank, very consistent box to box."),
            ReedModel(id: "daddario-royal", name: "Royal",
                      scale: .halfStep, instruments: sax,
                      blurb: "Filed Rico blank. Easy response, all-rounder."),
            ReedModel(id: "daddario-rico", name: "Rico",
                      scale: .halfStep, instruments: sax,
                      blurb: "Unfiled, thin. Cheap, bright, good for testing."),
            ReedModel(id: "daddario-plasticover", name: "Plasticover",
                      scale: .halfStep, instruments: sax,
                      blurb: "Coated cane. Long-lasting, humidity-proof, bright."),
            ReedModel(id: "daddario-la-voz", name: "La Voz",
                      scale: .softToHard, instruments: sax,
                      blurb: "Unfiled jazz cut, graded soft to hard."),
        ]),
        ReedBrand(id: "legere", name: "Légère", models: [
            ReedModel(id: "legere-signature", name: "Signature",
                      scale: .quarterStep, instruments: sax,
                      blurb: "Synthetic. Thin profile, closest to a broken-in cane reed.",
                      isSynthetic: true),
            ReedModel(id: "legere-american-cut", name: "American Cut",
                      scale: .quarterStep, instruments: sax,
                      blurb: "Synthetic. Jazz cut, thick heart, projects.",
                      isSynthetic: true),
            ReedModel(id: "legere-studio-cut", name: "Studio Cut",
                      scale: .quarterStep, instruments: sax,
                      blurb: "Synthetic. Bright and loud, built for amplified work.",
                      isSynthetic: true),
            ReedModel(id: "legere-classic", name: "Classic",
                      scale: .quarterStep, instruments: sax,
                      blurb: "Synthetic. The original Légère cut.",
                      isSynthetic: true),
        ]),
        ReedBrand(id: "rigotti", name: "Rigotti", models: [
            ReedModel(id: "rigotti-gold", name: "Gold",
                      scale: .rigottiGold, instruments: sax,
                      blurb: "French cane, hand-finished. Light / Medium / Strong grading."),
            ReedModel(id: "rigotti-gold-jazz", name: "Gold Jazz",
                      scale: .rigottiGold, instruments: sax,
                      blurb: "Gold blank with a jazz profile. Freer blowing."),
        ]),
        ReedBrand(id: "fibracell", name: "Fibracell", models: [
            ReedModel(id: "fibracell-premier", name: "Premier",
                      scale: .halfStep, instruments: sax,
                      blurb: "Synthetic. Aramid fibre, very stable, long life.",
                      isSynthetic: true),
        ]),
        ReedBrand(id: "marca", name: "Marca", models: [
            ReedModel(id: "marca-superieure", name: "Supérieure",
                      scale: .halfStep, instruments: sax,
                      blurb: "Filed French cane. Warm and flexible."),
            ReedModel(id: "marca-jazz", name: "Jazz",
                      scale: .halfStep, instruments: sax,
                      blurb: "Unfiled jazz cut, thicker tip."),
            ReedModel(id: "marca-american-vintage", name: "American Vintage",
                      scale: .halfStep, instruments: sax,
                      blurb: "Vintage-style American cut, thick heart."),
        ]),
        ReedBrand(id: "gonzalez", name: "Gonzalez", models: [
            ReedModel(id: "gonzalez-local-63", name: "Local 63",
                      scale: .halfStep, instruments: sax,
                      blurb: "Argentine cane, unfiled. Dark with a firm heart."),
            ReedModel(id: "gonzalez-regular-cut", name: "Regular Cut",
                      scale: .halfStep, instruments: sax,
                      blurb: "Filed. Even, quick response."),
            ReedModel(id: "gonzalez-jazz", name: "Jazz",
                      scale: .halfStep, instruments: sax,
                      blurb: "Jazz profile on Gonzalez cane."),
        ]),
        ReedBrand(id: "alexander", name: "Alexander", models: [
            ReedModel(id: "alexander-superial", name: "Superial",
                      scale: .halfStep, instruments: sax,
                      blurb: "Thin blank, fast response. Long-time jazz favourite."),
            ReedModel(id: "alexander-superial-dc", name: "Superial DC",
                      scale: .halfStep, instruments: sax,
                      blurb: "Double cut. More heart, more resistance than Superial."),
            ReedModel(id: "alexander-ny", name: "NY",
                      scale: .halfStep, instruments: sax,
                      blurb: "Thick blank, dark and centred."),
        ]),
        ReedBrand(id: "hemke", name: "Hemke", models: [
            ReedModel(id: "hemke-select-jazz", name: "Hemke",
                      scale: .halfStep, instruments: sax,
                      blurb: "Frederick Hemke cut, filed. Dark classical standard."),
        ]),
    ]

    static func brand(id: String) -> ReedBrand? {
        brands.first { $0.id == id }
    }

    static func model(id: String) -> ReedModel? {
        brands.lazy.flatMap(\.models).first { $0.id == id }
    }

    /// Brands that make at least one reed for the given instrument.
    static func brands(for instrument: Instrument) -> [ReedBrand] {
        brands.filter { !$0.models(for: instrument).isEmpty }
    }
}
