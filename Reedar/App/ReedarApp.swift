import SwiftData
import SwiftUI

@main
struct ReedarApp: App {
    let container: ModelContainer

    init() {
        // `-seedSampleData` fills an in-memory store with a believable
        // rotation, for screenshots and for poking at the UI in the simulator.
        if ProcessInfo.processInfo.arguments.contains("-seedSampleData") {
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
