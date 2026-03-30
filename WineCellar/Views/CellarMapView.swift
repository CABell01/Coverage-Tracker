import SwiftUI
import SwiftData

struct CellarMapView: View {
    @Environment(CellarSelection.self) private var cellarSelection
    @Query(sort: \Wine.variety) private var allWines: [Wine]
    @Query private var cellars: [Cellar]

    @State private var selectedZone: String = ""

    private var selectedCellar: Cellar? {
        cellars.first(where: { $0.id == cellarSelection.selectedCellarID })
    }

    private var wines: [Wine] {
        guard let id = cellarSelection.selectedCellarID else { return allWines }
        return allWines.filter { $0.cellar?.id == id }
    }

    private var zones: [String] {
        Array(Set(wines.map(\.zone).filter { !$0.isEmpty })).sorted()
    }

    private var winesInZone: [Wine] {
        wines.filter { $0.zone == selectedZone }
    }

    var body: some View {
        VStack(spacing: 0) {
            if zones.isEmpty {
                ContentUnavailableView {
                    Label("No Locations", systemImage: "square.grid.3x3")
                } description: {
                    Text("Add wines with a location to see them here.")
                }
            } else {
                zonePicker
                zoneWineList
            }
        }
        .navigationTitle(selectedCellar.map { "\($0.name) Map" } ?? "Cellar Map")
        .onAppear {
            if selectedZone.isEmpty, let first = zones.first {
                selectedZone = first
            }
        }
        .onChange(of: cellarSelection.selectedCellarID) {
            selectedZone = zones.first ?? ""
        }
    }

    @ViewBuilder
    private var zonePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(zones, id: \.self) { zone in
                    let count = wines.filter { $0.zone == zone }.count
                    Button {
                        selectedZone = zone
                    } label: {
                        HStack(spacing: 4) {
                            Text(zone)
                                .font(.subheadline)
                            Text("\(count)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(selectedZone == zone ? Color.white.opacity(0.3) : Color.accentColor.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedZone == zone ? Color.accentColor : Color(.systemGray6))
                        .foregroundStyle(selectedZone == zone ? .white : .primary)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private var zoneWineList: some View {
        if winesInZone.isEmpty {
            ContentUnavailableView("No Wines", systemImage: "wineglass", description: Text("No wines in \(selectedZone)."))
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(winesInZone, id: \.id) { wine in
                        NavigationLink(destination: WineDetailView(wine: wine)) {
                            ZoneWineRow(wine: wine)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
        }
    }
}

struct ZoneWineRow: View {
    let wine: Wine

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.headline)
                HStack {
                    Text(wine.producer)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(vintageText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !wine.variety.isEmpty {
                    Text(wine.variety)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            Spacer()
            if wine.quantity > 1 {
                Text("\(wine.quantity)")
                    .font(.title3.bold())
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 4)
    }

    private var displayName: String {
        if !wine.name.isEmpty { return wine.name }
        if !wine.variety.isEmpty { return wine.variety }
        return wine.producer
    }

    private var vintageText: String {
        wine.vintage > 0 ? String(wine.vintage) : "No Year"
    }
}

#Preview {
    NavigationStack {
        CellarMapView()
    }
    .environment(CellarSelection())
    .modelContainer(for: [Wine.self, Cellar.self], inMemory: true)
}
