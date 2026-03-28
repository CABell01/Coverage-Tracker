import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(CellarSelection.self) private var cellarSelection
    @Query private var cellars: [Cellar]
    @State private var selectedTab = 0

    var body: some View {
        @Bindable var selection = cellarSelection

        VStack(spacing: 0) {
            if cellars.count > 1 {
                cellarPicker
            }

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
        .onAppear {
            if cellarSelection.selectedCellar == nil, let first = cellars.first(where: { $0.isOwned }) ?? cellars.first {
                cellarSelection.selectedCellar = first
            }
        }
    }

    @ViewBuilder
    private var cellarPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(cellars.sorted { $0.isOwned && !$1.isOwned }) { cellar in
                    Button {
                        cellarSelection.selectedCellar = cellar
                    } label: {
                        HStack(spacing: 4) {
                            if !cellar.isOwned {
                                Image(systemName: "person.fill")
                                    .font(.caption2)
                            }
                            Text(cellar.name)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(cellarSelection.selectedCellar?.id == cellar.id ? Color.accentColor : Color(.systemGray6))
                        .foregroundStyle(cellarSelection.selectedCellar?.id == cellar.id ? .white : .primary)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    ContentView()
        .environment(CellarSelection())
        .modelContainer(for: [Wine.self, DrinkingLog.self, Cellar.self], inMemory: true)
}
