import SwiftData
import SwiftUI

@main
struct ReedarApp: App {
    let container: ModelContainer

    init() {
        // Simulator flags, before anything reads them.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-resetIntro") {
            UserDefaults.standard.set(false, forKey: Intro.seenKey)
        }
        if arguments.contains("-skipIntro") {
            UserDefaults.standard.set(true, forKey: Intro.seenKey)
        }
        // `-appearance light|dark|system`, for looking at both materials
        // without tapping into Settings.
        if let index = arguments.firstIndex(of: "-appearance"),
           arguments.indices.contains(index + 1),
           let appearance = Appearance(rawValue: arguments[index + 1]) {
            UserDefaults.standard.set(appearance.rawValue, forKey: Appearance.key)
        }
        if let index = arguments.firstIndex(of: "-accent"),
           arguments.indices.contains(index + 1),
           let accent = Accent(rawValue: arguments[index + 1]) {
            UserDefaults.standard.set(accent.rawValue, forKey: Accent.key)
        }

        // `-seedSampleData` fills an in-memory store with a believable
        // rotation, for screenshots and for poking at the UI in the simulator.
        if arguments.contains("-seedSampleData") {
            container = MainActor.assumeIsolated { ModelContainer.preview() }
            return
        }
        do {
            container = try ModelContainer.reedar()
        } catch {
            // A store that can't open is not recoverable at runtime; failing
            // loudly here beats silently losing a player's history.
            fatalError("Could not open the Reedar store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
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
