import SwiftData
import Foundation

@Model
final class Cellar {
    var id: UUID
    var name: String
    var ownerName: String
    var isOwned: Bool
    var lastUpdated: Date

    @Relationship(deleteRule: .cascade, inverse: \Wine.cellar)
    var wines: [Wine]

    init(
        id: UUID = UUID(),
        name: String = "",
        ownerName: String = "",
        isOwned: Bool = true,
        lastUpdated: Date = .now,
        wines: [Wine] = []
    ) {
        self.id = id
        self.name = name
        self.ownerName = ownerName
        self.isOwned = isOwned
        self.lastUpdated = lastUpdated
        self.wines = wines
    }
}
