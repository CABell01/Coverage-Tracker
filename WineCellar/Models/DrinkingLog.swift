import SwiftData
import Foundation

@Model
final class DrinkingLog {
    var wineName: String
    var producer: String
    var variety: String
    var vintage: Int
    var dateConsumed: Date
    var rating: Int
    var tastingNotes: String

    init(
        wineName: String = "",
        producer: String = "",
        variety: String = "",
        vintage: Int = 0,
        dateConsumed: Date = .now,
        rating: Int = 3,
        tastingNotes: String = ""
    ) {
        self.wineName = wineName
        self.producer = producer
        self.variety = variety
        self.vintage = vintage
        self.dateConsumed = dateConsumed
        self.rating = rating
        self.tastingNotes = tastingNotes
    }
}
