import SwiftUI
import SwiftData

struct AddWineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CellarSelection.self) private var cellarSelection

    var existingWine: Wine?

    @State private var name: String = ""
    @State private var producer: String = ""
    @State private var variety: String = ""
    @State private var customVariety: String = ""
    @State private var region: String = ""
    @State private var customRegion: String = ""
    @State private var country: String = ""
    @State private var vintage: Int = Calendar.current.component(.year, from: Date())
    @State private var zone: String = ""
    @State private var slot: Int = 1
    @State private var notes: String = ""
    @State private var quantity: Int = 1

    @State private var showingScanner = false

    private var isEditing: Bool { existingWine != nil }

    private var effectiveVariety: String {
        variety == "Other" ? customVariety : variety
    }

    private var effectiveRegion: String {
        region == "Other" ? customRegion : region
    }

    var body: some View {
        Form {
            if !isEditing {
                Section {
                    Button {
                        showingScanner = true
                    } label: {
                        Label("Scan Bottle Label", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }

            Section("Wine Info") {
                TextField("Wine Name", text: $name)
                TextField("Producer / Winery", text: $producer)

                Picker("Variety", selection: $variety) {
                    Text("Select...").tag("")
                    ForEach(WineData.varieties, id: \.self) { v in
                        Text(v).tag(v)
                    }
                }
                if variety == "Other" {
                    TextField("Custom Variety", text: $customVariety)
                }

                Picker("Region", selection: $region) {
                    Text("Select...").tag("")
                    ForEach(WineData.regions, id: \.self) { r in
                        Text(r).tag(r)
                    }
                }
                if region == "Other" {
                    TextField("Custom Region", text: $customRegion)
                }

                TextField("Country", text: $country)

                Picker("Vintage", selection: $vintage) {
                    ForEach((1970...Calendar.current.component(.year, from: Date())).reversed(), id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
            }

            Section("Cellar Location") {
                TextField("Zone (e.g., Left Wall, Back Rack)", text: $zone)
                Stepper("Slot #\(slot)", value: $slot, in: 1...999)
            }

            Section("Details") {
                Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle(isEditing ? "Edit Wine" : "Add Wine")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(effectiveVariety.isEmpty && name.isEmpty && producer.isEmpty)
            }
        }
        .onAppear {
            if let wine = existingWine {
                name = wine.name
                producer = wine.producer
                if WineData.varieties.contains(wine.variety) {
                    variety = wine.variety
                } else {
                    variety = "Other"
                    customVariety = wine.variety
                }
                if WineData.regions.contains(wine.region) {
                    region = wine.region
                } else {
                    region = "Other"
                    customRegion = wine.region
                }
                country = wine.country
                vintage = wine.vintage
                zone = wine.zone
                slot = wine.slot
                notes = wine.notes
                quantity = wine.quantity
            }
        }
        .sheet(isPresented: $showingScanner) {
            ScanLabelView { scannedData in
                if let v = scannedData.name { name = v }
                if let v = scannedData.producer { producer = v }
                if let v = scannedData.variety {
                    if WineData.varieties.contains(v) {
                        variety = v
                    } else {
                        variety = "Other"
                        customVariety = v
                    }
                }
                if let v = scannedData.region {
                    if WineData.regions.contains(v) {
                        region = v
                    } else {
                        region = "Other"
                        customRegion = v
                    }
                }
                if let v = scannedData.vintage { vintage = v }
            }
        }
    }

    private func save() {
        if let wine = existingWine {
            wine.name = name
            wine.producer = producer
            wine.variety = effectiveVariety
            wine.region = effectiveRegion
            wine.country = country
            wine.vintage = vintage
            wine.zone = zone
            wine.slot = slot
            wine.notes = notes
            wine.quantity = quantity
        } else {
            let wine = Wine(
                name: name,
                producer: producer,
                variety: effectiveVariety,
                region: effectiveRegion,
                country: country,
                vintage: vintage,
                zone: zone,
                slot: slot,
                notes: notes,
                quantity: quantity
            )
            modelContext.insert(wine)
            wine.cellar = cellarSelection.selectedCellar
        }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        AddWineView()
    }
    .modelContainer(for: Wine.self, inMemory: true)
}
