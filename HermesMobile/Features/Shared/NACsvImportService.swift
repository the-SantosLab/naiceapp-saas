import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - CSV Import Service
struct NACsvImportService {

    /// Try multiple common German bank CSV formats
    static func parseCSV(_ content: String) -> [NAExpense] {
        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        // Try each format
        let parsers: [(String) -> NAExpense?] = [
            parseDKBRow,
            parseINGRow,
            parseN26Row,
            parseGenericSemicolonRow,
            parseGenericCommaRow,
        ]

        var expenses: [NAExpense] = []
        var headerSkipped = false

        for line in lines {
            // Skip header lines
            if !headerSkipped {
                let lower = line.lowercased()
                if lower.contains("buchung") || lower.contains("datum") || lower.contains("date") ||
                   lower.contains("betrag") || lower.contains("amount") || lower.contains("value") ||
                   lower.contains("umsatz") || lower.contains("valuta") {
                    headerSkipped = true
                    continue
                }
            }
            if !headerSkipped { headerSkipped = true; continue }

            for parser in parsers {
                if let expense = parser(line) {
                    expenses.append(expense)
                    break
                }
            }
        }

        return expenses
    }

    // MARK: - DKB Format
    // "Buchungstag","Wertstellung","Umsatzart","Buchungstext","Betrag (EUR)","..."
    private static func parseDKBRow(_ line: String) -> NAExpense? {
        let cols = parseCSVLine(line)
        guard cols.count >= 5 else { return nil }

        // Check if it looks like DKB (date in first col)
        let dateStr = cols[0].trimmingCharacters(in: .init(charactersIn: "\""))
        guard let date = parseDate(dateStr) else { return nil }

        let amountStr = cols[4].trimmingCharacters(in: .init(charactersIn: "\""))
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(amountStr), amount > 0 else { return nil }

        let text = cols.count > 3 ? cols[3].trimmingCharacters(in: .init(charactersIn: "\"")) : ""
        let category = categorize(text)

        return NAExpense(amount: amount, category: category, note: String(text.prefix(80)), date: date, isBusiness: false)
    }

    // MARK: - ING Format
    // "Buchung","Valuta","Auftraggeber/Empfänger","Buchungstext","Verwendungszweck","Betrag",...
    private static func parseINGRow(_ line: String) -> NAExpense? {
        let cols = parseCSVLine(line)
        guard cols.count >= 6 else { return nil }

        let dateStr = cols[0].trimmingCharacters(in: .init(charactersIn: "\""))
        guard let date = parseDate(dateStr) else { return nil }

        let amountStr = cols[5].trimmingCharacters(in: .init(charactersIn: "\""))
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(amountStr), amount > 0 else { return nil }

        let payee = cols.count > 2 ? cols[2].trimmingCharacters(in: .init(charactersIn: "\"")) : ""
        let purpose = cols.count > 4 ? cols[4].trimmingCharacters(in: .init(charactersIn: "\"")) : ""
        let text = "\(payee) \(purpose)".trimmingCharacters(in: .whitespaces)
        let category = categorize(text)

        return NAExpense(amount: amount, category: category, note: String(text.prefix(80)), date: date, isBusiness: false)
    }

    // MARK: - N26 Format
    // "Date","Payee","Reference","Amount"...
    private static func parseN26Row(_ line: String) -> NAExpense? {
        let cols = parseCSVLine(line)
        guard cols.count >= 4 else { return nil }

        let dateStr = cols[0].trimmingCharacters(in: .init(charactersIn: "\""))
        guard let date = parseDate(dateStr) else { return nil }

        let amountStr = cols[3].trimmingCharacters(in: .init(charactersIn: "\""))
            .replacingOccurrences(of: "\"", with: "")
        let cleaned = amountStr.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(cleaned), amount > 0 else { return nil }

        let payee = cols.count > 1 ? cols[1].trimmingCharacters(in: .init(charactersIn: "\"")) : ""
        let ref = cols.count > 2 ? cols[2].trimmingCharacters(in: .init(charactersIn: "\"")) : ""
        let text = "\(payee) \(ref)".trimmingCharacters(in: .whitespaces)
        let category = categorize(text)

        return NAExpense(amount: amount, category: category, note: String(text.prefix(80)), date: date, isBusiness: false)
    }

    // MARK: - Generic Semicolon (German format: 1,23)
    private static func parseGenericSemicolonRow(_ line: String) -> NAExpense? {
        let cols = line.components(separatedBy: ";")
        guard cols.count >= 2 else { return nil }

        // Try to find a date and amount
        var date: Date?
        var amount: Double?
        var text = ""

        for col in cols {
            let trimmed = col.trimmingCharacters(in: .whitespaces)
            if let d = parseDate(trimmed) { date = d; continue }
            let cleaned = trimmed.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            if let a = Double(cleaned), a > 0 { amount = a; continue }
            if trimmed.count > 3 && trimmed.rangeOfCharacter(from: .letters) != nil {
                text = (text + " " + trimmed).trimmingCharacters(in: .whitespaces)
            }
        }

        guard let d = date, let a = amount else { return nil }
        return NAExpense(amount: a, category: categorize(text), note: String(text.prefix(80)), date: d, isBusiness: false)
    }

