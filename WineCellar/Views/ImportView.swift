import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CellarSelection.self) private var cellarSelection

    @State private var csvData: CSVData?
    @State private var mapping = ColumnMapping()
    @State private var showingFilePicker = true
    @State private var importedCount = 0
    @State private var showingSuccess = false
    @State private var errorMessage: String?

    private let wineFields: [(label: String, keyPath: WritableKeyPath<ColumnMapping, Int?>)] = [
        ("Name", \.name),
        ("Producer", \.producer),
        ("Variety", \.variety),
        ("Region", \.region),
        ("Vintage", \.vintage),
        ("Zone", \.zone),
        ("Slot", \.slot),
        ("Quantity", \.quantity),
        ("Notes", \.notes),
    ]

    var body: some View {
        Group {
            if let csvData = csvData {
                mappingView(csvData)
            } else {
                ContentUnavailableView {
                    Label("Import CSV", systemImage: "square.and.arrow.down")
                } description: {
                    Text("Select a CSV file to import your wine inventory.")
                } actions: {
                    Button("Choose File") {
                        showingFilePicker = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Import Wines")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.commaSeparatedText, UTType.plainText]
        ) { result in
            handleFileSelection(result)
        }
        .alert("Import Complete", isPresented: $showingSuccess) {
            Button("Done") { dismiss() }
        } message: {
            Text("Successfully imported \(importedCount) wine\(importedCount == 1 ? "" : "s").")
        }
        .alert("Import Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func mappingView(_ data: CSVData) -> some View {
        Form {
            Section("CSV Columns") {
                Text("Found \(data.headers.count) columns, \(data.rows.count) rows")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Map Columns to Fields") {
                ForEach(wineFields, id: \.label) { field in
                    Picker(field.label, selection: Binding(
                        get: { mapping[keyPath: field.keyPath] },
                        set: { mapping[keyPath: field.keyPath] = $0 }
                    )) {
                        Text("Skip").tag(nil as Int?)
                        ForEach(Array(data.headers.enumerated()), id: \.offset) { index, header in
                            Text(header.isEmpty ? "Column \(index + 1)" : header).tag(index as Int?)
                        }
                    }
                }
            }

            if !data.rows.isEmpty {
                Section("Preview (First Row)") {
                    let preview = mapping.buildWine(from: data.rows[0])
                    previewRow("Name", value: preview.name)
                    previewRow("Producer", value: preview.producer)
                    previewRow("Variety", value: preview.variety)
                    previewRow("Region", value: preview.region)
                    previewRow("Vintage", value: String(preview.vintage))
                    previewRow("Zone", value: preview.zone)
                    previewRow("Slot", value: "#\(preview.slot)")
                }
            }

            Section {
                Button("Import \(data.rows.count) Wine\(data.rows.count == 1 ? "" : "s")") {
                    performImport(data)
                }
                .frame(maxWidth: .infinity)
                .bold()
                .disabled(mapping.variety == nil && mapping.name == nil && mapping.producer == nil)
            }
        }
    }

    private func previewRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .foregroundStyle(value.isEmpty ? .tertiary : .primary)
        }
    }

    private func handleFileSelection(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Could not access the selected file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let parsed = CSVImporter.parse(content)
                if parsed.headers.isEmpty {
                    errorMessage = "The file appears to be empty."
                } else {
                    csvData = parsed
                    autoMapColumns(parsed)
                }
            } catch {
                errorMessage = "Could not read file: \(error.localizedDescription)"
            }

        case .failure(let error):
            errorMessage = "File selection failed: \(error.localizedDescription)"
        }
    }

    private func autoMapColumns(_ data: CSVData) {
        let headers = data.headers.map { $0.lowercased() }

        for (index, header) in headers.enumerated() {
            if header.contains("name") && !header.contains("zone") {
                mapping.name = index
            } else if header.contains("producer") || header.contains("winery") || header.contains("brand") {
                mapping.producer = index
            } else if header.contains("variety") || header.contains("varietal") || header.contains("grape") || header.contains("type") {
                mapping.variety = index
            } else if header.contains("region") || header.contains("appellation") || header.contains("area") {
                mapping.region = index
            } else if header.contains("vintage") || header.contains("year") {
                mapping.vintage = index
            } else if header.contains("zone") || header.contains("section") || header.contains("location") {
                mapping.zone = index
            } else if header.contains("slot") || header.contains("position") || header.contains("bin") {
                mapping.slot = index
            } else if header.contains("quantity") || header.contains("qty") || header.contains("count") {
                mapping.quantity = index
            } else if header.contains("note") {
                mapping.notes = index
            }
        }
    }

    private func performImport(_ data: CSVData) {
        var count = 0
        for row in data.rows {
            let wine = mapping.buildWine(from: row)
            modelContext.insert(wine)
            wine.cellar = cellarSelection.selectedCellar
            count += 1
        }
        importedCount = count
        showingSuccess = true
    }
}

#Preview {
    NavigationStack {
        ImportView()
    }
    .modelContainer(for: Wine.self, inMemory: true)
}
