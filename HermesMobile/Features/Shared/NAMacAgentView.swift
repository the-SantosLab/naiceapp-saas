import SwiftUI

// MARK: - Mac Agent Result (Decodable from server + queue)
struct MacAgentResult: Decodable {
    let success: Bool
    let output: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        if let out = try? container.decode(String.self, forKey: .output) {
            output = out
        } else if let out = try? container.decode(String.self, forKey: .stdout) {
            output = out
        } else {
            output = ""
        }
    }

    enum CodingKeys: String, CodingKey {
        case success, output, stdout
    }
}

// MARK: - Queue Models
struct QueueSubmitResponse: Decodable {
    let ok: Bool?
    let id: String?
    let error: String?
}

struct QueuePollResponse: Decodable {
    let id: String?
    let command: String?
    let status: String?
    let result: QueueResult?
    let stdout: String?
    let stderr: String?
    let returncode: Int?
    let success: Bool?
    let error: String?
}

struct QueueResult: Decodable {
    let stdout: String?
    let stderr: String?
    let returncode: Int?
}

// MARK: - Mac Agent View
struct NAMacAgentView: View {
    @State private var command = ""
    @State private var output = ""
    @State private var isRunning = false
    @State private var recentCommands: [String] = []
    @State private var resultType: ResultType = .idle
    @State private var macConnected = false

    enum ResultType { case idle, success, error }

    let serverURL = "https://health.santoslab.de/api/mac-agent"

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
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

                // Quick Commands
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(["ls ~/Desktop/", "cat ~/Desktop/naice.txt", "whoami", "date", "df -h", "open /Applications/", "pwd", "sw_vers"], id: \.self) { cmd in
                        Button {
                            command = cmd
                            runCommand(cmd)
                        } label: {
                            Text(cmd)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.ncCyan)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.ncCyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.ncCyan.opacity(0.15), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)

                // Command Input
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "apple.terminal")
                            .font(.caption)
                            .foregroundColor(.ncCyan)
                        TextField("Befehl eingeben...", text: $command)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                            .onSubmit { runCommand(command) }
                    }
                    .padding(12)
                    .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 0.5))

                    Button {
                        runCommand(command)
                    } label: {
                        HStack(spacing: 6) {
                            if isRunning {
                                ProgressView().scaleEffect(0.6).tint(.white)
                            }
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

                // Output
                if !output.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "terminal")
                                .font(.caption)
                                .foregroundColor(resultType == .success ? .ncNeonGreen : .ncRose)
                            Text("Output")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.gray)
                            Spacer()
                            Button {
                                UIPasteboard.general.string = output
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(.plain)
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
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(red: 0.01, green: 0.01, blue: 0.02))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(resultType == .success ? Color.ncNeonGreen.opacity(0.1) : Color.ncRose.opacity(0.1), lineWidth: 0.5))
                    )
                    .padding(.horizontal, 16)
                }

                // Recent Commands
                if !recentCommands.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("Letzte Befehle | \(macConnected ? "Mac verbunden" : "warte auf Mac Client...")")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.gray)
                        }
                        ForEach(recentCommands.prefix(5), id: \.self) { cmd in
                            Button {
                                command = cmd
                                runCommand(cmd)
                            } label: {
                                Text(cmd)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                            .buttonStyle(.plain)
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
        .task {
            // Initial health check + start polling for connection status
            checkMacConnected()
        }
    }

    private func checkMacConnected() {
        guard let url = URL(string: "\(serverURL)/health") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if data != nil {
                DispatchQueue.main.async { macConnected = true }
            }
        }.resume()
    }

    private func runCommand(_ cmd: String) {
        guard !cmd.isEmpty else { return }
        isRunning = true
        output = "Sende Befehl an Mac..."
        resultType = .idle

        if !recentCommands.contains(cmd) {
            recentCommands.insert(cmd, at: 0)
            if recentCommands.count > 10 { recentCommands.removeLast() }
        }

        // Step 1: Queue the command
        guard let queueUrl = URL(string: "\(serverURL)/queue") else { return }
        var req = URLRequest(url: queueUrl)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(["command": cmd])

        URLSession.shared.dataTask(with: req) { data, _, error in
            guard let data = data,
                  let submit = try? JSONDecoder().decode(QueueSubmitResponse.self, from: data),
                  let cmdId = submit.id else {
                DispatchQueue.main.async {
                    isRunning = false
                    output = error?.localizedDescription ?? "Server nicht erreichbar"
                    resultType = .error
                }
                return
            }

            // Step 2: Poll for result
            self.pollResult(cmdId: cmdId, attempts: 0)
        }.resume()
    }

    private func pollResult(cmdId: String, attempts: Int) {
        let maxAttempts = 120 // 120 * 2s = 4 Minuten max
        guard let url = URL(string: "\(serverURL)/result/\(cmdId)") else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            URLSession.shared.dataTask(with: url) { data, _, error in
                guard let data = data,
                      let poll = try? JSONDecoder().decode(QueuePollResponse.self, from: data) else {
                    if attempts < maxAttempts {
                        if attempts % 5 == 0 {
                            DispatchQueue.main.async {
                                output = "Warte auf Mac Client... (\(attempts * 2)s)"
                            }
                        }
                        self.pollResult(cmdId: cmdId, attempts: attempts + 1)
                    } else {
                        DispatchQueue.main.async {
                            isRunning = false
                            output = "Timeout nach \(maxAttempts * 2)s - Mac Client nicht erreichbar?"
                            resultType = .error
                        }
                    }
                    return
                }

                DispatchQueue.main.async {
                    if poll.status == "completed" || poll.status == "failed" || poll.success != nil {
                        // Got result
                        isRunning = false
                        if let r = poll.result {
                            let out = r.stdout ?? ""
                            let err = r.stderr ?? ""
                            output = out + (err.isEmpty ? "" : "\nFehler:\n" + err)
                            resultType = (r.returncode == 0) ? .success : .error
                        } else if let s = poll.stdout {
                            output = s + (poll.stderr ?? "")
                            resultType = (poll.success ?? false) ? .success : .error
                        } else {
                            output = "Befehl ausgefuhrt (keine Ausgabe)"
                            resultType = .success
                        }
                        macConnected = true
                    } else if poll.status == "running" {
                        output = "Befehl lauft auf Mac..."
                        self.pollResult(cmdId: cmdId, attempts: attempts + 1)
                    } else if poll.status == "pending" {
                        output = "Befehl wartet in der Warteschlange..."
                        self.pollResult(cmdId: cmdId, attempts: attempts + 1)
                    } else {
                        self.pollResult(cmdId: cmdId, attempts: attempts + 1)
                    }
                }
            }.resume()
        }
    }
}