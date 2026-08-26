import SwiftUI

// MARK: - Amelia Context Provider
@MainActor
class AmeliaContextProvider: ObservableObject {
    static let shared = AmeliaContextProvider()

    @Published var currentTab: String = "home"
    @Published var currentView: String = ""
    @Published var currentEntity: String = ""
    @Published var currentEntityDetail: String = ""

    // Facts based on context - rotate through these
    private lazy var facts: [String: [String]] = [
        "home": [
            "Deine heutige Recovery beeinflusst deine Produktivität.",
            "Briefings geben dir Amelias Einschätzung zum Tag.",
            "Deine offenen Tasks warten auf dich.",
            "Amelia hat heute \(Int.random(in: 2...7)) Insights für dich.",
        ],
        "life": [
            "Der Radar-Chart zeigt 6 Dimensionen deines Lebens.",
            "Kreativität lebt von neuen Impulsen.",
            "Finanzen sind nur eine Säule – Balance ist der Schlüssel.",
            "Tägliche Reflexion stärkt deine Selbstwahrnehmung.",
        ],
        "tasks": [
            "Priorisiere High-Priority-Tasks zuerst.",
            "Deadline heute? Amelia kann dich erinnern.",
            "\(Int.random(in: 1...12)) Aufgaben warten auf Erledigung.",
            "Kleine Erfolge summieren sich zu großen.",
        ],
        "agent": [
            "Amelia lernt aus jedem Gespräch mit dir.",
            "Deine Sessions sind das Gedächtnis des Agents.",
            "Je mehr du mit Amelia sprichst, desto besser wird sie.",
            "Wissen wächst mit jeder Interaktion.",
        ],
        "more": [
            "Alle Integrationen sind vernetzt.",
            "Push-Benachrichtigungen halten dich auf dem Laufenden.",
            "Der Mac Agent erweitert deine Reichweite.",
            "Server-Status: health.santoslab.de ist online.",
        ],
        "default": [
            "Amelia ist dein persönlicher KI-Assistent.",
            "Frag mich alles – ich kenne deine Daten.",
            "Kontext ist der Schlüssel zu guten Antworten.",
            "Ich bin für dich da, rund um die Uhr.",
        ]
    ]

    @Published var currentFact: String = "Amelia ist bereit für dich."
    private var factTimer: Timer?
    private var factIndex: [String: Int] = [:]

    init() {
        startFactRotation()
    }

    func setContext(tab: String, view: String = "", entity: String = "", detail: String = "") {
        currentTab = tab
        currentView = view
        currentEntity = entity
        currentEntityDetail = detail
        // Reset to first fact for new context
        currentFact = nextFact(for: tab)
    }

    func nextFact(for tab: String? = nil) -> String {
        let key = tab ?? currentTab
        let pool = facts[key] ?? facts["default"]!
        let idx = factIndex[key] ?? 0
        factIndex[key] = (idx + 1) % pool.count
        return pool[idx]
    }

    func startFactRotation() {
        factTimer?.invalidate()
        factTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.currentFact = self.nextFact()
            }
        }
    }

    var slideUpContext: String {
        var parts: [String] = [currentTab]
        if !currentView.isEmpty { parts.append(currentView) }
        if !currentEntity.isEmpty { parts.append(currentEntity) }
        return parts.joined(separator: " > ")
    }
}