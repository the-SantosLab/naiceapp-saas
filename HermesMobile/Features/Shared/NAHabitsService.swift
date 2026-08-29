import Foundation
import SwiftUI

// MARK: - Habit Model
struct NAHabit: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var icon: String
    var frequency: String  // "daily", "weekly", "weekday"
    var goal: Int
    var unit: String
    var color: String
    var created: Int

    var colorValue: Color {
        switch color {
        case "#00E5FF": return Color(red: 0, green: 0.898, blue: 1)
        case "#00E676": return Color(red: 0, green: 0.902, blue: 0.463)
        case "#EF4444": return Color(red: 0.937, green: 0.267, blue: 0.267)
        case "#F59E0B": return Color(red: 0.961, green: 0.62, blue: 0.043)
        case "#7C3AED": return Color(red: 0.486, green: 0.227, blue: 0.929)
        case "#3B82F6": return Color(red: 0.231, green: 0.51, blue: 0.965)
        default: return Color(red: 0, green: 0.898, blue: 1)
        }
    }
}

// MARK: - Habit Log Entry
struct NAHabitLogEntry: Identifiable, Codable, Hashable {
    let id = UUID()
    let habit_id: String
    let date: String
    let value: Int
    let note: String
    let timestamp: Int

    enum CodingKeys: String, CodingKey { case habit_id, date, value, note, timestamp }
}

// MARK: - Goal Model
struct NAGoal: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var category: String  // "health", "business", "creative", "social", "finance"
    var target: String
    var deadline: String
    var progress: Int
    var status: String  // "active", "completed", "archived"
    var created: Int
}

// MARK: - Proactive Briefing
struct NAProactiveBriefing: Codable {
    let time_of_day: String
    let greeting: String
    let recovery: NABriefingRecovery
    let habits: NABriefingHabits
    let goals: NABriefingGoals
    let notes: NABriefingNotes
    let business: NABriefingBusiness
    let suggestions: [String]
}

struct NABriefingRecovery: Codable {
    let score: Int; let hrv: Int; let rhr: Int; let sleep: Double
    let strain: Double; let spo2: Double; let label: String
}

struct NABriefingHabits: Codable {
    let total: Int; let done: Int; let undone: Int; let undone_list: [String]
}

struct NABriefingGoals: Codable {
    let active: Int; let goals: [NABriefingGoalItem]
}

struct NABriefingGoalItem: Codable {
    let title: String; let progress: Int
}

struct NABriefingNotes: Codable {
    let count: Int; let latest: String
}

struct NABriefingBusiness: Codable {
    let naice_total: Int; let foodloop_total: Int
    let deals_active: Int; let deals_value: Int
    let tasks_active: Int; let events_today: Int
}

// MARK: - Services
@MainActor
class NAHabitsService: ObservableObject {
    static let shared = NAHabitsService()

    @Published var habits: [NAHabit] = []
    @Published var logs: [NAHabitLogEntry] = []
    @Published var isLoading = false

    private let serverURL = "https://health.santoslab.de/api/naice"

    private init() {}

