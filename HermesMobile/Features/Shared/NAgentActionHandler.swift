import Foundation
import SwiftUI
import Observation

// MARK: - Agent Action Types
enum NAgentActionType: String, Codable {
    case logMood, logExpense, createNote, createTask, openCalendar, openURL
}

struct NAgentAction: Identifiable, Codable {
    var id = UUID().uuidString
    let type: NAgentActionType
    let title: String
    let params: [String: String]
    let autoExecute: Bool
}

// MARK: - Agent Action Handler
@MainActor
@Observable
final class NAgentActionHandler {
    static let shared = NAgentActionHandler()

    var pendingActions: [NAgentAction] = []
    var lastActionResult: String?
    var showConfirmation = false
    var currentAction: NAgentAction?

    func parseActions(from text: String) -> [NAgentAction] {
        var actions: [NAgentAction] = []
        let pattern = /\[ACTION:(\w+)((?:,\s*\w+:[^\]]+)*)\]/
        for match in text.matches(of: pattern) {
            let typeStr = String(match.1)
            guard let type = NAgentActionType(rawValue: typeStr) else { continue }
            let paramsStr = String(match.2)
            var params: [String: String] = [:]
            for param in paramsStr.split(separator: ",") {
                let parts = param.trimmingCharacters(in: .whitespaces).split(separator: ":", maxSplits: 1)
                if parts.count == 2 { params[String(parts[0])] = String(parts[1]) }
            }
            let title = actionTitle(type, params)
            actions.append(NAgentAction(type: type, title: title, params: params, autoExecute: type == .logMood))
        }
        return actions
    }

    func execute(_ action: NAgentAction) async -> String {
        switch action.type {
        case .logMood:
            let mood = action.params["mood"] ?? "good"
            UserDefaults.standard.set(mood, forKey: "naice_last_mood")
            return "Stimmung geloggt: \(mood)"
        case .logExpense:
            if let amount = Double(action.params["amount"] ?? "") {
                let cat = action.params["category"] ?? "sonstiges"
                NAFinanceService.shared.addExpense(amount: amount, category: cat, note: action.params["note"] ?? "")
                return "Ausgabe: \(Int(amount))€ (\(cat))"
            }
            return "Betrag ungueltig"
        case .createNote:
            return "Notiz: \(action.params["title"] ?? "")"
        case .createTask:
            return "Aufgabe: \(action.params["title"] ?? "")"
        case .openCalendar:
            return "Kalender"
        case .openURL:
            if let urlStr = action.params["url"], let url = URL(string: urlStr) {
                await UIApplication.shared.open(url)
                return "Geoffnet: \(urlStr)"
            }
            return "Keine URL"
        }
    }

    func process(_ text: String) {
        let actions = parseActions(from: text)
        guard !actions.isEmpty else { return }
        pendingActions = actions
        Task {
            for action in actions where action.autoExecute {
                let result = await execute(action)
                lastActionResult = result
            }
            let needsConfirmation = actions.filter { !$0.autoExecute }
            if let first = needsConfirmation.first {
                currentAction = first
                showConfirmation = true
            }
        }
    }

    func confirmAction() async {
        guard let action = currentAction else { return }
        let result = await execute(action)
        lastActionResult = result
        currentAction = nil
        showConfirmation = false
        pendingActions.removeAll { $0.id == action.id }
    }

    func dismissAction() {
        currentAction = nil
        showConfirmation = false
    }

    private func actionTitle(_ type: NAgentActionType, _ params: [String: String]) -> String {
        switch type {
        case .logMood: return "Stimmung: \(params["mood"] ?? "?")"
        case .logExpense: return "\(params["amount"] ?? "?")€ (\(params["category"] ?? "?"))"
        case .createNote: return "Notiz: \(params["title"] ?? "?")"
        case .createTask: return "Aufgabe: \(params["title"] ?? "?")"
        case .openCalendar: return "Kalender"
        case .openURL: return "Link: \(params["url"] ?? "?")"
        }
    }
}

// MARK: - Action Confirmation View
struct NAgentActionConfirmationView: View {
    private var handler: NAgentActionHandler { NAgentActionHandler.shared }

    var body: some View {
        VStack(spacing: 8) {
            Text("Aktion vom Agent").font(.caption.weight(.semibold)).foregroundColor(.ncSage)
            Text(handler.currentAction?.title ?? "").font(.subheadline.weight(.medium)).foregroundColor(.ncDark)
            HStack(spacing: 12) {
                Button("Ausfuhren") { Task { await handler.confirmAction() } }
                    .font(.subheadline.weight(.semibold)).foregroundColor(.white)
                    .padding(.horizontal, 24).padding(.vertical, 10)
                    .background(Color.ncGreen, in: RoundedRectangle(cornerRadius: 10))
                Button("Ablehnen") { handler.dismissAction() }
                    .font(.subheadline).foregroundColor(.ncMuted)
            }
        }
        .padding(16)
        .background(Color.ncPaper)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .padding(.horizontal, 24)
    }
}