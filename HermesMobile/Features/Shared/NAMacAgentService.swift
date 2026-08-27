import Foundation
import SwiftUI

// MARK: - Mac Agent Service (Persistent, überlebt View-Wechsel)
@MainActor
class NAMacAgentService: ObservableObject {
    static let shared = NAMacAgentService()

    let serverURL = "https://health.santoslab.de/api/mac-agent"

    @Published var command = ""
    @Published var output = ""
    @Published var isRunning = false
    @Published var resultType: ResultType = .idle
    @Published var macConnected = false
    @Published var recentCommands: [String] = []
    @Published var actionMode: ActionMode = .shell
    @Published var currentCmdId: String? = nil
    @Published var statusText = ""

    enum ResultType { case idle, success, error }
    enum ActionMode: String, CaseIterable {
        case shell = "Terminal"
        case readFile = "Datei lesen"
        case openApp = "App offnen"
        case screenshot = "Screenshot"
        case findFiles = "Dateien suchen"
        case listDir = "Ordner"
        var icon: String {
            switch self {
            case .shell: return "terminal"
            case .readFile: return "doc.text"
            case .openApp: return "app"
            case .screenshot: return "camera.viewfinder"
            case .findFiles: return "magnifyingglass"
            case .listDir: return "folder"
            }
        }
    }

    private var pollTimer: Timer?

    func checkConnected() {
        guard let url = URL(string: "\(serverURL)/health") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            DispatchQueue.main.async { self?.macConnected = data != nil }
        }.resume()
    }

    func runCommand() {
        guard !command.isEmpty else { return }
        isRunning = true
        output = ""
        resultType = .idle
        statusText = "Sende an Mac..."

        if !recentCommands.contains(command) {
            recentCommands.insert(command, at: 0)
            if recentCommands.count > 10 { recentCommands.removeLast() }
        }

        var payload: [String: Any] = ["command": command]
        switch actionMode {
        case .shell:
            payload["action"] = "shell"
        case .readFile:
            payload["action"] = "read_file"
            payload["params"] = ["path": command]
        case .openApp:
            payload["action"] = "open_app"
            payload["params"] = ["name": command]
        case .screenshot:
            payload["action"] = "screenshot"
            payload["params"] = [:]
        case .findFiles:
            payload["action"] = "find_files"
            payload["params"] = ["pattern": command]
        case .listDir:
            payload["action"] = "list_directory"
            payload["params"] = ["path": command]
        }

        guard let url = URL(string: "\(serverURL)/queue") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: req) { [weak self] data, _, error in
            guard let self = self else { return }
            guard let data = data,
                  let submit = try? JSONDecoder().decode(QueueSubmitResponse.self, from: data),
                  let cmdId = submit.id else {
                DispatchQueue.main.async {
                    self.isRunning = false
                    self.output = error?.localizedDescription ?? "Server nicht erreichbar"
                    self.resultType = .error
                }
                return
            }
            self.currentCmdId = cmdId
            self.pollResult(cmdId: cmdId, attempts: 0)
        }.resume()
    }

    func pollResult(cmdId: String, attempts: Int) {
        let maxAttempts = 120
        guard let url = URL(string: "\(serverURL)/result/\(cmdId)") else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            // Stop polling if user sent a new command
            if self.currentCmdId != cmdId { return }

            URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
                guard let self = self else { return }
                guard let data = data,
                      let poll = try? JSONDecoder().decode(QueuePollResponse.self, from: data) else {
                    if attempts < maxAttempts && self.currentCmdId == cmdId {
                        if attempts % 5 == 0 {
                            DispatchQueue.main.async { self.statusText = "Warte auf Mac... (\(attempts * 2)s)" }
                        }
                        self.pollResult(cmdId: cmdId, attempts: attempts + 1)
                    } else {
                        DispatchQueue.main.async {
                            self.isRunning = false
                            self.output = "Timeout - Mac Client nicht erreichbar?"
                            self.resultType = .error
                        }
                    }
                    return
                }

                DispatchQueue.main.async {
                    if poll.status == "completed" || poll.status == "failed" || poll.success != nil {
                        self.isRunning = false
                        self.statusText = "Fertig"
                        if let r = poll.result {
                            let out = r.stdout ?? ""
                            let err = r.stderr ?? ""
                            self.output = out + (err.isEmpty ? "" : "\nFehler:\n" + err)
                        } else if let s = poll.stdout, !s.isEmpty {
                            let err = poll.stderr ?? ""
                            self.output = s + (err.isEmpty ? "" : "\nFehler:\n" + err)
                        } else {
                            self.output = "Befehl ausgefuhrt (keine Ausgabe)"
                        }
                        self.resultType = (poll.success ?? (poll.returncode == 0)) ? .success : .error
                        self.macConnected = true
                        self.currentCmdId = nil
                    } else if poll.status == "running" || poll.status == "pending" {
                        self.statusText = poll.status == "running" ? "Befehl lauft auf Mac..." : "Befehl wartet..."
                        self.pollResult(cmdId: cmdId, attempts: attempts + 1)
                    } else {
                        self.pollResult(cmdId: cmdId, attempts: attempts + 1)
                    }
                }
            }.resume()
        }
    }
}

// MARK: - Decodables
struct QueueSubmitResponse: Decodable {
    let ok: Bool?; let id: String?; let error: String?; let suggestions: [String]?
}

struct QueuePollResponse: Decodable {
    let id: String?; let command: String?; let status: String?
    let result: QueueResult?; let stdout: String?; let stderr: String?
    let returncode: Int?; let success: Bool?; let error: String?
    let action: String?; let has_image: Bool?
    struct QueueResult: Decodable { let stdout: String?; let stderr: String?; let returncode: Int? }
}