    var todayDate: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }

    var todayDone: Int {
        let t = todayDate
        return logs.filter { $0.date == t }.count
    }

    var todayUndone: [NAHabit] {
        let t = todayDate
        let loggedIds = Set(logs.filter { $0.date == t }.map { $0.habit_id })
        return habits.filter { !loggedIds.contains($0.id) }
    }

    var currentStreak: Int {
        var streak = 0
        let cal = Calendar.current
        var day = Date()
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        while true {
            let ds = f.string(from: day)
            let count = logs.filter { $0.date == ds }.count
            if count >= habits.count / 2 { streak += 1 } else { break }
            day = cal.date(byAdding: .day, value: -1, to: day)!
            if streak > 365 { break }
        }
        return streak
    }

    func fetch() async {
        isLoading = true
        defer { isLoading = false }
        guard let hurl = URL(string: "\(serverURL)/habits"),
              let lurl = URL(string: "\(serverURL)/habits/log") else { return }
        do {
            let (hdata, _) = try await URLSession.shared.data(from: hurl)
            let (ldata, _) = try await URLSession.shared.data(from: lurl)
            habits = try JSONDecoder().decode([NAHabit].self, from: hdata)
            logs = try JSONDecoder().decode([NAHabitLogEntry].self, from: ldata)
        } catch { print("[Habits] Fetch error: \(error)") }
    }

    func addHabit(name: String, icon: String = "figure.walk", frequency: String = "daily", goal: Int = 1, unit: String = "", color: String = "#00E5FF") async {
        guard let url = URL(string: "\(serverURL)/habits") else { return }
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["action": "add", "name": name, "icon": icon, "frequency": frequency, "goal": goal, "unit": unit, "color": color]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do { let (data, _) = try await URLSession.shared.data(for: req); if let r = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let hd = r["habit"] as? [String: Any], let hd2 = try? JSONSerialization.data(withJSONObject: hd), let h = try? JSONDecoder().decode(NAHabit.self, from: hd2) { habits.append(h) } } catch {}
    }

    func logHabit(_ habit: NAHabit, value: Int = 1, note: String = "") async {
        guard let url = URL(string: "\(serverURL)/habits") else { return }
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["action": "log", "habit_id": habit.id, "date": todayDate, "value": value, "note": note]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do { let (_, _) = try await URLSession.shared.data(for: req); await fetch() } catch {}
    }

    func deleteHabit(_ habit: NAHabit) async {
        guard let url = URL(string: "\(serverURL)/habits") else { return }
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["action": "delete", "habit_id": habit.id]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do { let (_, _) = try await URLSession.shared.data(for: req); habits.removeAll { $0.id == habit.id } } catch {}
    }
}

@MainActor
class NAGoalsService: ObservableObject {
    static let shared = NAGoalsService()

    @Published var goals: [NAGoal] = []
    @Published var isLoading = false

    private let serverURL = "https://health.santoslab.de/api/naice/goals"

    private init() {}

    var activeGoals: [NAGoal] { goals.filter { $0.status == "active" } }
    var completedGoals: [NAGoal] { goals.filter { $0.status == "completed" } }

    func fetch() async {
        isLoading = true
        defer { isLoading = false }
        guard let url = URL(string: serverURL) else { return }
        do { let (data, _) = try await URLSession.shared.data(from: url); goals = try JSONDecoder().decode([NAGoal].self, from: data) } catch {}
    }

    func addGoal(title: String, category: String = "health", target: String = "", deadline: String = "") async {
        guard let url = URL(string: serverURL) else { return }
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["action": "add", "title": title, "category": category, "target": target, "deadline": deadline]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do { let (data, _) = try await URLSession.shared.data(for: req); if let r = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let gd = r["goal"] as? [String: Any], let gd2 = try? JSONSerialization.data(withJSONObject: gd), let g = try? JSONDecoder().decode(NAGoal.self, from: gd2) { goals.append(g) } } catch {}
    }

    func updateGoal(_ goal: NAGoal, progress: Int? = nil, status: String? = nil) async {
        guard let url = URL(string: serverURL) else { return }
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["action": "update", "goal_id": goal.id]
        if let p = progress { body["progress"] = p }
        if let s = status { body["status"] = s }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do { let (_, _) = try await URLSession.shared.data(for: req); if let idx = goals.firstIndex(where: { $0.id == goal.id }) { if let p = progress { goals[idx].progress = p }; if let s = status { goals[idx].status = s } } } catch {}
    }

    func deleteGoal(_ goal: NAGoal) async {
        guard let url = URL(string: serverURL) else { return }
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["action": "delete", "goal_id": goal.id]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do { let (_, _) = try await URLSession.shared.data(for: req); goals.removeAll { $0.id == goal.id } } catch {}
    }
}