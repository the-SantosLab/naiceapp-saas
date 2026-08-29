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
    var isLocal: Bool

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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        project = try container.decodeIfPresent(String.self, forKey: .project)
        priority = try container.decodeIfPresent(String.self, forKey: .priority) ?? "medium"
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "open"
        deadline = try container.decodeIfPresent(String.self, forKey: .deadline)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        created = try container.decodeIfPresent(Int.self, forKey: .created)
        isLocal = try container.decodeIfPresent(Bool.self, forKey: .isLocal) ?? false
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
    private let completedKey = "naice_completed_tasks"
    private var completedIds: Set<String> = []

    private init() {
        loadCompletedState()
    }

    private func loadCompletedState() {
        if let data = UserDefaults.standard.data(forKey: completedKey),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            completedIds = ids
        }
    }

    private func saveCompletedState() {
        if let data = try? JSONEncoder().encode(completedIds) {
            UserDefaults.standard.set(data, forKey: completedKey)
        }
    }

    func fetch() async {
        isLoading = true
        defer { isLoading = false }
        loadCompletedState()

        await NARollupService.shared.fetch()
        var merged: [NATaskItem] = []

        // 1. Load rollup tasks
        if let rollupTasks = NARollupService.shared.tasks?.tasks {
            for t in rollupTasks {
                var item = NATaskItem(from: t)
                if completedIds.contains(t.id) {
                    item.status = "done"
                }
                merged.append(item)
            }
        }

        // 2. Load server tasks
        guard let url = URL(string: serverURL) else { print("[Tasks] No URL"); return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let raw = String(data: data, encoding: .utf8) ?? ""
            print("[Tasks] Server response: \(raw.prefix(200))")
            let serverTasks = try JSONDecoder().decode([NATaskItem].self, from: data)
            print("[Tasks] Decoded \(serverTasks.count) server tasks")
            let rollupIds = Set(merged.map { $0.id })
            for t in serverTasks where !rollupIds.contains(t.id) {
                var item = t
                item.isLocal = true
                if completedIds.contains(item.id) {
                    item.status = "done"
                }
                merged.append(item)
            }
        } catch {
            print("[Tasks] Fetch error: \(error)")
            lastError = "Server: \(error.localizedDescription)"
        }

        // Sort
        merged.sort { a, b in
            if a.status != b.status { return a.status == "open" && b.status != "open" }
            let pOrder = ["high": 0, "medium": 1, "low": 2]
            return (pOrder[a.priority] ?? 2) < (pOrder[b.priority] ?? 2)
        }

        print("[Tasks] Final count: \(merged.count)")
        tasks = merged
    }

    func addTask(title: String, project: String = "nAIce", priority: String = "medium", deadline: String? = nil) async {
        print("[Tasks] Adding task: \(title)")

        // Sync to server first
        guard let url = URL(string: serverURL) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["action": "add", "title": title, "project": project, "priority": priority]
        if let d = deadline { body["deadline"] = d }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            if let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               result["ok"] as? Bool == true {
                print("[Tasks] Server sync OK, refreshing...")
                // Refresh from server to get the exact state
                await fetch()
                return
            }
        } catch {
            print("[Tasks] Sync failed: \(error)")
            lastError = "Sync failed: \(error.localizedDescription)"
        }

        // Fallback: add locally if server sync fails
        let task = NATaskItem(title: title, project: project, priority: priority, deadline: deadline)
        tasks.insert(task, at: 0)
    }

    func toggleTask(_ task: NATaskItem) async {
        let newStatus = task.status == "done" ? "open" : "done"

        // Update local state
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx].status = newStatus
        }

        // Persist to UserDefaults (survives refresh)
        if newStatus == "done" {
            completedIds.insert(task.id)
        } else {
            completedIds.remove(task.id)
        }
        saveCompletedState()

        // Sync to server if local task
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
                    if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                        tasks[idx].status = task.status
                    }
                    completedIds.remove(task.id)
                    saveCompletedState()
                }
            } catch {
                // Keep local state
            }
        }
    }

    func deleteTask(_ task: NATaskItem) async {
        tasks.removeAll { $0.id == task.id }
        completedIds.remove(task.id)
        saveCompletedState()

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