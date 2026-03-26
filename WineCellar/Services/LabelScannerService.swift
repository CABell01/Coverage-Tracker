import Vision
import UIKit

struct ScannedWineData {
    var name: String?
    var producer: String?
    var variety: String?
    var region: String?
    var vintage: Int?
}

class LabelScannerService {
    func scan(image: UIImage) async -> ScannedWineData {
        guard let cgImage = image.cgImage else {
            return ScannedWineData()
        }

        let observations = await recognizeText(in: cgImage)
        return parseObservations(observations)
    }

    private func recognizeText(in image: CGImage) async -> [VNRecognizedTextObservation] {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                let results = request.results as? [VNRecognizedTextObservation] ?? []
                continuation.resume(returning: results)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en", "fr", "it", "es"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }

    private func parseObservations(_ observations: [VNRecognizedTextObservation]) -> ScannedWineData {
        var data = ScannedWineData()

        // Collect all text with bounding box heights for size-based heuristics
        struct TextBlock {
            let text: String
            let height: CGFloat
        }

        var blocks: [TextBlock] = []
        var allText: [String] = []

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(TextBlock(text: text, height: observation.boundingBox.height))
                allText.append(text)
            }
        }

        let combined = allText.joined(separator: " ")

        // Extract vintage: 4-digit year between 1900 and current year
        let currentYear = Calendar.current.component(.year, from: Date())
        let yearPattern = "\\b(19[0-9]{2}|20[0-9]{2})\\b"
        if let regex = try? NSRegularExpression(pattern: yearPattern),
           let match = regex.firstMatch(in: combined, range: NSRange(combined.startIndex..., in: combined)),
           let range = Range(match.range(at: 1), in: combined) {
            let yearStr = String(combined[range])
            if let year = Int(yearStr), year >= 1900, year <= currentYear {
                data.vintage = year
            }
        }

        // Extract variety: match against known varieties
        let lowerCombined = combined.lowercased()
        for variety in WineData.varieties {
            if variety == "Other" { continue }
            if lowerCombined.contains(variety.lowercased()) {
                data.variety = variety
                break
            }
        }

        // Extract region: match against known regions
        for region in WineData.regions {
            if region == "Other" { continue }
            if lowerCombined.contains(region.lowercased()) {
                data.region = region
                break
            }
        }

        // Producer: the largest text block (by bounding box height) that isn't a year
        let sortedBlocks = blocks.sorted { $0.height > $1.height }
        for block in sortedBlocks {
            let text = block.text
            // Skip if it's just a year
            if let _ = Int(text), text.count == 4 { continue }
            // Skip if it's a known variety or region (those aren't the producer)
            if WineData.varieties.contains(where: { text.lowercased() == $0.lowercased() }) { continue }
            if WineData.regions.contains(where: { text.lowercased() == $0.lowercased() }) { continue }
            data.producer = text
            break
        }

        // Wine name: second-largest text block that isn't the producer, year, variety, or region
        for block in sortedBlocks {
            let text = block.text
            if text == data.producer { continue }
            if let _ = Int(text), text.count == 4 { continue }
            if WineData.varieties.contains(where: { text.lowercased() == $0.lowercased() }) { continue }
            if WineData.regions.contains(where: { text.lowercased() == $0.lowercased() }) { continue }
            if text.count < 2 { continue }
            data.name = text
            break
        }

        return data
    }
}
