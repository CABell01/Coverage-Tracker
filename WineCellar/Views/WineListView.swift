import SwiftUI
import SwiftData

struct WineListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CellarSelection.self) private var cellarSelection
    @Query(sort: \Wine.vintage, order: .reverse) private var allWines: [Wine]
    @Query private var cellars: [Cellar]
    @State private var filterState = FilterState()
    @State private var showingAddWine = false
    @State private var showingImport = false
    @State private var showingShareSheet = false
    @State private var shareFileURL: URL?
    @State private var showingNewCellar = false
    @State private var newCellarName = ""
    @State private var newCellarOwner = ""

    private var selectedCellar: Cellar? {
        cellars.first(where: { $0.id == cellarSelection.selectedCellarID })
    }

    private var wines: [Wine] {
        guard let id = cellarSelection.selectedCellarID else { return allWines }
        return allWines.filter { $0.cellar?.id == id }
    }

    private var filteredWines: [Wine] {
        if filterState.isFiltering {
            return wines.filter { filterState.matches($0) }
        }
        return wines
    }

    private var uniqueVarieties: [String] {
        Array(Set(wines.map(\.variety).filter { !$0.isEmpty })).sorted()
    }

    private var uniqueRegions: [String] {
        Array(Set(wines.map(\.region).filter { !$0.isEmpty })).sorted()
    }

    private var uniqueProducers: [String] {
        Array(Set(wines.map(\.producer).filter { !$0.isEmpty })).sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            wineList
        }
        .navigationTitle(selectedCellar?.name ?? "Wine Cellar")
        .searchable(text: $filterState.searchText, prompt: "Search wines...")
        .toolbar {
            if !cellarSelection.isReadOnly {
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
                        Button {
                            shareCellar()
                        } label: {
                            Label("Share My Cellar", systemImage: "square.and.arrow.up")
                        }
                        Divider()
                        Button {
                            newCellarName = ""
                            newCellarOwner = ""
                            showingNewCellar = true
                        } label: {
                            Label("Create New Cellar", systemImage: "plus.square.on.square")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
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
        .sheet(isPresented: $showingShareSheet) {
            if let url = shareFileURL {
                ShareSheet(items: [url])
            }
        }
        .alert("New Cellar", isPresented: $showingNewCellar) {
            TextField("Cellar Name", text: $newCellarName)
            TextField("Owner Name", text: $newCellarOwner)
            Button("Create") {
                createCellar()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Create a cellar to import someone else's wines into.")
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

    private var emptyMessage: String {
        if wines.isEmpty {
            return cellarSelection.isReadOnly ? "This cellar is empty." : "Tap + to add your first bottle."
        }
        return "No wines match your filters."
    }

    @ViewBuilder
    private var wineList: some View {
        if filteredWines.isEmpty {
            ContentUnavailableView("No Wines", systemImage: "wineglass", description: Text(emptyMessage))
        } else {
            List {
                ForEach(filteredWines) { wine in
                    NavigationLink(destination: WineDetailView(wine: wine)) {
                        WineRowView(wine: wine)
                    }
                }
                .onDelete(perform: deleteWines)
                .deleteDisabled(cellarSelection.isReadOnly)
            }
            .listStyle(.plain)
        }
    }

    private func deleteWines(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredWines[index])
        }
    }

    private func createCellar() {
        guard !newCellarName.isEmpty else { return }
        let cellar = Cellar(
            name: newCellarName,
            ownerName: newCellarOwner.isEmpty ? newCellarName : newCellarOwner,
            isOwned: true
        )
        modelContext.insert(cellar)
        cellarSelection.selectedCellarID = cellar.id
        cellarSelection.selectedCellarIsOwned = cellar.isOwned
    }

    private func shareCellar() {
        guard let cellar = selectedCellar else { return }
        do {
            let url = try CellarShareService.exportCellar(cellar)
            shareFileURL = url
            showingShareSheet = true
        } catch {
            // Export failed silently for now
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct WineRowView: View {
    let wine: Wine

    var body: some View {
        HStack(spacing: 12) {
            WineThumbnail(photoData: wine.photoData, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(wine.name.isEmpty ? (wine.variety.isEmpty ? wine.producer : wine.variety) : wine.name)
                        .font(.headline)
                    Spacer()
                    Text(wine.vintage > 0 ? String(wine.vintage) : "No Year")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(wine.producer)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !wine.zone.isEmpty {
                        Label(wine.zone, systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    if !wine.variety.isEmpty {
                        Text(wine.variety)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(Capsule())
                    }
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
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        WineListView()
    }
    .environment(CellarSelection())
    .modelContainer(for: [Wine.self, Cellar.self], inMemory: true)
}
