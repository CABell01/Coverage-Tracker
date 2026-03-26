import SwiftUI
import SwiftData

struct WineListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Wine.vintage, order: .reverse) private var wines: [Wine]
    @State private var filterState = FilterState()
    @State private var showingAddWine = false
    @State private var showingImport = false

    private var filteredWines: [Wine] {
        if filterState.isFiltering {
            return wines.filter { filterState.matches($0) }
        }
        return wines
    }

    private var uniqueVarieties: [String] {
        Array(Set(wines.map(\.variety))).sorted()
    }

    private var uniqueRegions: [String] {
        Array(Set(wines.map(\.region))).sorted()
    }

    private var uniqueProducers: [String] {
        Array(Set(wines.map(\.producer))).sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            wineList
        }
        .navigationTitle("Wine Cellar")
        .searchable(text: $filterState.searchText, prompt: "Search wines...")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingAddWine = true
                    } label: {
                        Label("Add Wine", systemImage: "plus")
                    }
                    Button {
                        showingImport = true
                    } label: {
                        Label("Import CSV", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddWine) {
            NavigationStack {
                AddWineView()
            }
        }
        .sheet(isPresented: $showingImport) {
            NavigationStack {
                ImportView()
            }
        }
    }

    @ViewBuilder
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterMenu("Variety", selection: $filterState.selectedVariety, options: uniqueVarieties)
                filterMenu("Region", selection: $filterState.selectedRegion, options: uniqueRegions)
                filterMenu("Producer", selection: $filterState.selectedProducer, options: uniqueProducers)

                if filterState.isFiltering {
                    Button("Clear") {
                        filterState.clearAll()
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func filterMenu(_ title: String, selection: Binding<String?>, options: [String]) -> some View {
        Menu {
            Button("All") {
                selection.wrappedValue = nil
            }
            ForEach(options, id: \.self) { option in
                Button {
                    selection.wrappedValue = option
                } label: {
                    if selection.wrappedValue == option {
                        Label(option, systemImage: "checkmark")
                    } else {
                        Text(option)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selection.wrappedValue ?? title)
                    .font(.subheadline)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selection.wrappedValue != nil ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
            .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var wineList: some View {
        if filteredWines.isEmpty {
            ContentUnavailableView {
                Label("No Wines", systemImage: "wineglass")
            } description: {
                if wines.isEmpty {
                    Text("Tap + to add your first bottle.")
                } else {
                    Text("No wines match your filters.")
                }
            }
        } else {
            List {
                ForEach(filteredWines) { wine in
                    NavigationLink(destination: WineDetailView(wine: wine)) {
                        WineRowView(wine: wine)
                    }
                }
                .onDelete(perform: deleteWines)
            }
            .listStyle(.plain)
        }
    }

    private func deleteWines(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredWines[index])
        }
    }
}

struct WineRowView: View {
    let wine: Wine

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(wine.name.isEmpty ? wine.variety : wine.name)
                    .font(.headline)
                Spacer()
                Text(String(wine.vintage))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(wine.producer)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if !wine.zone.isEmpty {
                    Label("\(wine.zone) #\(wine.slot)", systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Text(wine.variety)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Capsule())
                if !wine.region.isEmpty {
                    Text(wine.region)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if wine.quantity > 1 {
                    Text("\(wine.quantity) bottles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        WineListView()
    }
    .modelContainer(for: Wine.self, inMemory: true)
}
