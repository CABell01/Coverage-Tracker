import SwiftUI

@Observable
class CellarSelection {
    var selectedCellarID: UUID?
    var selectedCellarIsOwned: Bool = true

    var isReadOnly: Bool {
        selectedCellarID != nil && !selectedCellarIsOwned
    }
}
