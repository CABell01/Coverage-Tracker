import Foundation

struct CSVRow {
    let values: [String]

    func value(at index: Int) -> String {
        guard index >= 0, index < values.count else { return "" }
        return values[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct CSVData {
    let headers: [String]
    let rows: [CSVRow]
}

enum CSVImporter {
    static func parse(_ content: String) -> CSVData {
        let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let headerLine = lines.first else {
            return CSVData(headers: [], rows: [])
        }

        let headers = parseLine(headerLine)
        let rows = lines.dropFirst().map { CSVRow(values: parseLine($0)) }

        return CSVData(headers: headers, rows: rows)
    }

    private static func parseLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)

        return fields.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

struct ColumnMapping {
    var name: Int?
    var producer: Int?
    var variety: Int?
    var region: Int?
    var vintage: Int?
    var zone: Int?
    var slot: Int?
    var quantity: Int?
    var notes: Int?

    func buildWine(from row: CSVRow) -> Wine {
        Wine(
            name: name.map { row.value(at: $0) } ?? "",
            producer: producer.map { row.value(at: $0) } ?? "",
            variety: variety.map { row.value(at: $0) } ?? "",
            region: region.map { row.value(at: $0) } ?? "",
            vintage: vintage.flatMap { Int(row.value(at: $0)) } ?? Calendar.current.component(.year, from: Date()),
            zone: zone.map { row.value(at: $0) } ?? "",
            slot: slot.flatMap { Int(row.value(at: $0)) } ?? 1,
            notes: notes.map { row.value(at: $0) } ?? "",
            quantity: quantity.flatMap { Int(row.value(at: $0)) } ?? 1
        )
    }
}
