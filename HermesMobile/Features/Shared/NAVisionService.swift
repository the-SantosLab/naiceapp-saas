import Foundation
import SwiftUI
import Vision
import AVFoundation

// MARK: - Vision Result
struct VisionResult {
    let text: String
    let type: VisionResultType
    let confidence: Double
    let suggestedAction: String
}

enum VisionResultType: String, Codable {
    case receipt, businessCard, note, whiteboard, unknown

    var displayName: String {
        switch self {
        case .receipt: return "Rechnung"
        case .businessCard: return "Visitenkarte"
        case .note: return "Notiz"
        case .whiteboard: return "Whiteboard"
        case .unknown: return "Text"
        }
    }

    var icon: String {
        switch self {
        case .receipt: return "doc.text.magnifyingglass"
        case .businessCard: return "person.text.rectangle"
        case .note: return "note.text"
        case .whiteboard: return "rectangle.3.group"
        case .unknown: return "doc"
        }
    }

    var color: Color {
        switch self {
        case .receipt: return .ncNeonGreen
        case .businessCard: return .ncCyan
        case .note: return .ncAmber
        case .whiteboard: return .ncPurple
        case .unknown: return .gray
        }
    }
}

// MARK: - Vision Service
@MainActor
class NAVisionService: ObservableObject {
    static let shared = NAVisionService()

    @Published var isProcessing = false
    @Published var lastResult: VisionResult?
    @Published var detectedType: VisionResultType?

    private let finance = NAFinanceService.shared

