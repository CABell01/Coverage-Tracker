import SwiftUI
import SwiftData
import PhotosUI

struct AddWineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CellarSelection.self) private var cellarSelection
    @Query private var cellars: [Cellar]

    var existingWine: Wine?

    private var selectedCellar: Cellar? {
        cellars.first(where: { $0.id == cellarSelection.selectedCellarID })
    }

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
    @State private var winePhoto: UIImage?

    @State private var showingScanner = false
    @State private var showingPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?

    private var isEditing: Bool { existingWine != nil }

    private var effectiveVariety: String {
        variety == "Other" ? customVariety : variety
    }

    private var effectiveRegion: String {
        region == "Other" ? customRegion : region
    }

    var body: some View {
        Form {
            // Photo section
            Section {
                if let photo = winePhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 180)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(alignment: .topTrailing) {
                            Button {
                                winePhoto = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.white, .black.opacity(0.5))
                            }
                            .padding(8)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                HStack {
                    if !isEditing {
                        Button {
                            showingScanner = true
                        } label: {
                            Label("Scan Label", systemImage: "camera")
                        }
                    }

                    Spacer()

                    PhotosPicker(selection: $photoPickerItem, matching: .images) {
                        Label(winePhoto == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
                    }
                }
            }

            Section {
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
            } header: {
                Label("Wine Info", systemImage: "info.circle")
            }

            Section {
                TextField("Zone (e.g., Left Wall, Back Rack)", text: $zone)
                Stepper("Slot #\(slot)", value: $slot, in: 1...999)
            } header: {
                Label("Cellar Location", systemImage: "mappin")
            }

            Section {
                Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            } header: {
                Label("Details", systemImage: "note.text")
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
                if let data = wine.photoData {
                    winePhoto = UIImage(data: data)
                }
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
                if let img = scannedData.image { winePhoto = img }
            }
        }
        .onChange(of: photoPickerItem) {
            Task {
                if let data = try? await photoPickerItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    winePhoto = image
                }
            }
        }
    }

    private func resizedImageData(_ image: UIImage) -> Data? {
        let maxDimension: CGFloat = 800
        let size = image.size
        let scale: CGFloat
        if size.width > maxDimension || size.height > maxDimension {
            scale = maxDimension / max(size.width, size.height)
        } else {
            scale = 1.0
        }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }

    private func save() {
        let photoBytes = winePhoto.flatMap { resizedImageData($0) }

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
            wine.photoData = photoBytes
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
                quantity: quantity,
                photoData: photoBytes
            )
            modelContext.insert(wine)
            wine.cellar = selectedCellar
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
