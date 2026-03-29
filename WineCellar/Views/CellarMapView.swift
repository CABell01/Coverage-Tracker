import SwiftUI
import SwiftData

struct CellarMapView: View {
    @Environment(CellarSelection.self) private var cellarSelection
    @Query private var allWines: [Wine]

    @State private var selectedZone: String = ""
    @State private var selectedSlotWines: [Wine] = []
    @State private var showingSlotDetail = false
    @State private var selectedSlotNumber: Int = 0

    private var wines: [Wine] {
        guard let cellar = cellarSelection.selectedCellar else { return allWines }
        return allWines.filter { $0.cellar?.id == cellar.id }
    }

    private var zones: [String] {
        Array(Set(wines.map(\.zone).filter { !$0.isEmpty })).sorted()
    }

    private var winesInZone: [Wine] {
        wines.filter { $0.zone == selectedZone }
    }

    private var maxSlot: Int {
        winesInZone.map(\.slot).max() ?? 12
    }

    private var slotCount: Int {
        max(maxSlot, 12)
    }

    private func winesAt(slot: Int) -> [Wine] {
        winesInZone.filter { $0.slot == slot }
    }

    private func totalBottlesAt(slot: Int) -> Int {
        winesAt(slot: slot).reduce(0) { $0 + $1.quantity }
    }

    var body: some View {
        VStack(spacing: 0) {
            if zones.isEmpty {
                ContentUnavailableView {
                    Label("No Cellar Zones", systemImage: "square.grid.3x3")
                } description: {
                    Text("Add wines with a cellar zone to see them on the map.")
                }
            } else {
                zonePicker
                slotGrid
            }
        }
        .navigationTitle(cellarSelection.selectedCellar.map { "\($0.name) Map" } ?? "Cellar Map")
        .onAppear {
            if selectedZone.isEmpty, let first = zones.first {
                selectedZone = first
            }
        }
        .onChange(of: cellarSelection.selectedCellar) {
            selectedZone = zones.first ?? ""
        }
        .sheet(isPresented: $showingSlotDetail) {
            NavigationStack {
                slotDetailView
            }
            .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private var zonePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(zones, id: \.self) { zone in
                    Button {
                        selectedZone = zone
                    } label: {
                        Text(zone)
                            .font(.subheadline)
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
    private var slotGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(1...slotCount, id: \.self) { slot in
                    let bottles = totalBottlesAt(slot: slot)
                    Button {
                        selectedSlotNumber = slot
                        selectedSlotWines = winesAt(slot: slot)
                        showingSlotDetail = true
                    } label: {
                        VStack(spacing: 4) {
                            Text("#\(slot)")
                                .font(.caption.bold())
                            if bottles > 0 {
                                Image(systemName: "wineglass.fill")
                                    .font(.title3)
                                Text("\(bottles)")
                                    .font(.caption2)
                            } else {
                                Image(systemName: "wineglass")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                Text("empty")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 80)
                        .background(bottles > 0 ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var slotDetailView: some View {
        Group {
            if selectedSlotWines.isEmpty {
                ContentUnavailableView {
                    Label("Empty Slot", systemImage: "wineglass")
                } description: {
                    Text("No wines stored in \(selectedZone) slot #\(selectedSlotNumber).")
                }
            } else {
                List(selectedSlotWines) { wine in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(wine.name.isEmpty ? wine.variety : wine.name)
                            .font(.headline)
                        Text("\(wine.producer) \(String(wine.vintage))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text(wine.variety)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(Capsule())
                            Spacer()
                            Text("\(wine.quantity) bottle\(wine.quantity == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("\(selectedZone) — Slot #\(selectedSlotNumber)")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { showingSlotDetail = false }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CellarMapView()
    }
    .environment(CellarSelection())
    .modelContainer(for: [Wine.self, Cellar.self], inMemory: true)
}
