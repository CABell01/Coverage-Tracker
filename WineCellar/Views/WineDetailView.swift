import SwiftUI
import SwiftData

struct WineDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CellarSelection.self) private var cellarSelection
    let wine: Wine

    @State private var showingEdit = false
    @State private var showingDrinkSheet = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        List {
            Section("Wine Info") {
                detailRow("Name", value: wine.name)
                detailRow("Producer", value: wine.producer)
                detailRow("Variety", value: wine.variety)
                detailRow("Region", value: wine.region)
                if !wine.country.isEmpty {
                    detailRow("Country", value: wine.country)
                }
                detailRow("Vintage", value: wine.vintage > 0 ? String(wine.vintage) : "No Year")
            }

            Section("Cellar Location") {
                if wine.zone.isEmpty {
                    Text("No location set")
                        .foregroundStyle(.secondary)
                } else {
                    detailRow("Zone", value: wine.zone)
                }
            }

            Section("Details") {
                detailRow("Quantity", value: "\(wine.quantity) bottle\(wine.quantity == 1 ? "" : "s")")
                detailRow("Added", value: wine.dateAdded.formatted(date: .abbreviated, time: .omitted))
                if !wine.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(wine.notes)
                    }
                }
            }

            if !cellarSelection.isReadOnly {
                Section {
                    Button("Drink This Wine") {
                        showingDrinkSheet = true
                    }
                    .foregroundStyle(.orange)

                    Button("Delete Wine", role: .destructive) {
                        showingDeleteConfirm = true
                    }
                }
            }
        }
        .navigationTitle(wine.name.isEmpty ? wine.variety : wine.name)
        .toolbar {
            if !cellarSelection.isReadOnly {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") {
                        showingEdit = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            NavigationStack {
                AddWineView(existingWine: wine)
            }
        }
        .sheet(isPresented: $showingDrinkSheet) {
            NavigationStack {
                DrinkWineView(wine: wine)
            }
        }
        .alert("Delete Wine", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                modelContext.delete(wine)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove all \(wine.quantity) bottle\(wine.quantity == 1 ? "" : "s") from your cellar? This cannot be undone.")
        }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}

#Preview {
    NavigationStack {
        WineDetailView(wine: Wine(
            name: "Reserve Pinot Noir",
            producer: "Domaine Drouhin",
            variety: "Pinot Noir",
            region: "Willamette Valley",
            vintage: 2019,
            zone: "Left Wall",
            slot: 5,
            notes: "Gift from John. Excellent with salmon.",
            quantity: 2
        ))
    }
    .environment(CellarSelection())
    .modelContainer(for: [Wine.self, DrinkingLog.self, Cellar.self], inMemory: true)
}
