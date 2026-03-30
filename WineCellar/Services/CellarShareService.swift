import Foundation
import SwiftData
import UniformTypeIdentifiers

// MARK: - Codable Transfer Structs

struct CellarExport: Codable {
    var formatVersion: Int = 1
    var cellar: CellarInfo
    var wines: [WineInfo]
}

struct CellarInfo: Codable {
    var id: UUID
    var name: String
    var ownerName: String
    var lastUpdated: Date
}

struct WineInfo: Codable {
    var name: String
    var producer: String
    var variety: String
    var region: String
    var country: String
    var vintage: Int
    var zone: String
    var slot: Int
    var notes: String
    var dateAdded: Date
    var quantity: Int
    var photoBase64: String?
}

// MARK: - UTType

extension UTType {
    static let wineCellar = UTType(exportedAs: "com.winecellar.cellarfile")
}

// MARK: - Service

enum CellarShareService {

    // MARK: Export

    static func exportCellar(_ cellar: Cellar) throws -> URL {
        let info = CellarInfo(
            id: cellar.id,
            name: cellar.name,
            ownerName: cellar.ownerName,
            lastUpdated: .now
        )

        let wineInfos = cellar.wines.map { wine in
            WineInfo(
                name: wine.name,
                producer: wine.producer,
                variety: wine.variety,
                region: wine.region,
                country: wine.country,
                vintage: wine.vintage,
                zone: wine.zone,
                slot: wine.slot,
                notes: wine.notes,
                dateAdded: wine.dateAdded,
                quantity: wine.quantity,
                photoBase64: wine.photoData?.base64EncodedString()
            )
        }

        let export = CellarExport(cellar: info, wines: wineInfos)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(export)

        let fileName = "\(cellar.name.replacingOccurrences(of: " ", with: "_")).winecellar"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: tempURL)

        return tempURL
    }

    // MARK: Import

    static func importCellar(from url: URL, into context: ModelContext) throws -> Cellar {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(CellarExport.self, from: data)

        // Look for existing cellar with same ID
        let targetID = export.cellar.id
        let descriptor = FetchDescriptor<Cellar>(
            predicate: #Predicate { $0.id == targetID }
        )
        let existing = try context.fetch(descriptor)

        let cellar: Cellar
        if let found = existing.first {
            // Update existing shared cellar — remove old wines
            for wine in found.wines {
                context.delete(wine)
            }
            found.name = export.cellar.name
            found.ownerName = export.cellar.ownerName
            found.lastUpdated = export.cellar.lastUpdated
            cellar = found
        } else {
            // Create new shared cellar
            cellar = Cellar(
                id: export.cellar.id,
                name: export.cellar.name,
                ownerName: export.cellar.ownerName,
                isOwned: false,
                lastUpdated: export.cellar.lastUpdated
            )
            context.insert(cellar)
        }

        // Add wines
        for wineInfo in export.wines {
            let photoData = wineInfo.photoBase64.flatMap { Data(base64Encoded: $0) }
            let wine = Wine(
                name: wineInfo.name,
                producer: wineInfo.producer,
                variety: wineInfo.variety,
                region: wineInfo.region,
                country: wineInfo.country,
                vintage: wineInfo.vintage,
                zone: wineInfo.zone,
                slot: wineInfo.slot,
                notes: wineInfo.notes,
                dateAdded: wineInfo.dateAdded,
                quantity: wineInfo.quantity,
                photoData: photoData
            )
            wine.cellar = cellar
            context.insert(wine)
        }

        return cellar
    }
}
