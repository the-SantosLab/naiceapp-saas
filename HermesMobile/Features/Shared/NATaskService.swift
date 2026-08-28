import Foundation
import SwiftUI

// MARK: - Task Item Model
struct NATaskItem: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var project: String?
    var priority: String
    var status: String
    var deadline: String?
    var source: String?
    var created: Int?
    var isLocal: Bool = false

    var isCompleted: Bool {
        get { status == "done" }
        set { status = newValue ? "done" : "open" }
    }

    var priorityColor: Color {
        switch priority.lowercased() {
        case "high": return .ncRose
        case "medium": return .ncAmber
        default: return .ncCyan
        }
    }

    var deadlineDate: Date? {
        guard let d = deadline, !d.isEmpty else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        if let date = f.date(from: d) { return date }
        let f2 = DateFormatter()
        f2.dateFormat = "yyyy-MM-dd"
        return f2.date(from: d)
    }

    var deadlineLabel: String {
        guard let date = deadlineDate else { return "" }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days < 0 { return "\(abs(days))d überfällig" }
        if days == 0 { return "Heute" }
        if days == 1 { return "Morgen" }
        return "\(days)d"
    }

    var deadlineColor: Color {
        guard let date = deadlineDate else { return .gray }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 99
        if days < 0 { return .ncRose }
        if days == 0 { return .ncAmber }
        return .gray
    }

    var statusDot: Color {
        switch status.lowercased() {
        case "open": return .ncAmber
        case "in_progress": return .ncCyan
        case "done": return .ncNeonGreen
        default: return .gray
        }
    }

    init(id: String = String(UUID().uuidString.prefix(8)),
         title: String,
         project: String? = "nAIce",
         priority: String = "medium",
         status: String = "open",
         deadline: String? = nil,
         source: String? = "ios",
         created: Int? = nil,
         isLocal: Bool = true) {
        self.id = id
        self.title = title
        self.project = project
        self.priority = priority
        self.status = status
        self.deadline = deadline
        self.source = source
        self.created = created ?? Int(Date().timeIntervalSince1970)
        self.isLocal = isLocal
    }

    init(from rollupTask: NATask) {
        self.id = rollupTask.id
        self.title = rollupTask.title
        self.project = rollupTask.project
        self.priority = rollupTask.priority ?? "medium"
        self.status = rollupTask.status ?? "open"
        self.deadline = rollupTask.deadline
        self.source = rollupTask.source
        self.created = nil
        self.isLocal = false
    }
}

// MARK: - Task Service
@MainActor
class NATaskService: ObservableObject {
    static let shared = NATaskService()

    @Published var tasks: [NATaskItem] = []
    @Published var isLoading = false
    @Published var lastError: String?

    private let serverURL = "https://health.santoslab.de/api/naice/tasks"

    private init() {}

    func fetch() async {
        isLoading = true
        defer { isLoading = false }

        await NARollupService.shared.fetch()
        var merged: [NATaskItem] = []

        if let rollupTasks = NARollupService.shared.tasks?.tasks {
            for t in rollupTasks {
                let item = NATaskItem(from: t)
                if item.status != "done" {
                    merged.append(item)
                }
            }
        }

        guard let url = URL(string: serverURL) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let serverTasks = try JSONDecoder().decode([NATaskItem].self, from: data)
            let rollupIds = Set(merged.map { $0.id })
            for t in serverTasks where !rollupIds.contains(t.id) {
                var item = t
                item.isLocal = true
                merged.append(item)
            }
        } catch {
            lastError = "Server: \(error.localizedDescription)"
        }

        merged.sort { a, b in
            if a.status != b.status { return a.status == "open" && b.status != "open" }
            let pOrder = ["high": 0, "medium": 1, "low": 2]
            return (pOrder[a.priority] ?? 2) < (pOrder[b.priority] ?? 2)
        }

        tasks = merged
    }

    func addTask(title: String, project: String = "nAIce", priority: String = "medium", deadline: String? = nil) async {
        guard let url = URL(string: serverURL) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["action": "add", "title": title, "project": project, "priority": priority]
        if let d = deadline { body["deadline"] = d }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, _) = try await URLSession.shared.data(for: req)
            // Refresh full list
            await fetch()
        } catch {
            lastError = "Add failed: \(error.localizedDescription)"
        }
    }

    func toggleTask(_ task: NATaskItem) async {
        let newStatus = task.status == "done" ? "open" : "done"

        // Local update first (instant UI)
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx].status = newStatus
        }

        // If local task, sync to server
        if task.isLocal {
            guard let url = URL(string: serverURL) else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = ["action": "update", "task_id": task.id, "status": newStatus]
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            do {
                let (data, _) = try await URLSession.shared.data(for: req)
                if let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   result["ok"] as? Bool == false {
                    // Server failed, revert
                    if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                        tasks[idx].status = task.status
                    }
                }
            } catch {
                if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                    tasks[idx].status = task.status
                }
            }
        }
        // For rollup tasks: just local state, no server sync
    }

    func deleteTask(_ task: NATaskItem) async {
        // Local removal first
        tasks.removeAll { $0.id == task.id }

        if task.isLocal {
            guard let url = URL(string: serverURL) else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = ["action": "delete", "task_id": task.id]
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            do {
                let (_, _) = try await URLSession.shared.data(for: req)
            } catch {
                lastError = "Delete failed: \(error.localizedDescription)"
            }
        }
    }
}