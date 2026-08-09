import SwiftData
import SwiftUI

@main
struct ReedarApp: App {
    /// The player's own reeds. Built once, whether or not it is being shown.
    private let store: ModelContainer
    /// A case with a few reeds in it that exist only in memory, for the tour
    /// to be given on. See `Tour`: nothing shown during onboarding is real, so
    /// nothing shown during onboarding can be written to disk or synced.
    @State private var demo: ModelContainer?

    @AppStorage(Intro.seenKey) private var hasSeenIntro = false

    init() {
        // Before anything reads it. The tour is decided at launch, so a flag
        // that lands after the first `task` is a flag that does nothing.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-resetIntro") {
            UserDefaults.standard.set(false, forKey: Intro.seenKey)
        }
        if arguments.contains("-skipIntro") {
            UserDefaults.standard.set(true, forKey: Intro.seenKey)
        }

        // `-seedSampleData` fills an in-memory store with a believable
        // rotation, for screenshots and for poking at the UI in the simulator.
        if ProcessInfo.processInfo.arguments.contains("-seedSampleData") {
            store = MainActor.assumeIsolated { ModelContainer.preview() }
            return
        }
        do {
            store = try ModelContainer.reedar()
        } catch {
            // A store that can't open is not recoverable at runtime; failing
            // loudly here beats silently losing a player's history.
            fatalError("Could not open the Reedar store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(isDemo: demo != nil)
                // Swapping the container rebuilds everything below it, which is
                // exactly what should happen the moment the borrowed reeds go
                // and the player's own empty case takes their place.
                .modelContainer(demo ?? store)
                .task { if !hasSeenIntro, demo == nil { demo = ModelContainer.preview() } }
                .onChange(of: hasSeenIntro) { _, seen in
                    if seen { withAnimation(.settle) { demo = nil } }
                }
        }
    }
}

extension ModelContainer {
    static let schema = Schema([Reed.self, PlaySession.self])

    /// The app store. `cloudKitDatabase: .automatic` syncs across the player's
    /// own devices when the iCloud capability is enabled on the target, and
    /// quietly stays local when it isn't — no accounts, no sign-in, no prompts.
    static func reedar() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "Reedar",
            schema: schema,
            cloudKitDatabase: .automatic
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// In-memory container for previews, seeded with a plausible rotation.
    @MainActor
    static func preview() -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: configuration)
        SampleData.populate(container.mainContext)
        return container
    }
}
