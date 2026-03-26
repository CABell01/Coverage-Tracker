import SwiftUI
import SwiftData

@main
struct WineCellarApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Wine.self, DrinkingLog.self])
    }
}