    func requestCameraAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    func processImage(_ image: UIImage) async -> VisionResult {
        isProcessing = true
        defer { isProcessing = false }

        guard let cgImage = image.cgImage else {
            return VisionResult(text: "Bild konnte nicht verarbeitet werden", type: .unknown, confidence: 0, suggestedAction: "Keine Aktion")
        }

        // OCR with Vision
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["de-DE", "en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])

        let text = request.results?
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n") ?? ""

        guard !text.isEmpty else {
            return VisionResult(text: "Kein Text erkannt", type: .unknown, confidence: 0, suggestedAction: "Erneut versuchen")
        }

        let (type, confidence) = classify(text)
        let action = suggestAction(for: type, text: text)

        lastResult = VisionResult(text: String(text.prefix(500)), type: type, confidence: confidence, suggestedAction: action)
        detectedType = type

        return lastResult!
    }

    func executeAction(for result: VisionResult) {
        switch result.type {
        case .receipt:
            // Extract amount, create expense
            let amount = extractAmount(from: result.text)
            let company = extractCompany(from: result.text)
            if amount > 0 {
                finance.addExpense(amount: amount, category: "sonstiges", note: "Rechnung: \(company)")
            }
        case .businessCard:
            let name = extractName(from: result.text)
            let phone = extractPhone(from: result.text)
            let email = extractEmail(from: result.text)
            let company = extractCompany(from: result.text)
            print("[Vision] Visitenkarte: \(name) | \(company) | \(phone) | \(email)")
        case .note:
            print("[Vision] Notiz: \(result.text.prefix(100))")
        case .whiteboard:
            print("[Vision] Whiteboard: \(result.text.prefix(100))")
        case .unknown:
            break
        }
    }

    // MARK: - Classification
    private func classify(_ text: String) -> (VisionResultType, Double) {
        let lower = text.lowercased()

        var scores: [(VisionResultType, Int)] = []

        // Receipt
        var receiptScore = 0
        if lower.contains("€") || lower.contains("eur") || lower.contains("rechnung") || lower.contains("betrag") || lower.contains("zahlung") || lower.contains("mwst") || lower.contains("steuer") || lower.contains("gesamt") {
            receiptScore += 3
        }
        let amounts = extractAmounts(from: text)
        if !amounts.isEmpty { receiptScore += 2 }
        if lower.contains("edeka") || lower.contains("rewe") || lower.contains("aldi") || lower.contains("amazon") { receiptScore += 1 }
        scores.append((.receipt, receiptScore))

        // Business Card
        var cardScore = 0
        if lower.contains("@") && (lower.contains("tel") || lower.contains("mobil") || lower.contains("telefon") || lower.contains("phone")) { cardScore += 3 }
        if lower.contains("str.") || lower.contains("straße") || lower.contains("strasse") { cardScore += 1 }
        if (lower.contains("gmbh") || lower.contains("kg") || lower.contains("e.k.") || lower.contains("e.v.")) { cardScore += 2 }
        if lower.contains("ceo") || lower.contains("geschäftsführer") || lower.contains("director") { cardScore += 2 }
        scores.append((.businessCard, cardScore))

        // Whiteboard / Notes
        var boardScore = 0
        if lower.contains("brainstorm") || lower.contains("idee") || lower.contains("meeting") || lower.contains("todo") || lower.contains("punkt") || lower.contains("agenda") || lower.contains("nächste") { boardScore += 3 }
        if lower.contains("ziel") || lower.contains("plan") || lower.contains("projekt") || lower.contains("deadline") { boardScore += 2 }
        scores.append((.whiteboard, boardScore))

        // Note (default for text)
        scores.append((.note, 1))

        let best = scores.max(by: { $0.1 < $1.1 }) ?? (.unknown, 0)
        let maxScore = scores.map(\.1).max() ?? 1
        let confidence = Double(best.1) / Double(max(maxScore, 3))

        return (best.0, min(confidence, 1.0))
    }

    // MARK: - Extractors
    private func extractAmounts(from text: String) -> [Double] {
        let pattern = #"\b(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})?)\s*(?:€|EUR|eur)\b"#
        var amounts: [Double] = []
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    let cleaned = String(text[range]).replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
                    if let amount = Double(cleaned) { amounts.append(amount) }
                }
            }
        }
        return amounts
    }

    private func extractAmount(from text: String) -> Double {
        extractAmounts(from: text).max() ?? 0
    }

    private func extractCompany(from text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        for line in lines.prefix(5) {
            let lower = line.lowercased()
            if lower.contains("gmbh") || lower.contains("kg") || lower.contains("e.k.") || lower.contains("e.v.") || lower.contains("& co") {
                return line.trimmingCharacters(in: .whitespaces).prefix(40).description
            }
        }
        return ""
    }

    private func extractName(from text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        for line in lines.prefix(3) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let words = trimmed.split(separator: " ")
            if words.count >= 2 {
                let possible = words.map(String.init)
                let hasTitle = possible.contains { ["dr.", "prof.", "dipl."].contains($0.lowercased()) }
                if hasTitle || possible.allSatisfy({ $0.first?.isUppercase ?? false && $0.count > 1 }) {
                    return trimmed.prefix(40).description
                }
            }
        }
        return ""
    }

    private func extractPhone(from text: String) -> String {
        let pattern = #"(\+?\d[\d\s\-/]{7,})"#
        if let match = text.range(of: pattern, options: .regularExpression) {
            return String(text[match]).trimmingCharacters(in: .whitespaces)
        }
        return ""
    }

    private func extractEmail(from text: String) -> String {
        let pattern = #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
        if let match = text.range(of: pattern, options: .regularExpression) {
            return String(text[match])
        }
        return ""
    }

    private func suggestAction(for type: VisionResultType, text: String) -> String {
        switch type {
        case .receipt:
            let amount = extractAmount(from: text)
            let company = extractCompany(from: text)
            return "\(String(format: "%.2f", amount))€ als Ausgabe erfasst · \(company.isEmpty ? "Kategorie: sonstiges" : company)"
        case .businessCard:
            let name = extractName(from: text)
            return "Kontakt \(name) anlegen · WhatsApp-Gruß senden"
        case .note:
            return "Als Journal-Eintrag gespeichert"
        case .whiteboard:
            return "Ideen erfasst · im Chat bearbeitbar"
        case .unknown:
            return "Text erkannt · kein Muster identifiziert"
        }
    }
}