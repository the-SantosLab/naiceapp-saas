import SwiftUI
import WatchConnectivity

// MARK: - Data Models
struct WatchWhoopData: Codable {
    var recoveryScore: Int = 0
    var hrv: Double = 0
    var rhr: Int = 0
    var sleepHours: Double = 0
    var strain: Double = 0
    var spo2: Double = 0
    var lastSync: String = ""
}

struct WatchMoodEntry: Codable, Identifiable {
    var id = UUID().uuidString
    let emoji: String
    let note: String
    let timestamp: Date
}

struct WatchHabit: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: String
    var done: Bool = false
}

struct WatchTask: Codable, Identifiable {
    let id: String
    let title: String
    let project: String?
    let priority: String
    let deadline: String?
    var done: Bool = false
}

struct WatchBriefing: Codable {
    let greeting: String
    let recoveryScore: Int
    let recoveryLabel: String
    let hrv: Double
    let rhr: Int
    let sleepHours: Double
    let tasksOpen: Int
    let habitsUndone: Int
    let dealsActive: Int
    let suggestion: String
}

// MARK: - Data Store
@MainActor
class WatchDataStore: ObservableObject {
    static let shared = WatchDataStore()
    private init() {}

    @Published var whoop = WatchWhoopData()
    @Published var moods: [WatchMoodEntry] = []
    @Published var habits: [WatchHabit] = []
    @Published var tasks: [WatchTask] = []
    @Published var briefing: WatchBriefing?
    @Published var lastUpdated: Date?
    @Published var isConnected = false

    private let defaults = UserDefaults.standard

    func update(from dict: [String: Any]) {
        if let whoopData = dict["whoop"] as? [String: Any] {
            whoop = WatchWhoopData(
                recoveryScore: whoopData["recoveryScore"] as? Int ?? 0,
                hrv: whoopData["hrv"] as? Double ?? 0,
                rhr: whoopData["rhr"] as? Int ?? 0,
                sleepHours: whoopData["sleepHours"] as? Double ?? 0,
                strain: whoopData["strain"] as? Double ?? 0,
                spo2: whoopData["spo2"] as? Double ?? 0,
                lastSync: whoopData["lastSync"] as? String ?? ""
            )
        }
        if let habitsData = dict["habits"] as? [[String: Any]] {
            habits = habitsData.map { d in
                WatchHabit(id: d["id"] as? String ?? "", name: d["name"] as? String ?? "",
                          icon: d["icon"] as? String ?? "star", color: d["color"] as? String ?? "#00E5FF",
                          done: d["done"] as? Bool ?? false)
            }
        }
        if let tasksData = dict["tasks"] as? [[String: Any]] {
            tasks = tasksData.map { d in
                WatchTask(id: d["id"] as? String ?? "", title: d["title"] as? String ?? "",
                         project: d["project"] as? String, priority: d["priority"] as? String ?? "medium",
                         deadline: d["deadline"] as? String, done: d["done"] as? Bool ?? false)
            }
        }
        if let briefingData = dict["briefing"] as? [String: Any] {
            briefing = WatchBriefing(
                greeting: briefingData["greeting"] as? String ?? "",
                recoveryScore: briefingData["recoveryScore"] as? Int ?? 0,
                recoveryLabel: briefingData["recoveryLabel"] as? String ?? "",
                hrv: briefingData["hrv"] as? Double ?? 0,
                rhr: briefingData["rhr"] as? Int ?? 0,
                sleepHours: briefingData["sleepHours"] as? Double ?? 0,
                tasksOpen: briefingData["tasksOpen"] as? Int ?? 0,
                habitsUndone: briefingData["habitsUndone"] as? Int ?? 0,
                dealsActive: briefingData["dealsActive"] as? Int ?? 0,
                suggestion: briefingData["suggestion"] as? String ?? ""
            )
        }
        lastUpdated = Date()
        isConnected = true
    }

    func saveMood(_ emoji: String, note: String) {
        let entry = WatchMoodEntry(emoji: emoji, note: note, timestamp: Date())
        moods.insert(entry, at: 0)
        // Send to iPhone
        WatchConnectivityManager.shared.sendMood(emoji, note: note)
    }

    func toggleHabit(_ habit: WatchHabit) {
        if let idx = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[idx].done.toggle()
            WatchConnectivityManager.shared.toggleHabit(habit.id, done: habits[idx].done)
        }
    }

    func toggleTask(_ task: WatchTask) {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx].done.toggle()
            WatchConnectivityManager.shared.toggleTask(task.id, done: tasks[idx].done)
        }
    }
}

// MARK: - Watch Connectivity Manager
@MainActor
class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()
    @Published var reachable = false

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        reachable = session.isReachable
        if activationState == .activated {
            requestData()
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        reachable = session.isReachable
        if reachable { requestData() }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            WatchDataStore.shared.update(from: applicationContext)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            WatchDataStore.shared.update(from: message)
        }
    }

    func requestData() {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["request": "sync"], replyHandler: { response in
            Task { @MainActor in
                WatchDataStore.shared.update(from: response)
            }
        }, errorHandler: { error in
            print("[Watch] Request data error: \(error)")
            // Try context as fallback
            if let context = WCSession.default.applicationContext as? [String: Any] {
                Task { @MainActor in
                    WatchDataStore.shared.update(from: context)
                }
            }
        })
    }

    func sendMood(_ emoji: String, note: String) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage([
            "action": "mood",
            "emoji": emoji,
            "note": note,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ], replyHandler: nil, errorHandler: nil)
    }

    func toggleHabit(_ id: String, done: Bool) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage([
            "action": "habit_toggle",
            "habit_id": id,
            "done": done
        ], replyHandler: nil, errorHandler: nil)
    }

    func toggleTask(_ id: String, done: Bool) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage([
            "action": "task_toggle",
            "task_id": id,
            "done": done
        ], replyHandler: nil, errorHandler: nil)
    }

    func sendChatMessage(_ text: String) async -> String? {
        await withCheckedContinuation { continuation in
            guard WCSession.default.isReachable else {
                continuation.resume(returning: nil)
                return
            }
            WCSession.default.sendMessage([
                "action": "chat",
                "message": text
            ], replyHandler: { response in
                continuation.resume(returning: response["response"] as? String)
            }, errorHandler: { _ in
                continuation.resume(returning: nil)
            })
        }
    }
}