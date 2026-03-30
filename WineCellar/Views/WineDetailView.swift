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

    private var displayName: String {
        if !wine.name.isEmpty { return wine.name }
        if !wine.variety.isEmpty { return wine.variety }
        return wine.producer
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero header
                heroHeader
                    .padding(.bottom, 16)

                // Info cards
                VStack(spacing: 12) {
                    infoCard {
                        detailRow("Producer", value: wine.producer)
                        Divider()
                        detailRow("Variety", value: wine.variety)
                        if !wine.region.isEmpty {
                            Divider()
                            detailRow("Region", value: wine.region)
                        }
                        if !wine.country.isEmpty {
                            Divider()
                            detailRow("Country", value: wine.country)
                        }
                        Divider()
                        detailRow("Vintage", value: wine.vintage > 0 ? String(wine.vintage) : "No Year")
                    }

                    if !wine.zone.isEmpty {
                        infoCard {
                            Label(wine.zone, systemImage: "mappin")
                                .font(.subheadline)
                        }
                    }

                    infoCard {
                        detailRow("Quantity", value: "\(wine.quantity) bottle\(wine.quantity == 1 ? "" : "s")")
                        Divider()
                        detailRow("Added", value: wine.dateAdded.formatted(date: .abbreviated, time: .omitted))
                        if !wine.notes.isEmpty {
                            Divider()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(wine.notes)
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if !cellarSelection.isReadOnly {
                        VStack(spacing: 8) {
                            Button {
                                showingDrinkSheet = true
                            } label: {
                                Label("Drink This Wine", systemImage: "wineglass")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.orange.opacity(0.12))
                                    .foregroundStyle(.orange)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            Button(role: .destructive) {
                                showingDeleteConfirm = true
                            } label: {
                                Label("Delete Wine", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.red.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
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

    @ViewBuilder
    private var heroHeader: some View {
        VStack(spacing: 0) {
            if let data = wine.photoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: 240)
                    .clipped()
            } else {
                // Gradient placeholder with wine glass
                ZStack {
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "wineglass")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accentColor.opacity(0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: 140)
            }

            // Name + vintage overlay
            VStack(spacing: 6) {
                Text(displayName)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                if !wine.producer.isEmpty && wine.producer != displayName {
                    Text(wine.producer)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    if wine.vintage > 0 {
                        Text(String(wine.vintage))
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    if !wine.variety.isEmpty {
                        Text(wine.variety)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
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
