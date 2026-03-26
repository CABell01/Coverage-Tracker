import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                WineListView()
            }
            .tabItem {
                Label("Wines", systemImage: "wineglass")
            }

            NavigationStack {
                CellarMapView()
            }
            .tabItem {
                Label("Cellar", systemImage: "square.grid.3x3")
            }

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("History", systemImage: "clock")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Wine.self, DrinkingLog.self], inMemory: true)
}
