import Foundation
import AppIntents

// MARK: - nAIce Intent Router (bridges intents → app navigation)
@MainActor
final class NAIntentRouter: ObservableObject {
    static let shared = NAIntentRouter()
    @Published var pendingTab: String? = nil
    @Published var pendingNewChat = false
    private init() {}
}

// MARK: - UserDefaults helpers for intent passthrough
extension UserDefaults {
    var naice_sharedNotes: [String] {
        get { stringArray(forKey: "naice_shared_notes") ?? [] }
        set { set(newValue, forKey: "naice_shared_notes") }
    }
    var naice_lastMood: Int {
        get { integer(forKey: "naice_last_mood") }
        set { set(newValue, forKey: "naice_last_mood") }
    }
}

// MARK: - Recovery Intent
struct RecoveryIntent: AppIntent {
    static var title: LocalizedStringResource = "Recovery abfragen"
    static var description = LocalizedStringResource("Zeigt deine aktuelle WHOOP Recovery")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let url = URL(string: "https://health.santoslab.de/api/naice/whoop")!
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .result(value: "Konnte WHOOP nicht abrufen")
        }
        let rec = json["recovery_score"] as? Int ?? 0
        let hrv = json["hrv"] as? Double ?? 0
        let rhr = json["resting_heart_rate"] as? Int ?? 0
        let strain = json["strain"] as? Double ?? 0
        let connected = json["connected"] as? Bool ?? false
        if !connected { return .result(value: "WHOOP nicht verbunden") }
        return .result(value: "Recovery \(rec)%, HRV \(Int(hrv)), RHR \(rhr), Strain \(String(format: "%.1f", strain))")
    }
}

// MARK: - Journal Intent
struct JournalIntent: AppIntent {
    static var title: LocalizedStringResource = "Journal Eintrag"
    static var description = LocalizedStringResource("Öffnet das Journal für einen neuen Eintrag")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NAIntentRouter.shared.pendingTab = "life"
        return .result()
    }
}

// MARK: - Briefing Intent
struct BriefingIntent: AppIntent {
    static var title: LocalizedStringResource = "Tagesbriefing"
    static var description = LocalizedStringResource("Zeigt dein heutiges Briefing mit WHOOP, Aufgaben und Business")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let url = URL(string: "https://health.santoslab.de/api/rollup")!
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .result(value: "Konnte Briefing nicht abrufen")
        }
        let whoop = json["whoop"] as? [String: Any] ?? [:]
        let recovery = whoop["recovery"] as? [String: Any] ?? [:]
        let cycle = whoop["cycle"] as? [String: Any] ?? [:]
        let business = json["business"] as? [String: Any] ?? [:]
        let tasks = json["tasks"] as? [String: Any] ?? [:]

        let rec = recovery["score"] as? Int ?? 0
        let hrv = recovery["hrv"] as? Int ?? 0
        let strain = cycle["strain"] as? Double ?? 0
        let naice = (business["naice"] as? [String: Any])?["total"] as? Int ?? 0
        let foodloop = (business["foodloop"] as? [String: Any])?["total"] as? Int ?? 0
        let activeTasks = tasks["active"] as? Int ?? 0
        let deals = (json["deals"] as? [String: Any])?["active_deals"] as? Int ?? 0

        var parts: [String] = ["📊 Tagesbriefing"]
        parts.append("🫀 Recovery \(rec)% | HRV \(hrv) | Strain \(String(format: "%.1f", strain))")
        parts.append("💼 nAIce \(naice) Leads | foodloop \(foodloop) Restaurants")
        if activeTasks > 0 { parts.append("✅ \(activeTasks) Aufgaben offen") }
        if deals > 0 { parts.append("💰 \(deals) aktive Deals") }
        return .result(value: parts.joined(separator: "\n"))
    }
}

// MARK: - Business Status Intent
struct BusinessIntent: AppIntent {
    static var title: LocalizedStringResource = "Business Status"
    static var description = LocalizedStringResource("Zeigt deine aktuelle Business-Pipeline")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let url = URL(string: "https://health.santoslab.de/api/rollup")!
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .result(value: "Konnte Daten nicht abrufen")
        }
        let business = json["business"] as? [String: Any] ?? [:]
        let deals = json["deals"] as? [String: Any] ?? [:]
        let naice = (business["naice"] as? [String: Any]) ?? [:]
        let foodloop = (business["foodloop"] as? [String: Any]) ?? [:]
        let schaffer = (business["schaffer"] as? [String: Any]) ?? [:]

        return .result(value: """
📈 Business Status
🍽 foodloop: \(foodloop["total"] ?? 0) Restaurants
🤖 nAIce: \(naice["total"] ?? 0) Leads (\(naice["pitched_today"] ?? 0) today)
🛒 Schaffer-Wine: \(schaffer["pageviews_today"] ?? 0) Views, \(schaffer["orders"] ?? 0) Orders
💰 Deals: \((deals["active_deals"] as? Int ?? 0)) aktiv, \((deals["total_value_eur"] as? Int ?? 0))€ Wert
""")
    }
}

// MARK: - Open Home Intent
struct OpenHomeIntent: AppIntent {
    static var title: LocalizedStringResource = "nAIce Home"
    static var description = LocalizedStringResource("Öffnet den nAIce Home-Bildschirm")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NAIntentRouter.shared.pendingTab = "home"
        return .result()
    }
}

// MARK: - Open Tasks Intent
struct OpenTasksIntent: AppIntent {
    static var title: LocalizedStringResource = "nAIce Aufgaben"
    static var description = LocalizedStringResource("Öffnet die nAIce Aufgaben-Übersicht")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NAIntentRouter.shared.pendingTab = "tasks"
        return .result()
    }
}

// MARK: - New Chat Intent (nAIce native)
struct NAiceNewChatIntent: AppIntent {
    static var title: LocalizedStringResource = "New Chat"
    static var description = IntentDescription("Öffnet nAIce in einem neuen Chat mit Amelia.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NAIntentRouter.shared.pendingTab = "agent"
        NAIntentRouter.shared.pendingNewChat = true
        return .result()
    }
}

// MARK: - nAIce Shortcuts Provider
struct NAiceShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NAiceNewChatIntent(),
            phrases: [
                "New chat in \(.applicationName)",
                "New \(.applicationName) chat",
                "Start a new chat in \(.applicationName)"
            ],
            shortTitle: "New Chat",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: RecoveryIntent(),
            phrases: [
                "What is my recovery in \(.applicationName)",
                "\(.applicationName) recovery",
                "Show my WHOOP recovery"
            ],
            shortTitle: "Recovery",
            systemImageName: "heart.fill"
        )
        AppShortcut(
            intent: BriefingIntent(),
            phrases: [
                "What is my briefing in \(.applicationName)",
                "\(.applicationName) briefing",
                "Show my daily briefing"
            ],
            shortTitle: "Daily Briefing",
            systemImageName: "sun.max.fill"
        )
        AppShortcut(
            intent: BusinessIntent(),
            phrases: [
                "Business status in \(.applicationName)",
                "\(.applicationName) business",
                "Show my business pipeline"
            ],
            shortTitle: "Business",
            systemImageName: "chart.bar.fill"
        )
    }
}