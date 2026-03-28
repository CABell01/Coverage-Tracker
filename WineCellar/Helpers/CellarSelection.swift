import SwiftUI

@Observable
class CellarSelection {
    var selectedCellar: Cellar?

    var isReadOnly: Bool {
        guard let cellar = selectedCellar else { return false }
        return !cellar.isOwned
    }
}
