# Reedar

A reed tracker for saxophone players. Log what you play, retire reeds when
they're done, and find out how long your reeds actually last — by brand,
model and strength.

Free on the
[App Store](https://apps.apple.com/us/app/reedar-saxophone-reed-tracker/id6799631094)
— no subscription, no in-app purchases, no ads.

Open `Reedar.xcodeproj` and run. No accounts, no onboarding, fully offline.

`Tools/screenshots.sh` renders the App Store screenshot set into
`Store/screenshots/`.

The website is `docs/` — a static site served by GitHub Pages at
[reedar.app](https://reedar.app), carrying the marketing page, the privacy
policy and the support page. `docs/assets/styles.css` takes its colours
straight from `Design/Palette.swift`, so the site and the app are moulded in
the same two materials; `docs/assets/shots/` is the web-sized copy of the App
Store screenshots.

## What's in V1

| Screen | File |
| --- | --- |
| The case (home, and the only top-level screen) | `Features/Home/CaseView.swift` |
| Log a session | `Features/Log/LogSessionView.swift` |
| Reed detail + history | `Features/Detail/ReedDetailView.swift` |
| Retire a reed | `Features/Retire/RetireReedView.swift` |
| Archive of retired reeds | `Features/Retire/ArchiveView.swift` |
| Lifespan stats | `Features/Stats/StatsView.swift` |
| Add a reed | `Features/AddReed/AddReedView.swift` |

## How it's put together

SwiftUI + SwiftData, no third-party dependencies. Two persisted types:

- **`Reed`** — one physical reed. Catalog identity (brand, model, strength) is
  denormalised onto the reed as text alongside the catalog IDs, so a reed
  retired today still reads correctly after the catalog is edited, and a
  custom reed is exactly the same shape as a catalog one.
- **`PlaySession`** — one time that reed was played. `totalMinutes` is clock
  time, `playingMinutes` is the part that actually wore the reed.

`Support/LifespanStats.swift` is the whole analysis layer: it groups retired
reeds by model (and by model + strength), and skips reeds that chipped or were
lost, since those say nothing about how long the model lasts.

### Playing time

Sessions carry a `SessionContext` (practice, lesson, rehearsal, gig,
recording, audition). Each context has an honest default for how much of the
clock time was actually blowing — a rehearsal is mostly counting bars at 45%,
practice is 85%. The estimate is a starting point; the slider in the log flow
always wins.

### Strength scales

Brands number strengths differently, so `StrengthScale` is stored per reed:
half steps (Vandoren, Rico, Marca…), D'Addario Select Jazz (2S/2M/2H),
quarter steps (Légère), Rigotti's Light/Medium/Strong, and Soft-to-Hard.
The strength picker always reflects the scale of the selected model.

## Built to grow

- **Other woodwinds.** `Instrument` is real data on every reed and every
  catalog entry from day one. Shipping clarinet means adding the instruments
  to `ReedModel.instruments` in `Catalog/ReedCatalog.swift` and widening
  `Instrument.selectable`. Nothing else changes.
- **Automatic sessions.** `PlaySession.source` already distinguishes
  `manual` / `automatic` / `imported`. A future metronome or practice timer
  can insert sessions directly; the history view marks automatic ones with a
  bolt. Nothing in the data layer assumes a human filled in a form.
- **Visual pass.** Structure and surface are separated on purpose. Everything
  material lives in `Design/`, and the feature views only compose those pieces.

## How it looks

Home is the case and nothing else: eight slots with a reed lying in each one,
filling its slot end to end. The reed's name and hours are set into the pale
planed end, the brand and strength printed on the bark at the other, exactly
where you'd read them lying in a real case. Tap a reed to open it; tap an empty
slot to fill it. One button in the corner leads to the lifespan data. That's
the whole navigation.

Everything else happens *to a reed*: you pick one up first, and logging,
retiring and history all belong to it. The log sheet never asks which reed —
it already knows.

The case is the screen on an iPad too — the tray still runs to the glass and
takes its corners from the display. What changes is the bays. A bay is a reed's
outline, so its proportion is not negotiable, and `CaseView.bed(in:)` picks the
arrangement that gets the most reed onto the glass: one column of eight in
portrait, two of four in landscape, chosen by which one yields the wider bay
rather than by asking what device this is. Whatever's left over stays bare
tray. Insetting the whole case instead — a rounded rectangle with a hairline,
on a ground of the same colour — reads as a phone pasted onto an iPad, which is
what it was before this.

Everything behind the case is a column of panels held to 520pt
(`Metrics.column`). The switch throughout is `horizontalSizeClass`, not a width
in points; a 6.9" phone is 440pt wide and wants every one of them.

The reeds are drawn, not illustrated. `Design/ReedView.swift` builds the
silhouette from normalised coordinates, so one path serves a reed lying either
way in the case or standing up on its own screen, complete with grain, the vamp
planed toward a translucent tip, and darkening from the tip as hours build up.

The app is black throughout — a reed case is black — with one accent, orange,
reserved for the thing you're meant to press. Surfaces are separated by a
single lit top edge rather than borders, and anything cut into the body gets an
inner shadow.

| File | What lives there |
| --- | --- |
| `Design/Palette.swift` | Every colour, adaptive light/dark |
| `Design/Surfaces.swift` | `raised` / `milled` surfaces, `Panel`, `Well` |
| `Design/Buttons.swift` | Keys, choice keys, selectors |
| `Design/Hardware.swift` | `Display`, `LEDBar`, `LED`, `Tag`, `RuleHeader` |
| `Design/ReedView.swift` | The reed itself |
| `Design/Theme.swift` | Metrics and type |
| `Design/Haptics.swift` | CoreHaptics patterns |

Logging is three questions with big keys — which reed, how long, what was it —
and then one sentence telling you what the app worked out: "that's about 50m of
playing". The ratio slider is behind an "adjust it" link for anyone who wants
it.

## Simulator flags

The app takes a few launch arguments so a screen can be opened directly while
working on it: `-seedSampleData` (in-memory store with a believable rotation),
`-openStats`, `-openReed`, `-openAdd`.

## iCloud sync

The store is already CloudKit-shaped: no unique constraints, every attribute
has a default, every relationship is optional with an inverse. The container
uses `cloudKitDatabase: .automatic`, which syncs across the player's own
devices when the capability is present and stays local when it isn't.

To turn it on: select the Reedar target → Signing & Capabilities → set your
team → add **iCloud** with CloudKit and a container, and add **Background
Modes → Remote notifications**. No code change needed.

## Deliberately not in V1

No tuner, no metronome, no charts, no accounts, no Android.
