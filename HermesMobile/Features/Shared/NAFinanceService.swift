import Foundation

// MARK: - Finance Models
struct NAExpense: Codable, Identifiable {
    var id = UUID().uuidString
    let amount: Double
    let category: String // "essen", "transport", "einkaufen", "wohnen", "freizeit", "gesundheit", "sonstiges"
    let note: String
    let date: Date
    let isBusiness: Bool
}

struct NABudget: Codable, Identifiable {
    var id = UUID().uuidString
    let category: String
    var monthlyLimit: Double
    var spentThisMonth: Double
}

// MARK: - Finance Service
@MainActor
class NAFinanceService: ObservableObject {
    static let shared = NAFinanceService()

    @Published var expenses: [NAExpense] = []
    @Published var budgets: [NABudget] = []
    @Published var isLoading = false

    private let expensesKey = "naice_expenses"
    private let budgetsKey = "naice_budgets"

    init() {
        load()
        if budgets.isEmpty {
            budgets = [
                NABudget(category: "essen", monthlyLimit: 400, spentThisMonth: 0),
                NABudget(category: "transport", monthlyLimit: 150, spentThisMonth: 0),
                NABudget(category: "einkaufen", monthlyLimit: 300, spentThisMonth: 0),
                NABudget(category: "wohnen", monthlyLimit: 800, spentThisMonth: 0),
                NABudget(category: "freizeit", monthlyLimit: 200, spentThisMonth: 0),
                NABudget(category: "gesundheit", monthlyLimit: 100, spentThisMonth: 0),
                NABudget(category: "sonstiges", monthlyLimit: 250, spentThisMonth: 0),
            ]
            save()
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: expensesKey),
           let decoded = try? JSONDecoder().decode([NAExpense].self, from: data) {
            expenses = decoded
        }
        if let data = UserDefaults.standard.data(forKey: budgetsKey),
           let decoded = try? JSONDecoder().decode([NABudget].self, from: data) {
            budgets = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(expenses) {
            UserDefaults.standard.set(data, forKey: expensesKey)
        }
        if let data = try? JSONEncoder().encode(budgets) {
            UserDefaults.standard.set(data, forKey: budgetsKey)
        }
    }

    func addExpense(amount: Double, category: String, note: String, isBusiness: Bool = false) {
        let expense = NAExpense(amount: amount, category: category, note: note, date: Date(), isBusiness: isBusiness)
        expenses.insert(expense, at: 0)
        updateBudgetSpent()
        save()
    }

    func addExpenseVal(amount: Double, category: String, note: String, date: Date) {
        let expense = NAExpense(amount: amount, category: category, note: note, date: date, isBusiness: false)
        // Insert in date-sorted order
        if let idx = expenses.firstIndex(where: { $0.date < date }) {
            expenses.insert(expense, at: idx)
        } else {
            expenses.append(expense)
        }
        updateBudgetSpent()
        save()
    }

    func deleteExpense(_ id: String) {
        expenses.removeAll { $0.id == id }
        updateBudgetSpent()
        save()
    }

    func updateBudget(category: String, newLimit: Double) {
        guard newLimit >= 0 else { return }
        if let idx = budgets.firstIndex(where: { $0.category == category }) {
            budgets[idx].monthlyLimit = newLimit
            save()
        }
    }

    private func updateBudgetSpent() {
        let thisMonth = Calendar.current.component(.month, from: Date())
        let thisYear = Calendar.current.component(.year, from: Date())
        for i in budgets.indices {
            let cat = budgets[i].category
            budgets[i].spentThisMonth = expenses
                .filter { $0.category == cat && !$0.isBusiness }
                .filter { $0.category != "einnahmen" }
                .filter {
                    let c = Calendar.current
                    return c.component(.month, from: $0.date) == thisMonth && c.component(.year, from: $0.date) == thisYear
                }
                .reduce(0) { $0 + $1.amount }
        }
    }

    var monthlyTotal: Double {
        let thisMonth = Calendar.current.component(.month, from: Date())
        let thisYear = Calendar.current.component(.year, from: Date())
        return expenses
            .filter { $0.category != "einnahmen" }
            .filter {
                let c = Calendar.current
                return c.component(.month, from: $0.date) == thisMonth && c.component(.year, from: $0.date) == thisYear
            }
            .reduce(0) { $0 + $1.amount }
    }

    var incomeTotal: Double {
        let thisMonth = Calendar.current.component(.month, from: Date())
        let thisYear = Calendar.current.component(.year, from: Date())
        return expenses
            .filter { $0.category == "einnahmen" }
            .filter {
                let c = Calendar.current
                return c.component(.month, from: $0.date) == thisMonth && c.component(.year, from: $0.date) == thisYear
            }
            .reduce(0) { $0 + $1.amount }
    }

    var incomeEntries: [NAExpense] {
        expenses.filter { $0.category == "einnahmen" }.sorted { $0.date > $1.date }
    }

    var categorySpending: [(String, Double, Double, Double)] {
        // Returns (category, spent, limit, percentage)
        budgets.map { b in
            (b.category, b.spentThisMonth, b.monthlyLimit, b.monthlyLimit > 0 ? (b.spentThisMonth / b.monthlyLimit) * 100 : 0)
        }
    }

    // MARK: - Category Labels
    static func categoryLabel(_ cat: String) -> String {
        switch cat {
        case "essen": return "Essen"
        case "transport": return "Transport"
        case "einkaufen": return "Einkaufen"
        case "wohnen": return "Wohnen"
        case "freizeit": return "Freizeit"
        case "gesundheit": return "Gesundheit"
        case "einnahmen": return "Einnahmen"
        default: return "Sonstiges"
        }
    }

    static func categoryIcon(_ cat: String) -> String {
        switch cat {
        case "essen": return "fork.knife"
        case "transport": return "car.fill"
        case "einkaufen": return "cart.fill"
        case "wohnen": return "house.fill"
        case "freizeit": return "gamecontroller.fill"
        case "gesundheit": return "heart.fill"
        case "einnahmen": return "arrow.down.circle.fill"
        default: return "ellipsis.circle.fill"
        }
    }

    // MARK: - Server Sync
    func syncFromServer() {
        guard let url = URL(string: "https://health.santoslab.de/api/naice/expenses") else { return }
        isLoading = true
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                guard let data = data, error == nil,
                      let serverExpenses = try? JSONDecoder().decode([NAServerExpense].self, from: data) else {
                    print("[Finance] Server sync failed: \(error?.localizedDescription ?? "no data")")
                    return
                }
                // Merge: only add expenses not already in local store
                let existingNotes = Set(self?.expenses.map { $0.note } ?? [])
                var added = 0
                for se in serverExpenses {
                    let note = se.note ?? ""
                    if existingNotes.contains(note) { continue }
                    let expense = NAExpense(amount: se.amount, category: se.category ?? "sonstiges", note: note, date: se.date ?? Date(), isBusiness: false)
                    self?.expenses.append(expense)
                    added += 1
                }
                if added > 0 {
                    self?.updateBudgetSpent()
                    self?.save()
                    print("[Finance] \(added) neue Ausgaben vom Server importiert")
                }
            }
        }.resume()
    }
}

struct NAServerExpense: Codable {
    let amount: Double
    let category: String?
    let note: String?
    let date: Date?
    let isBusiness: Bool?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        amount = try container.decode(Double.self, forKey: .amount)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        isBusiness = try container.decodeIfPresent(Bool.self, forKey: .isBusiness)

        // Date can be ISO string or timestamp
        var parsedDate: Date?
        if let dateStr = try? container.decode(String.self, forKey: .date) {
            // Try ISO8601 with Z suffix first
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            parsedDate = fmt.date(from: dateStr)
            // Try without Z
            if parsedDate == nil {
                fmt.formatOptions = [.withInternetDateTime]
                parsedDate = fmt.date(from: dateStr)
            }
            // Try custom format "yyyy-MM-dd'T'HH:mm:ss"
            if parsedDate == nil {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                f.locale = Locale(identifier: "en_US_POSIX")
                parsedDate = f.date(from: dateStr)
            }
        }
        date = parsedDate
    }

    enum CodingKeys: String, CodingKey {
        case amount, category, note, date, isBusiness
    }
}