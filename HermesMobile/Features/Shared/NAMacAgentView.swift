import SwiftUI

// MARK: - Mac Agent Result
struct MacAgentResult: Decodable {
    let success: Bool
    let output: String
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        if let out = try? container.decode(String.self, forKey: .output) { output = out }
        else if let out = try? container.decode(String.self, forKey: .stdout) { output = out }
        else if let out = try? container.decode(String.self, forKey: .content) { output = out }
        else { output = "" }
    }
    enum CodingKeys: String, CodingKey { case success, output, stdout, content }
}

struct QueueSubmitResponse: Decodable {
    let ok: Bool?; let id: String?; let error: String?; let suggestions: [String]?
}

struct QueuePollResponse: Decodable {
    let id: String?; let command: String?; let status: String?
    let result: QueueResult?; let stdout: String?; let stderr: String?
    let returncode: Int?; let success: Bool?; let error: String?
    let action: String?; let has_image: Bool?
    var items: [DirectoryItem]?
    var results: [FindResult]?
    struct QueueResult: Decodable { let stdout: String?; let stderr: String?; let returncode: Int? }
    struct DirectoryItem: Decodable { let name: String; let type: String; let size: Int; let modified: String }
    struct FindResult: Decodable { let path: String; let name: String; let size: Int; let modified: String }
}

// MARK: - Mac Agent View
struct NAMacAgentView: View {
    @State private var command = ""
    @State private var output = ""
    @State private var isRunning = false
    @State private var recentCommands: [String] = []
    @State private var resultType: ResultType = .idle
    @State private var macConnected = false
    @State private var actionMode: ActionMode = .shell
    @State private var showActionPicker = false

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

