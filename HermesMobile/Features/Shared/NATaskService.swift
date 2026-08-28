import Foundation
import SwiftUI

// MARK: - Task Item Model (mutable, for local + server tasks)
struct NATaskItem: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var project: String?
    var priority: String  // "high", "medium", "low"
    var status: String    // "open", "done", "in_progress"
    var deadline: String?
    var source: String?
    var created: Int?
    var isLocal: Bool = false  // true = user-created, false = from rollup

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

    var statusDot: Color {
        switch status.lowercased() {
        case "open": return .ncAmber
        case "in_progress": return .ncCyan
        case "done": return .ncNeonGreen
        default: return .gray
        }
    }

    init(id: String = UUID().uuidString.prefix(8).description,
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

    // Convert from rollup NATask
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

    // MARK: - Fetch
    func fetch() async {
        isLoading = true
        defer { isLoading = false }

        // 1. Load from rollup
        await NARollupService.shared.fetch()
        var merged: [NATaskItem] = []

        // Add rollup tasks (not completed)
        if let rollupTasks = NARollupService.shared.tasks?.tasks {
            for t in rollupTasks {
                let item = NATaskItem(from: t)
                if item.status != "done" {
                    merged.append(item)
                }
            }
        }

        // 2. Load local/server tasks
        guard let url = URL(string: serverURL) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let serverTasks = try JSONDecoder().decode([NATaskItem].self, from: data)
            // Merge: rollup tasks first, then server tasks (filter out duplicates by id)
            let rollupIds = Set(merged.map { $0.id })
            for t in serverTasks where !rollupIds.contains(t.id) {
                var item = t
                item.isLocal = true
                merged.append(item)
            }
        } catch {
            lastError = "Server: \(error.localizedDescription)"
        }

        // Sort: open first, then by priority
        merged.sort { a, b in
            if a.status != b.status { return a.status == "open" }
            let pOrder = ["high": 0, "medium": 1, "low": 2]
            return (pOrder[a.priority] ?? 2) < (pOrder[b.priority] ?? 2)
        }

        tasks = merged
    }

    // MARK: - Add Task
    func addTask(title: String, project: String = "nAIce", priority: String = "medium", deadline: String? = nil) async {
        guard let url = URL(string: serverURL) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["action": "add", "title": title, "project": project, "priority": priority]
        if let d = deadline { body["deadline"] = d }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            if let result = try? JSONDecoder().decode([String: AnyCodable].self, from: data),
               result["ok"]?.value as? Bool == true,
               let taskDict = result["task"]?.value as? [String: Any] {
                // Try to decode the task from the response
                if let taskData = try? JSONSerialization.data(withJSONObject: taskDict),
                   let task = try? JSONDecoder().decode(NATaskItem.self, from: taskData) {
                    var t = task
                    t.isLocal = true
                    tasks.insert(t, at: 0)
                }
            }
            // Refresh
            await fetch()
        } catch {
            lastError = "Add failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Update Task (toggle complete, change priority, etc.)
    func updateTask(_ task: NATaskItem, status: String? = nil, priority: String? = nil) async {
        guard let url = URL(string: serverURL) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["action": "update", "task_id": task.id]
        if let s = status { body["status"] = s }
        if let p = priority { body["priority"] = p }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, _) = try await URLSession.shared.data(for: req)
            // Update locally
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                if let s = status { tasks[idx].status = s }
                if let p = priority { tasks[idx].priority = p }
            }
        } catch {
            lastError = "Update failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Delete Task
    func deleteTask(_ task: NATaskItem) async {
        guard let url = URL(string: serverURL) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["action": "delete", "task_id": task.id]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, _) = try await URLSession.shared.data(for: req)
            tasks.removeAll { $0.id == task.id }
        } catch {
            lastError = "Delete failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - AnyCodable helper for flexible JSON decoding
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) { value = intVal }
        else if let doubleVal = try? container.decode(Double.self) { value = doubleVal }
        else if let boolVal = try? container.decode(Bool.self) { value = boolVal }
        else if let stringVal = try? container.decode(String.self) { value = stringVal }
        else if let arrayVal = try? container.decode([AnyCodable].self) { value = arrayVal.map { $0.value } }
        else if let dictVal = try? container.decode([String: AnyCodable].self) { value = dictVal.mapValues { $0.value } }
        else { value = "" }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intVal = value as? Int { try container.encode(intVal) }
        else if let doubleVal = value as? Double { try container.encode(doubleVal) }
        else if let boolVal = value as? Bool { try container.encode(boolVal) }
        else if let stringVal = value as? String { try container.encode(stringVal) }
        else if let arrayVal = value as? [Any] { try container.encode(arrayVal.map { AnyCodable($0) }) }
        else if let dictVal = value as? [String: Any] { try container.encode(dictVal.mapValues { AnyCodable($0) }) }
    }
}