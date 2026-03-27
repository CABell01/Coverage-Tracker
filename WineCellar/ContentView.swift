import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                WineListView()
            }
            .tabItem {
                Label("Wines", systemImage: "wineglass.fill")
            }
            .tag(0)

            NavigationStack {
                CellarMapView()
            }
            .tabItem {
                Label("Cellar", systemImage: "square.grid.3x3.fill")
            }
            .tag(1)

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("History", systemImage: "clock.fill")
            }
            .tag(2)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Wine.self, DrinkingLog.self], inMemory: true)
}
