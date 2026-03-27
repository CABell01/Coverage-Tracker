import SwiftUI
import SwiftData

@main
struct WineCellarApp: App {
    var sharedModelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([Wine.self, DrinkingLog.self])
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            sharedModelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
