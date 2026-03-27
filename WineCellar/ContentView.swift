import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                WineListView()
            }
            .tabItem {
                Image(systemName: "wine.glass.fill")
                Text("Wines")
            }
            .tag(0)

            NavigationStack {
                CellarMapView()
            }
            .tabItem {
                Image(systemName: "square.grid.3x3.fill")
                Text("Cellar")
            }
            .tag(1)

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Image(systemName: "clock.fill")
                Text("History")
            }
            .tag(2)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Wine.self, DrinkingLog.self], inMemory: true)
}
