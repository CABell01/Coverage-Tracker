import SwiftData
import Foundation

@Model
final class Wine {
    var name: String
    var producer: String
    var variety: String
    var region: String
    var vintage: Int
    var zone: String
    var slot: Int
    var notes: String
    var dateAdded: Date
    var quantity: Int

    init(
        name: String = "",
        producer: String = "",
        variety: String = "",
        region: String = "",
        vintage: Int = Calendar.current.component(.year, from: Date()),
        zone: String = "",
        slot: Int = 1,
        notes: String = "",
        dateAdded: Date = .now,
        quantity: Int = 1
    ) {
        self.name = name
        self.producer = producer
        self.variety = variety
        self.region = region
        self.vintage = vintage
        self.zone = zone
        self.slot = slot
        self.notes = notes
        self.dateAdded = dateAdded
        self.quantity = quantity
    }
}
