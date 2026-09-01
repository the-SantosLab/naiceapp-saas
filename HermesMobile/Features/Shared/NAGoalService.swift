import Foundation
import SwiftUI

// MARK: - Goal Model
struct NALifeGoal: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var description: String
    var category: String // "life", "work", "health", "finance", "social"
    var targetValue: Double
    var currentValue: Double
    var deadline: String?
    var company: String?
    var relatedTasks: [String]
    var icon: String
    var color: String
    var created: Int
    var status: String // "active", "completed", "paused"

    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(1.0, currentValue / targetValue)
    }

    var progressPercent: Int { Int(progress * 100) }

    var colorSwift: Color {
        switch color {
        case "ncCyan": return .ncCyan
        case "ncRose": return .ncRose
        case "ncAmber": return .ncAmber
        case "ncNeonGreen": return .ncNeonGreen
        case "ncBlue": return .ncBlue
        case "ncPurple": return .ncPurple
        default: return .ncCyan
        }
    }

    var categoryLabel: String {
        switch category {
        case "life": return "Leben"
        case "work": return "Arbeit"
        case "health": return "Gesundheit"
        case "finance": return "Finanzen"
        case "social": return "Soziales"
        default: return category
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, title, description, category
        case targetValue = "target_value"
        case currentValue = "current_value"
        case deadline, company
        case relatedTasks = "related_tasks"
        case icon, color, created, status
    }
}

struct NALifeGoalListResponse: Codable {
    let goals: [NALifeGoal]
}

// MARK: - Goals Service
@MainActor
class NAGoalService: ObservableObject {
    static let shared = NAGoalService()

    @Published var goals: [NALifeGoal] = []
    @Published var isLoading = false

    private let baseURL = "https://health.santoslab.de/api/naice/goals"

    var activeGoals: [NALifeGoal] { goals.filter { $0.status == "active" } }
    var completedGoals: [NALifeGoal] { goals.filter { $0.status == "completed" } }

    func fetch() async {
        guard let url = URL(string: baseURL) else { return }
        isLoading = true
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(NALifeGoalListResponse.self, from: data)
            goals = response.goals
        } catch { print("[Goals] Fetch error: \(error)") }
        isLoading = false
    }

    func addGoal(title: String, description: String = "", category: String = "life", targetValue: Double = 100, deadline: String? = nil, company: String? = nil, icon: String = "star.fill", color: String = "ncCyan") async -> NALifeGoal? {
        guard let url = URL(string: baseURL) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["action": "add", "title": title, "description": description, "category": category, "target_value": targetValue, "deadline": deadline ?? "", "company": company ?? "", "icon": icon, "color": color]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let result = try JSONDecoder().decode(NALifeGoalAddResponse.self, from: data)
            if let goal = result.goal { goals.insert(goal, at: 0) }
            return result.goal
        } catch { print("[Goals] Add error: \(error)"); return nil }
    }

    func update(goalId: String, currentValue: Double? = nil, status: String? = nil) async {
        guard let url = URL(string: baseURL) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["action": "update", "goal_id": goalId]
        if let cv = currentValue { body["current_value"] = cv }
        if let s = status { body["status"] = s }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let result = try JSONDecoder().decode(NALifeGoalUpdateResponse.self, from: data)
            if let goal = result.goal, let idx = goals.firstIndex(where: { $0.id == goalId }) {
                goals[idx] = goal
            }
        } catch { print("[Goals] Update error: \(error)") }
    }

    func delete(goalId: String) async {
        guard let url = URL(string: baseURL) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["action": "delete", "goal_id": goalId])
        do {
            let _ = try await URLSession.shared.data(for: req)
            goals.removeAll { $0.id == goalId }
        } catch { print("[Goals] Delete error: \(error)") }
    }
}

struct NALifeGoalAddResponse: Codable { let ok: Bool?; let goal: NALifeGoal? }
struct NALifeGoalUpdateResponse: Codable { let ok: Bool?; let goal: NALifeGoal? }