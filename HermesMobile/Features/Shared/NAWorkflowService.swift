import Foundation

// MARK: - Workflow Models
struct NAWorkflow: Codable, Identifiable {
    var id = UUID().uuidString
    let name: String
    let trigger: NAWorkflowTrigger
    let action: NAWorkflowAction
    var isEnabled: Bool = true
    var lastRun: Date?
    var runCount: Int = 0
}

enum NAWorkflowTrigger: Codable {
    case time(hour: Int, minute: Int)
    case whatsappUnread(threshold: Int)
    case lowRecovery(threshold: Int)
    case highSteps(threshold: Int)
    case calendarEvent
    case manual

    var description: String {
        switch self {
        case .time(let h, let m): return "Taglich um \(String(format: "%02d", h)):\(String(format: "%02d", m))"
        case .whatsappUnread(let t): return "Wenn >\(t) WhatsApp unbeantwortet"
        case .lowRecovery(let t): return "Wenn Recovery <\(t)%"
        case .highSteps(let t): return "Wenn Schritte >\(t)"
        case .calendarEvent: return "Vor einem Kalendertermin"
        case .manual: return "Manuell"
        }
    }
}

enum NAWorkflowAction: Codable {
    case sendPush(text: String)
    case createJournal(prompt: String)
    case logExpense(category: String, note: String)
    case suggestBreak
    case remindContact(name: String)

    var description: String {
        switch self {
        case .sendPush(let t): return "Push: \(t.prefix(40))"
        case .createJournal(let p): return "Journal: \(p.prefix(40))"
        case .logExpense(let c, _): return "Ausgabe loggen: \(c)"
        case .suggestBreak: return "Pause vorschlagen"
        case .remindContact(let n): return "Erinnere: \(n)"
        }
    }
}

// MARK: - Workflow Service
@MainActor
class NAWorkflowService: ObservableObject {
    static let shared = NAWorkflowService()

    @Published var workflows: [NAWorkflow] = []
    @Published var lastTriggeredLog: [String] = []

    private let storageKey = "naice_workflows"

    init() {
        load()
        if workflows.isEmpty {
            // Default workflows
            workflows = [
                NAWorkflow(name: "Abend-Reflexion", trigger: .time(hour: 21, minute: 0), action: .createJournal(prompt: "Wie war dein Tag? Was war gut?")),
                NAWorkflow(name: "WhatsApp-Check", trigger: .whatsappUnread(threshold: 3), action: .sendPush(text: "WhatsApp-Rückstand aufräumen?")),
                NAWorkflow(name: "Bewegungs-Erinnerung", trigger: .highSteps(threshold: 5000), action: .suggestBreak),
            ]
            save()
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([NAWorkflow].self, from: data) else { return }
        workflows = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(workflows) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    func addWorkflow(_ workflow: NAWorkflow) {
        workflows.append(workflow)
        save()
    }

    func toggleWorkflow(_ id: String) {
        if let idx = workflows.firstIndex(where: { $0.id == id }) {
            workflows[idx].isEnabled.toggle()
            save()
        }
    }

    func deleteWorkflow(_ id: String) {
        workflows.removeAll { $0.id == id }
        save()
    }

    func triggerManual(_ id: String) {
        guard let idx = workflows.firstIndex(where: { $0.id == id }) else { return }
        workflows[idx].runCount += 1
        workflows[idx].lastRun = Date()
        lastTriggeredLog.insert("\(workflows[idx].name) manuell getriggert", at: 0)
        save()
    }

    func checkTriggers() async {
        for i in workflows.indices where workflows[i].isEnabled {
            let w = workflows[i]
            var shouldTrigger = false

            switch w.trigger {
            case .time(let h, let m):
                let now = Date()
                let cal = Calendar.current
                if cal.component(.hour, from: now) == h && cal.component(.minute, from: now) == m {
                    shouldTrigger = true
                }
            case .whatsappUnread(let t):
                if WhatsAppViewModel.shared.totalUnread > t {
                    shouldTrigger = true
                }
            case .lowRecovery(let t):
                if let rec = NARollupService.shared.whoop?.recovery?.score, rec < t {
                    shouldTrigger = true
                }
            case .highSteps(let t):
                if HealthManager.shared.steps > t {
                    shouldTrigger = true
                }
            case .calendarEvent:
                if !CalendarManager.shared.upcomingEvents.isEmpty {
                    shouldTrigger = true
                }
            case .manual:
                break
            }

            if shouldTrigger {
                workflows[i].runCount += 1
                workflows[i].lastRun = Date()
                lastTriggeredLog.insert("\(w.name) getriggert", at: 0)
            }
        }
        save()
    }
}