import Foundation
import SwiftData

/// A player's case a year into using the app: eight bays full, a rotation with
/// real history behind it, and enough retired reeds that the lifespan figures
/// are somebody's rather than a guess.
///
/// This only ever runs behind `-seedSampleData`, into the in-memory store — no
/// shipping build can reach it. It exists for two jobs: the SwiftUI previews,
/// and `Tools/screenshots.sh`, which shoots the App Store screenshots straight
/// out of the app rather than staging them by hand. That second job is why it
/// is this detailed. A case with three reeds in it and one 15-minute session
/// photographs like an app nobody has used yet, and the screens that carry the
/// listing — the case, a reed's page, the lifespan table — are exactly the ones
/// that say nothing until there is a year of playing behind them.
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
            let reed = Reed(
                brandID: brandID, brandName: brand,
                modelID: modelID, modelName: model,
                strength: Strength(label: strength, value: value, scale: scale),
                instrument: instrument,
                nickname: nickname,
                addedAt: daysAgo(addedDaysAgo),
                slotIndex: slot
            )
            context.insert(reed)
            return reed
        }

        func log(_ reed: Reed, daysAgo days: Int, total: Int,
                 context ctx: SessionContext, note: String = "") {
            let ratio = ctx.defaultPlayingRatio
            context.insert(PlaySession(
                date: daysAgo(days),
                totalMinutes: total,
                playingMinutes: Int((Double(total) * ratio / 5).rounded()) * 5,
                context: ctx,
                note: note,
                reed: reed
            ))
        }

        /// A run of sessions at a steady rhythm, for the reeds whose individual
        /// sessions nobody reads — the retired ones behind the averages.
        func history(_ reed: Reed, from: Int, to: Int, every: Int,
                     total: Int, context ctx: SessionContext) {
            for day in stride(from: from, through: to, by: -every) {
                log(reed, daysAgo: day, total: total, context: ctx)
            }
        }

        // MARK: The case — eight bays, eight reeds

        let javaRed = make(brandID: "vandoren", brand: "Vandoren",
                           modelID: "vandoren-java-red", model: "Java Red",
                           strength: "2½", value: 2.5, scale: .halfStep,
                           addedDaysAgo: 24, nickname: "Java #3", slot: 0)
        let selectJazz = make(brandID: "daddario", brand: "D'Addario",
                              modelID: "daddario-select-jazz-unfiled", model: "Select Jazz Unfiled",
                              strength: "3M", value: 3.25, scale: .daddarioJazz,
                              addedDaysAgo: 17, slot: 1)
        let v16 = make(brandID: "vandoren", brand: "Vandoren",
                       modelID: "vandoren-v16", model: "V16",
                       strength: "3", value: 3.0, scale: .halfStep,
                       addedDaysAgo: 12, slot: 2)
        let rigotti = make(brandID: "rigotti", brand: "Rigotti",
                           modelID: "rigotti-gold-jazz", model: "Gold Jazz",
                           strength: "2½ Medium", value: 2.5, scale: .rigottiGold,
                           addedDaysAgo: 20, slot: 3)
        let zz = make(brandID: "vandoren", brand: "Vandoren",
                      modelID: "vandoren-zz", model: "ZZ",
                      strength: "3", value: 3.0, scale: .halfStep,
                      addedDaysAgo: 9, slot: 4)
        let filed = make(brandID: "daddario", brand: "D'Addario",
                         modelID: "daddario-select-jazz-filed", model: "Select Jazz Filed",
                         strength: "3S", value: 3.0, scale: .daddarioJazz,
                         addedDaysAgo: 2, slot: 5)
        let legere = make(brandID: "legere", brand: "Légère",
                          modelID: "legere-signature", model: "Signature",
                          strength: "2.75", value: 2.75, scale: .quarterStep,
                          addedDaysAgo: 60, nickname: "Outdoor gig", slot: 6)
        let marca = make(brandID: "marca", brand: "Marca",
                         modelID: "marca-jazz", model: "Jazz",
                         strength: "3", value: 3.0, scale: .halfStep,
                         addedDaysAgo: 6, slot: 7)

        // The one they reach for. Rested two days, so the case says to play it
        // on the cane rather than in a badge.
        javaRed.isFavourite = true

        log(javaRed, daysAgo: 22, total: 90, context: .practice)
        log(javaRed, daysAgo: 19, total: 120, context: .rehearsal)
        log(javaRed, daysAgo: 15, total: 60, context: .practice, note: "Blowing freely today.")
        log(javaRed, daysAgo: 12, total: 180, context: .gig, note: "Two sets at the Blue Room.")
        log(javaRed, daysAgo: 9, total: 75, context: .practice)
        log(javaRed, daysAgo: 6, total: 60, context: .lesson)
        log(javaRed, daysAgo: 4, total: 150, context: .rehearsal)
        log(javaRed, daysAgo: 2, total: 45, context: .practice, note: "Still the best one in the case.")

        log(selectJazz, daysAgo: 15, total: 75, context: .practice)
        log(selectJazz, daysAgo: 11, total: 120, context: .rehearsal)
        log(selectJazz, daysAgo: 8, total: 90, context: .practice)
        log(selectJazz, daysAgo: 5, total: 210, context: .session, note: "Album date — long day.")
        log(selectJazz, daysAgo: 1, total: 60, context: .practice)

        log(v16, daysAgo: 10, total: 60, context: .practice)
        log(v16, daysAgo: 7, total: 90, context: .lesson)
        log(v16, daysAgo: 4, total: 120, context: .rehearsal)

        log(rigotti, daysAgo: 18, total: 90, context: .practice)
        log(rigotti, daysAgo: 14, total: 60, context: .practice)
        log(rigotti, daysAgo: 10, total: 150, context: .gig)
        log(rigotti, daysAgo: 6, total: 75, context: .audition, note: "Got the chair.")

        log(zz, daysAgo: 8, total: 45, context: .practice)
        log(zz, daysAgo: 3, total: 90, context: .rehearsal)

        // Straight out of the box: one short session, still breaking in.
        log(filed, daysAgo: 2, total: 20, context: .practice, note: "First blow. Keep it short.")

        // A synthetic, and they last: months of outdoor gigs on one reed.
        history(legere, from: 58, to: 5, every: 6, total: 120, context: .gig)

        log(marca, daysAgo: 5, total: 60, context: .practice)

        // MARK: The archive — what the lifespan figures are made of

        func retire(brandID: String, brand: String, modelID: String, model: String,
                    strength: String, value: Double, scale: StrengthScale,
                    added: Int, from: Int, to: Int, every: Int, total: Int,
                    context ctx: SessionContext, on day: Int,
                    reason: RetireReason, note: String = "") {
            let reed = make(brandID: brandID, brand: brand, modelID: modelID, model: model,
                            strength: strength, value: value, scale: scale, addedDaysAgo: added)
            history(reed, from: from, to: to, every: every, total: total, context: ctx)
            reed.retiredAt = daysAgo(day)
            reed.retireReasonRaw = reason.rawValue
            reed.retireNote = note
        }

        // Three of the model they play most, so the app stops calling the
        // average early days.
        retire(brandID: "vandoren", brand: "Vandoren",
               modelID: "vandoren-java-red", model: "Java Red",
               strength: "2½", value: 2.5, scale: .halfStep,
               added: 200, from: 196, to: 150, every: 6, total: 100,
               context: .practice, on: 148, reason: .wentFlat)
        retire(brandID: "vandoren", brand: "Vandoren",
               modelID: "vandoren-java-red", model: "Java Red",
               strength: "2½", value: 2.5, scale: .halfStep,
               added: 152, from: 148, to: 96, every: 6, total: 95,
               context: .practice, on: 94, reason: .feltDone,
               note: "Nothing wrong with it. It just stopped singing.")
        retire(brandID: "vandoren", brand: "Vandoren",
               modelID: "vandoren-java-red", model: "Java Red",
               strength: "2½", value: 2.5, scale: .halfStep,
               added: 98, from: 94, to: 40, every: 7, total: 110,
               context: .rehearsal, on: 38, reason: .wentFlat)

        retire(brandID: "daddario", brand: "D'Addario",
               modelID: "daddario-select-jazz-unfiled", model: "Select Jazz Unfiled",
               strength: "3M", value: 3.25, scale: .daddarioJazz,
               added: 175, from: 170, to: 120, every: 5, total: 80,
               context: .practice, on: 118, reason: .wentFlat)
        retire(brandID: "daddario", brand: "D'Addario",
               modelID: "daddario-select-jazz-unfiled", model: "Select Jazz Unfiled",
               strength: "3M", value: 3.25, scale: .daddarioJazz,
               added: 120, from: 116, to: 70, every: 6, total: 90,
               context: .rehearsal, on: 68, reason: .tooSoft,
               note: "Blew out after the festival week.")
        retire(brandID: "daddario", brand: "D'Addario",
               modelID: "daddario-select-jazz-unfiled", model: "Select Jazz Unfiled",
               strength: "3M", value: 3.25, scale: .daddarioJazz,
               added: 72, from: 68, to: 26, every: 6, total: 85,
               context: .practice, on: 24, reason: .feltDone)

        retire(brandID: "vandoren", brand: "Vandoren",
               modelID: "vandoren-v16", model: "V16",
               strength: "3", value: 3.0, scale: .halfStep,
               added: 130, from: 126, to: 84, every: 7, total: 105,
               context: .practice, on: 82, reason: .wentFlat)
        retire(brandID: "vandoren", brand: "Vandoren",
               modelID: "vandoren-v16", model: "V16",
               strength: "3", value: 3.0, scale: .halfStep,
               added: 86, from: 82, to: 46, every: 6, total: 95,
               context: .gig, on: 44, reason: .warped,
               note: "Wouldn't sit flat after a wet week.")

        // One that didn't die of old age. It shows in the archive and stays out
        // of every average, which is the rule the retire sheet explains.
        retire(brandID: "rigotti", brand: "Rigotti",
               modelID: "rigotti-gold-jazz", model: "Gold Jazz",
               strength: "2½ Medium", value: 2.5, scale: .rigottiGold,
               added: 64, from: 60, to: 52, every: 4, total: 90,
               context: .rehearsal, on: 50, reason: .chipped,
               note: "Caught the tip on the case. Two weeks old.")

        retire(brandID: "legere", brand: "Légère",
               modelID: "legere-signature", model: "Signature",
               strength: "2.75", value: 2.75, scale: .quarterStep,
               added: 240, from: 236, to: 70, every: 8, total: 110,
               context: .gig, on: 68, reason: .feltDone,
               note: "A year of outdoor gigs. Fair innings.")
    }
}
