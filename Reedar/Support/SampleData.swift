import Foundation
import SwiftData

/// A plausible rotation for previews: two reeds in play, three already retired
/// so the lifespan screen has something to say.
enum SampleData {
    @MainActor
    static func populate(_ context: ModelContext) {
        let now = Date()
        func daysAgo(_ days: Int) -> Date {
            Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
        }

        func make(
            brandID: String, brand: String, modelID: String, model: String,
            strength: String, value: Double, scale: StrengthScale,
            instrument: Instrument = .altoSax, addedDaysAgo: Int, nickname: String = "",
            slot: Int = 0
        ) -> Reed {
            Reed(
                brandID: brandID, brandName: brand,
                modelID: modelID, modelName: model,
                strength: Strength(label: strength, value: value, scale: scale),
                instrument: instrument,
                nickname: nickname,
                addedAt: daysAgo(addedDaysAgo),
                slotIndex: slot
            )
        }

        // Active
        let javaRed = make(brandID: "vandoren", brand: "Vandoren",
                           modelID: "vandoren-java-red", model: "Java Red",
                           strength: "2½", value: 2.5, scale: .halfStep,
                           addedDaysAgo: 18, nickname: "Java #3", slot: 0)
        let selectJazz = make(brandID: "daddario", brand: "D'Addario",
                              modelID: "daddario-select-jazz-unfiled", model: "Select Jazz Unfiled",
                              strength: "2M", value: 2.25, scale: .daddarioJazz,
                              instrument: .tenorSax, addedDaysAgo: 9, slot: 1)

        // Straight out of the box — one short session, still breaking in.
        let fresh = make(brandID: "vandoren", brand: "Vandoren",
                         modelID: "vandoren-v16", model: "V16",
                         strength: "3", value: 3.0, scale: .halfStep,
                         addedDaysAgo: 3, slot: 2)

        // Retired
        let old1 = make(brandID: "vandoren", brand: "Vandoren",
                        modelID: "vandoren-java-red", model: "Java Red",
                        strength: "2½", value: 2.5, scale: .halfStep, addedDaysAgo: 120)
        let old2 = make(brandID: "vandoren", brand: "Vandoren",
                        modelID: "vandoren-java-red", model: "Java Red",
                        strength: "2½", value: 2.5, scale: .halfStep, addedDaysAgo: 90)
        let old3 = make(brandID: "daddario", brand: "D'Addario",
                        modelID: "daddario-select-jazz-unfiled", model: "Select Jazz Unfiled",
                        strength: "2M", value: 2.25, scale: .daddarioJazz,
                        instrument: .tenorSax, addedDaysAgo: 75)

        for reed in [javaRed, selectJazz, fresh, old1, old2, old3] {
            context.insert(reed)
        }

        func log(_ reed: Reed, daysAgo days: Int, total: Int,
                 context ctx: SessionContext, ratio: Double? = nil) {
            let r = ratio ?? ctx.defaultPlayingRatio
            let session = PlaySession(
                date: daysAgo(days),
                totalMinutes: total,
                playingMinutes: Int((Double(total) * r / 5).rounded()) * 5,
                context: ctx,
                reed: reed
            )
            context.insert(session)
        }

        log(javaRed, daysAgo: 16, total: 90, context: .practice)
        log(javaRed, daysAgo: 13, total: 120, context: .rehearsal)
        log(javaRed, daysAgo: 9, total: 60, context: .practice)
        log(javaRed, daysAgo: 5, total: 180, context: .gig)
        log(javaRed, daysAgo: 2, total: 60, context: .lesson)
        log(javaRed, daysAgo: 1, total: 45, context: .practice)

        log(fresh, daysAgo: 2, total: 15, context: .practice)

        log(selectJazz, daysAgo: 7, total: 75, context: .practice)
        log(selectJazz, daysAgo: 4, total: 120, context: .rehearsal)
        log(selectJazz, daysAgo: 1, total: 90, context: .practice)

        for day in stride(from: 115, through: 65, by: -6) {
            log(old1, daysAgo: day, total: 90, context: .practice)
        }
        for day in stride(from: 88, through: 40, by: -5) {
            log(old2, daysAgo: day, total: 75, context: .rehearsal)
        }
        for day in stride(from: 72, through: 30, by: -7) {
            log(old3, daysAgo: day, total: 100, context: .practice)
        }

        // A reed the player favours, and one they've stopped reaching for.
        javaRed.isFavourite = true
        fresh.isSetAside = true

        old1.retiredAt = daysAgo(64)
        old1.retireReasonRaw = RetireReason.wentFlat.rawValue
        old2.retiredAt = daysAgo(38)
        old2.retireReasonRaw = RetireReason.feltDone.rawValue
        old3.retiredAt = daysAgo(28)
        old3.retireReasonRaw = RetireReason.wentFlat.rawValue
    }
}