    // MARK: - Generic Comma (English format: 1.23)
    private static func parseGenericCommaRow(_ line: String) -> NAExpense? {
        let cols = line.components(separatedBy: ",")
        guard cols.count >= 2 else { return nil }

        var date: Date?
        var amount: Double?
        var text = ""

        for col in cols {
            let trimmed = col.trimmingCharacters(in: .whitespaces)
            if let d = parseDate(trimmed) { date = d; continue }
            if let a = Double(trimmed), a > 0 { amount = a; continue }
            if trimmed.count > 3 && trimmed.rangeOfCharacter(from: .letters) != nil {
                text = (text + " " + trimmed).trimmingCharacters(in: .whitespaces)
            }
        }

        guard let d = date, let a = amount else { return nil }
        return NAExpense(amount: a, category: categorize(text), note: String(text.prefix(80)), date: d, isBusiness: false)
    }

    // MARK: - Helpers
    private static func parseCSVLine(_ line: String) -> [String] {
        var cols: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" { inQuotes.toggle(); continue }
            if ch == "," || ch == ";" { if !inQuotes { cols.append(current); current = ""; continue } }
            current.append(ch)
        }
        if !current.isEmpty { cols.append(current) }
        return cols
    }

    private static func parseDate(_ str: String) -> Date? {
        let formatters = [
            "dd.MM.yyyy", "dd.MM.yy", "yyyy-MM-dd", "yyyy/MM/dd",
            "MM/dd/yyyy", "dd/MM/yyyy", "dd.MM.yyyy HH:mm",
        ]
        for fmt in formatters {
            let f = DateFormatter()
            f.dateFormat = fmt
            f.locale = Locale(identifier: "de_DE")
            if let date = f.date(from: str) { return date }
        }
        return nil
    }

    private static func categorize(_ text: String) -> String {
        let lower = text.lowercased()
        let keywords: [(String, [String])] = [
            ("essen", ["edeka", "rewe", "aldi", "lidl", "netto", "penny", "dm", "rossmann",
                       "supermarkt", "bäcker", "backshop", "müller", "getränk", "restaurant",
                       "cafe", "café", "bistro", "imbiss", "lieferdienst", "lieferando",
                       "starbucks", "mcdonalds", "burger", "pizza", "asia", "griech",
                       "italien", "essen", "lebensmittel", "deli", "markt"]),
            ("transport", ["tank", "aral", "shell", "esso", "total", "avanti",
                           "db ", "bahn", "deutsche bahn", "mvgo", "mvg", "sbahn", "ubahn",
                           "tram", "bus", "taxi", "uber", "miles", "share", "sixt",
                           "parkplatz", "parkhaus", "adac", "werkstatt", "auto",
                           "fahrrad", "reifen", "ölwechsel"]),
            ("einkaufen", ["amazon", "otto", "zalando", "ebay", "mediamarkt", "saturn",
                           "ikea", "bauhaus", "obi", "hornbach", "kleidung", "mode",
                           "schuhe", "h&m", "zara", "decathlon", "thalia", "buch",
                           "apotheke", "müller", "rossmann", "dm"]),
            ("wohnen", ["miete", "strom", "wasser", "gas", "heizung", "nebenkost",
                        "grundsteuer", "versicherung", "haus", "wohnung", "immobilie",
                        "telekom", "vodafone", "internet", "handy", "mobilfunk",
                        "gebaude", "wartung", "handwerker"]),
            ("freizeit", ["netflix", "spotify", "apple", "disney", "prime", "youtube",
                          "kino", "konzert", "museum", "theater", "urlaub", "hotel",
                          "flug", "booking", "airbnb", "spor", "fitness", "studio",
                          "verein", "mitgliedschaft", "streaming", "spiele", "gaming"]),
            ("gesundheit", ["arzt", "krankenhaus", "apotheke", "medikament", "rezept",
                            "zahnarzt", "krankenkasse", "physio", "therapie", "brille",
                            "kontaktlinse", "impfung"]),
        ]
        for (cat, kws) in keywords {
            for kw in kws where lower.contains(kw) { return cat }
        }
        return "sonstiges"
    }
}

// MARK: - Document Picker Wrapper
struct NACsvDocumentPicker: UIViewControllerRepresentable {
    var onImport: ([NAExpense]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.commaSeparatedText, .text, .plainText], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImport: onImport)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onImport: ([NAExpense]) -> Void
        init(onImport: @escaping ([NAExpense]) -> Void) {
            self.onImport = onImport
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let expenses = NACsvImportService.parseCSV(content)
                DispatchQueue.main.async {
                    self.onImport(expenses)
                }
            } catch {
                print("[CSV] Error reading: \(error)")
                // Try latin1
                do {
                    let content = try String(contentsOf: url, encoding: .isoLatin1)
                    let expenses = NACsvImportService.parseCSV(content)
                    DispatchQueue.main.async {
                        self.onImport(expenses)
                    }
                } catch {
                    print("[CSV] Error reading latin1: \(error)")
                }
            }
        }
    }
}