    let serverURL = "https://health.santoslab.de/api/mac-agent"

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mac Agent")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                        Text(macConnected ? "Verbunden mit deinem Mac" : "Warte auf Mac Client...")
                            .font(.subheadline)
                            .foregroundColor(macConnected ? .ncNeonGreen : .gray)
                    }
                    Spacer()
                    Circle()
                        .fill(macConnected ? Color.ncNeonGreen : Color.ncAmber)
                        .frame(width: 8, height: 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Action Picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ActionMode.allCases, id: \.rawValue) { mode in
                            Button {
                                actionMode = mode
                                command = ""
                                output = ""
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: mode.icon).font(.system(size: 9))
                                    Text(mode.rawValue).font(.caption)
                                }
                                .foregroundColor(actionMode == mode ? .white : .gray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(actionMode == mode ? Color.ncCyan : Color(red: 0.03, green: 0.03, blue: 0.06), in: Capsule())
                                .overlay(Capsule().stroke(actionMode == mode ? Color.ncCyan : Color.white.opacity(0.08), lineWidth: 1))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Input area
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: actionMode.icon)
                            .font(.caption)
                            .foregroundColor(.ncCyan)
                        if actionMode == .shell {
                            TextField("Befehl eingeben...", text: $command)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white)
                                .onSubmit { runCommand() }
                        } else if actionMode == .readFile {
                            TextField("Dateipfad (z.B. ~/Desktop/note.txt)", text: $command)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white)
                                .onSubmit { runCommand() }
                        } else if actionMode == .openApp {
                            TextField("App-Name (z.B. Safari)", text: $command)
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .onSubmit { runCommand() }
                        } else if actionMode == .findFiles {
                            TextField("Muster (z.B. *.pdf, *.swift)", text: $command)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white)
                                .onSubmit { runCommand() }
                        } else if actionMode == .listDir {
                            TextField("Ordner (z.B. ~/Desktop)", text: $command)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white)
                                .onSubmit { runCommand() }
                        } else {
                            TextField("Befehl...", text: $command)
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .onSubmit { runCommand() }
                        }
                    }
                    .padding(12)
                    .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 0.5))

                    Button { runCommand() } label: {
                        HStack(spacing: 6) {
                            if isRunning { ProgressView().scaleEffect(0.6).tint(.white) }
                            Text(isRunning ? "Warte auf Mac..." : "An Mac senden")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(command.isEmpty || isRunning ? Color.gray.opacity(0.3) : Color.ncCyan, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(command.isEmpty || isRunning)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                // Quick Actions as buttons
                if actionMode == .shell {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Schnellbefehle").font(.caption.weight(.semibold)).foregroundColor(.gray).padding(.horizontal, 20)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            quickBtn("whoami", "terminal")
                            quickBtn("date", "calendar")
                            quickBtn("df -h", "externaldrive")
                            quickBtn("sw_vers", "apple.logo")
                            quickBtn("ls ~/Desktop/", "folder")
                            quickBtn("ps aux | head 10", "memorychip")
                        }
                        .padding(.horizontal, 16)
                    }
                } else if actionMode == .openApp {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        quickBtn("Safari", "safari")
                        quickBtn("Finder", "folder")
                        quickBtn("Terminal", "terminal")
                        quickBtn("Xcode", "hammer")
                        quickBtn("Calendar", "calendar")
                        quickBtn("Notes", "note.text")
                    }
                    .padding(.horizontal, 16)
                }

                // Output
                if !output.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "terminal")
                                .font(.caption)
                                .foregroundColor(resultType == .success ? .ncNeonGreen : .ncRose)
                            Text("Output von deinem Mac")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.gray)
                            Spacer()
                            Button { UIPasteboard.general.string = output } label: {
                                Image(systemName: "doc.on.doc").font(.caption).foregroundColor(.gray)
                            }.buttonStyle(.plain)
                        }
                        ScrollView([.horizontal, .vertical]) {
                            Text(output)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(resultType == .success ? .white.opacity(0.9) : .ncRose)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 300)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.01, green: 0.01, blue: 0.02))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(resultType == .success ? Color.ncNeonGreen.opacity(0.1) : Color.ncRose.opacity(0.1), lineWidth: 0.5)))
                    .padding(.horizontal, 16)
                }

                // Recent Commands
                if !recentCommands.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock").font(.caption).foregroundColor(.gray)
                            Text("Letzte Aktionen").font(.caption.weight(.semibold)).foregroundColor(.gray)
                        }
                        ForEach(recentCommands.prefix(5), id: \.self) { cmd in
                            Button {
                                command = cmd
                                runCommand()
                            } label: {
                                Text(cmd).font(.system(size: 11, design: .monospaced)).foregroundColor(.gray).lineLimit(1)
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                    .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { checkMacConnected() }
    }

    private func quickBtn(_ label: String, _ icon: String) -> some View {
        Button {
            command = label
            runCommand()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 8))
                Text(label).font(.system(size: 9, design: .monospaced)).lineLimit(1)
            }
            .foregroundColor(.ncCyan)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Color.ncCyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.ncCyan.opacity(0.15), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func checkMacConnected() {
        guard let url = URL(string: "\(serverURL)/health") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if data != nil { DispatchQueue.main.async { macConnected = true } }
        }.resume()
    }

    private func runCommand() {
        guard !command.isEmpty else { return }
        isRunning = true
        output = "Sende an Mac..."
        resultType = .idle
        if !recentCommands.contains(command) {
            recentCommands.insert(command, at: 0)
            if recentCommands.count > 10 { recentCommands.removeLast() }
        }

        // Build the payload
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

        URLSession.shared.dataTask(with: req) { data, _, error in
            guard let data = data, let submit = try? JSONDecoder().decode(QueueSubmitResponse.self, from: data), let cmdId = submit.id else {
                DispatchQueue.main.async { isRunning = false; output = error?.localizedDescription ?? "Server nicht erreichbar"; resultType = .error }
                return
            }
            self.pollResult(cmdId: cmdId, attempts: 0)
        }.resume()
    }

    private func pollResult(cmdId: String, attempts: Int) {
        let maxAttempts = 120
        guard let url = URL(string: "\(serverURL)/result/\(cmdId)") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            URLSession.shared.dataTask(with: url) { data, _, error in
                guard let data = data, let poll = try? JSONDecoder().decode(QueuePollResponse.self, from: data) else {
                    if attempts < maxAttempts { self.pollResult(cmdId: cmdId, attempts: attempts + 1) }
                    else { DispatchQueue.main.async { isRunning = false; output = "Timeout - Mac Client nicht erreichbar?"; resultType = .error } }
                    return
                }
                DispatchQueue.main.async {
                    if poll.status == "completed" || poll.status == "failed" || poll.success != nil {
                        isRunning = false
                        if let r = poll.result {
                            let out = r.stdout ?? ""
                            let err = r.stderr ?? ""
                            output = out + (err.isEmpty ? "" : "\nFehler:\n" + err)
                        } else if let s = poll.stdout, !s.isEmpty {
                            let err = poll.stderr ?? ""
                            output = s + (err.isEmpty ? "" : "\nFehler:\n" + err)
                        } else {
                            output = "Befehl ausgefuhrt (keine Ausgabe)"
                        }
                        resultType = (poll.success ?? (poll.returncode == 0)) ? .success : .error
                        macConnected = true
                    } else if poll.status == "running" || poll.status == "pending" {
                        output = poll.status == "running" ? "Befehl lauft auf Mac..." : "Befehl wartet in der Warteschlange..."
                        self.pollResult(cmdId: cmdId, attempts: attempts + 1)
                    } else { self.pollResult(cmdId: cmdId, attempts: attempts + 1) }
                }
            }.resume()
        }
    }
}