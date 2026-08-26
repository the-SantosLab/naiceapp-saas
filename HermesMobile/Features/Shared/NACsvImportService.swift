import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - CSV Import Service
struct NACsvImportService {

    /// Try multiple common German bank CSV formats
    static func parseCSV(_ content: String) -> [NAExpense] {
        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        let parsers: [(String) -> NAExpense?] = [
            parseN26AccountStatementRow,
            parseDKBRow,
            parseINGRow,
            parseN26Row,
            parseGenericSemicolonRow,
            parseGenericCommaRow,
        ]

        var expenses: [NAExpense] = []
        var headerSkipped = false

        for line in lines {
            if !headerSkipped {
                let lower = line.lowercased()
                if lower.contains("buchung") || lower.contains("datum") || lower.contains("date") ||
                   lower.contains("betrag") || lower.contains("amount") || lower.contains("value") ||
                   lower.contains("umsatz") || lower.contains("valuta") ||
                   lower.contains("art,") || lower.contains("produkt,") {
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
    private static func parseDKBRow(_ line: String) -> NAExpense? {
        let cols = parseCSVLine(line)
        guard cols.count >= 5 else { return nil }
        let dateStr = cols[0].trimmingCharacters(in: .init(charactersIn: "\""))
        guard let date = parseDate(dateStr) else { return nil }
        let amountStr = cols[4].trimmingCharacters(in: .init(charactersIn: "\""))
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(amountStr), amount > 0 else { return nil }
        let text = cols.count > 3 ? cols[3].trimmingCharacters(in: .init(charactersIn: "\"")) : ""
        return NAExpense(amount: amount, category: categorize(text), note: String(text.prefix(80)), date: date, isBusiness: false)
    }

    // MARK: - ING Format
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
        return NAExpense(amount: amount, category: categorize(text), note: String(text.prefix(80)), date: date, isBusiness: false)
    }

    // MARK: - N26 Format (Kontoauszug)
    private static func parseN26Row(_ line: String) -> NAExpense? {
        let cols = parseCSVLine(line)
        guard cols.count >= 4 else { return nil }
        let dateStr = cols[0].trimmingCharacters(in: .init(charactersIn: "\""))
        guard let date = parseDate(dateStr) else { return nil }
        let amountStr = cols[3].trimmingCharacters(in: .init(charactersIn: "\""))
        let cleaned = amountStr.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(cleaned), amount > 0 else { return nil }
        let payee = cols.count > 1 ? cols[1].trimmingCharacters(in: .init(charactersIn: "\"")) : ""
        let ref = cols.count > 2 ? cols[2].trimmingCharacters(in: .init(charactersIn: "\"")) : ""
        let text = "\(payee) \(ref)".trimmingCharacters(in: .whitespaces)
        return NAExpense(amount: amount, category: categorize(text), note: String(text.prefix(80)), date: date, isBusiness: false)
    }

    // MARK: - N26 Account Statement Format
    // "Art","Produkt","Datum des Beginns","Datum des Abschlusses","Beschreibung","Betrag","Gebühr","Währung","Status","Kontostand"
    private static func parseN26AccountStatementRow(_ line: String) -> NAExpense? {
        let cols = parseCSVLine(line)
        guard cols.count >= 9 else { return nil }

        // Skip STORNIERT and AUSSTEHEND
        let status = cols[8].trimmingCharacters(in: .init(charactersIn: "\""))
        guard status == "ABGESCHLOSSEN" else { return nil }

        // Date from "Datum des Beginns" (col 2) — format "yyyy-MM-dd HH:mm:ss"
        let dateStr = cols[2].trimmingCharacters(in: .init(charactersIn: "\""))
        guard let date = parseDateFull(dateStr) else { return nil }

        // Amount from "Betrag" (col 5) — N26 uses "." as decimal separator (e.g., -2.02, 10174.50)
        let raw = cols[5].trimmingCharacters(in: .init(charactersIn: "\""))
        let cleaned = raw.replacingOccurrences(of: ",", with: ".") // safety fallback
        guard let signedAmount = Double(cleaned) else { return nil }

        // Only expenses (negative amounts) — include positive as einnahmen
        guard signedAmount != 0 else { return nil }
        let amount = abs(signedAmount)

        let art = cols.count > 0 ? cols[0].trimmingCharacters(in: .init(charactersIn: "\"")) : ""
        let text = cols.count > 4 ? cols[4].trimmingCharacters(in: .init(charactersIn: "\"")) : ""

        if signedAmount > 0 {
            // Revenue
            return NAExpense(amount: amount, category: "einnahmen", note: String(text.prefix(80)), date: date, isBusiness: false)
        }

        return NAExpense(amount: amount, category: categorize(text), note: String(text.prefix(80)), date: date, isBusiness: false)
    }

    // MARK: - Generic
    private static func parseGenericSemicolonRow(_ line: String) -> NAExpense? {
        let cols = line.components(separatedBy: ";")
        guard cols.count >= 2 else { return nil }
        var date: Date?; var amount: Double?; var text = ""
        for col in cols {
            let trimmed = col.trimmingCharacters(in: .whitespaces)
            if let d = parseDate(trimmed) { date = d; continue }
            let cleaned = trimmed.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            if let a = Double(cleaned), a > 0 { amount = a; continue }
            if trimmed.count > 3 && trimmed.rangeOfCharacter(from: .letters) != nil { text = (text + " " + trimmed).trimmingCharacters(in: .whitespaces) }
        }
        guard let d = date, let a = amount else { return nil }
        return NAExpense(amount: a, category: categorize(text), note: String(text.prefix(80)), date: d, isBusiness: false)
    }

    private static func parseGenericCommaRow(_ line: String) -> NAExpense? {
        let cols = line.components(separatedBy: ",")
        guard cols.count >= 2 else { return nil }
        var date: Date?; var amount: Double?; var text = ""
        for col in cols {
            let trimmed = col.trimmingCharacters(in: .whitespaces)
            if let d = parseDate(trimmed) { date = d; continue }
            if let a = Double(trimmed), a > 0 { amount = a; continue }
            if trimmed.count > 3 && trimmed.rangeOfCharacter(from: .letters) != nil { text = (text + " " + trimmed).trimmingCharacters(in: .whitespaces) }
        }
        guard let d = date, let a = amount else { return nil }
        return NAExpense(amount: a, category: categorize(text), note: String(text.prefix(80)), date: d, isBusiness: false)
    }

    private static func parseCSVLine(_ line: String) -> [String] {
        var cols: [String] = []; var current = ""; var inQuotes = false
        for ch in line {
            if ch == "\"" { inQuotes.toggle(); continue }
            if ch == "," || ch == ";" { if !inQuotes { cols.append(current); current = ""; continue } }
            current.append(ch)
        }
        if !current.isEmpty { cols.append(current) }
        return cols
    }

    private static func parseDate(_ str: String) -> Date? {
        let formatters = ["dd.MM.yyyy", "dd.MM.yy", "yyyy-MM-dd", "yyyy/MM/dd", "MM/dd/yyyy", "dd/MM/yyyy"]
        for fmt in formatters {
            let f = DateFormatter(); f.dateFormat = fmt; f.locale = Locale(identifier: "de_DE")
            if let date = f.date(from: str) { return date }
        }
        return nil
    }

    private static func parseDateFull(_ str: String) -> Date? {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm:ss"; f.locale = Locale(identifier: "de_DE")
        return f.date(from: str)
    }

    private static func categorize(_ text: String) -> String {
        let lower = text.lowercased()
        let keywords: [(String, [String])] = [
            ("essen", ["edeka", "rewe", "aldi", "lidl", "netto", "penny", "supermarkt", "bäcker", "restaurant", "cafe", "lieferando", "starbucks", "mcdonalds", "pizza", "essen", "lebensmittel"]),
            ("transport", ["tank", "aral", "shell", "bahn", "deutsche bahn", "mvgo", "taxi", "uber", "miles", "parkplatz", "adac", "auto"]),
            ("einkaufen", ["amazon", "otto", "zalando", "ebay", "mediamarkt", "saturn", "ikea", "bauhaus", "kleidung", "h&m", "zara", "decathlon", "thalia", "buch", "apotheke"]),
            ("wohnen", ["miete", "strom", "wasser", "gas", "heizung", "nebenkost", "versicherung", "telekom", "vodafone", "internet", "handy"]),
            ("freizeit", ["netflix", "spotify", "apple", "disney", "prime", "kino", "konzert", "urlaub", "hotel", "flug", "booking", "airbnb", "fitness", "verein", "streaming"]),
            ("gesundheit", ["arzt", "krankenhaus", "apotheke", "medikament", "zahnarzt", "krankenkasse", "physio", "therapie", "brille"]),
        ]
        for (cat, kws) in keywords { for kw in kws where lower.contains(kw) { return cat } }
        return "sonstiges"
    }
}