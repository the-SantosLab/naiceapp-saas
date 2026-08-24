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
    let monthlyLimit: Double
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

    func deleteExpense(_ id: String) {
        expenses.removeAll { $0.id == id }
        updateBudgetSpent()
        save()
    }

    private func updateBudgetSpent() {
        let thisMonth = Calendar.current.component(.month, from: Date())
        let thisYear = Calendar.current.component(.year, from: Date())
        for i in budgets.indices {
            let cat = budgets[i].category
            budgets[i].spentThisMonth = expenses
                .filter { $0.category == cat && !$0.isBusiness }
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
            .filter {
                let c = Calendar.current
                return c.component(.month, from: $0.date) == thisMonth && c.component(.year, from: $0.date) == thisYear
            }
            .reduce(0) { $0 + $1.amount }
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
        default: return "ellipsis.circle.fill"
        }
    }
}