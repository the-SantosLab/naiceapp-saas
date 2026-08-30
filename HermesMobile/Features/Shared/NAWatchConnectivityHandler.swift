import Foundation
import WatchConnectivity

// MARK: - iOS-side Watch Connectivity Handler
class NAWatchConnectivityHandler: NSObject, WCSessionDelegate {
    static let shared = NAWatchConnectivityHandler()

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("[WatchHandler] Activated: \(activationState.rawValue)")
        if activationState == .activated {
            pushDataToWatch()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleWatchMessage(message, replyHandler: replyHandler)
    }

    private func handleWatchMessage(_ message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        let action = message["action"] as? String ?? ""

        switch action {
        case "sync":
            Task { @MainActor in
                let data = await buildSyncData()
                replyHandler(data)
            }
        case "mood":
            let emoji = message["emoji"] as? String ?? ""
            let note = message["note"] as? String ?? ""
            print("[WatchHandler] Mood: \(emoji) - \(note)")
            replyHandler(["ok": true])
        case "habit_toggle":
            replyHandler(["ok": true])
        case "task_toggle":
            replyHandler(["ok": true])
        case "chat":
            let text = message["message"] as? String ?? ""
            Task {
                let response = await chatWithAgent(text)
                replyHandler(["response": response ?? "Konnte keine Antwort generieren."])
            }
        default:
            replyHandler(["ok": false, "error": "Unknown action"])
        }
    }

    @MainActor
    private func buildSyncData() async -> [String: Any] {
        var data: [String: Any] = [:]
        let rollup = NARollupService.shared.rollup

        // WHOOP
        if let r = rollup?.whoop?.recovery {
            let sleepHours = rollup?.whoop?.sleep?.net_hours ?? 0
            let strain = rollup?.whoop?.cycle?.strain ?? 0
            data["whoop"] = [
                "recoveryScore": r.score,
                "hrv": r.hrv,
                "rhr": r.rhr,
                "sleepHours": sleepHours,
                "strain": strain,
                "spo2": r.spo2 ?? 0,
                "lastSync": r.synced_at ?? ""
            ]
        }

        // Habits
        let habits = NAHabitsService.shared.habits
        let todayLogs = NAHabitsService.shared.logs
        let today = NAHabitsService.shared.todayDate
        let loggedIds = Set(todayLogs.filter { $0.date == today }.map { $0.habit_id })
        data["habits"] = habits.map { h in
            ["id": h.id, "name": h.name, "icon": h.icon,
             "color": h.color, "done": loggedIds.contains(h.id)]
        }

        // Tasks
        let tasks = NATaskService.shared.tasks
        data["tasks"] = tasks.prefix(20).map { t in
            ["id": t.id, "title": t.title, "project": t.project ?? "",
             "priority": t.priority, "deadline": t.deadline ?? "",
             "done": t.status == "done"]
        }

        // Briefing
        let rec = rollup?.whoop?.recovery?.score ?? 0
        let label = rec >= 67 ? "Gut" : rec >= 34 ? "Mittel" : "Niedrig"
        let hrv = rollup?.whoop?.recovery?.hrv ?? 0
        let rhr = rollup?.whoop?.recovery?.rhr ?? 0
        let sleep = rollup?.whoop?.sleep?.net_hours ?? 0
        let openTasks = tasks.filter { $0.status != "done" }.count
        let undoneHabits = NAHabitsService.shared.todayUndone.count
        let activeDeals = rollup?.deals?.active_deals ?? 0

        data["briefing"] = [
            "greeting": "nAIce",
            "recoveryScore": rec,
            "recoveryLabel": label,
            "hrv": hrv,
            "rhr": rhr,
            "sleepHours": sleep,
            "tasksOpen": openTasks,
            "habitsUndone": undoneHabits,
            "dealsActive": activeDeals,
            "suggestion": "Wie war deine Stimmung heute?"
        ]

        return data
    }

    private func chatWithAgent(_ text: String) async -> String? {
        guard let url = URL(string: "https://health.santoslab.de/api/naice/chat") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["message": text]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 30
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            if let result = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let response = result["response"] as? String {
                return response
            }
        } catch {
            print("[WatchHandler] Chat error: \(error)")
        }
        return nil
    }

    func pushDataToWatch() {
        Task { @MainActor in
            let data = await buildSyncData()
            if !data.isEmpty {
                try? WCSession.default.updateApplicationContext(data)
            }
        }
    }
}