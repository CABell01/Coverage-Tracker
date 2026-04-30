import SwiftUI

@Observable
class FilterState {
    var searchText: String = ""
    var selectedVariety: String?
    var selectedRegion: String?
    var selectedProducer: String?
    var minVintage: Int?
    var maxVintage: Int?

    var isFiltering: Bool {
        !searchText.isEmpty
            || selectedVariety != nil
            || selectedRegion != nil
            || selectedProducer != nil
            || minVintage != nil
            || maxVintage != nil
    }

    func clearAll() {
        searchText = ""
        selectedVariety = nil
        selectedRegion = nil
        selectedProducer = nil
        minVintage = nil
        maxVintage = nil
    }

    func matches(_ wine: Wine) -> Bool {
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            let found = wine.name.lowercased().contains(query)
                || wine.producer.lowercased().contains(query)
                || wine.region.lowercased().contains(query)
                || wine.variety.lowercased().contains(query)
                || String(wine.vintage).contains(query)
            if !found { return false }
        }
        if let variety = selectedVariety, wine.variety != variety {
            return false
        }
        if let region = selectedRegion, wine.region != region {
            return false
        }
        if let producer = selectedProducer, wine.producer != producer {
            return false
        }
        if let min = minVintage, wine.vintage < min {
            return false
        }
        if let max = maxVintage, wine.vintage > max {
            return false
        }
        return true
    }
}
