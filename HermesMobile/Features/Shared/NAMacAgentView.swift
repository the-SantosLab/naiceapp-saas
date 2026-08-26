import SwiftUI

// MARK: - Mac Agent View
struct NAMacAgentView: View {
    @State private var command = ""
    @State private var output = ""
    @State private var isRunning = false
    @State private var recentCommands: [String] = []
    @State private var resultType: ResultType = .idle

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
                        Text("Steuere deinen Mac von hier aus")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Circle()
                        .fill(resultType == .idle ? .gray : resultType == .success ? .ncNeonGreen : .ncRose)
                        .frame(width: 8, height: 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Quick Commands
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(["ls ~/Desktop/", "cat ~/Desktop/naice.txt", "whoami", "date", "df -h", "ps aux | head 10", "open /Applications/", "pwd", "sw_vers"], id: \.self) { cmd in
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
                .padding(.bottom, 4)

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
                            Text(isRunning ? "Ausfuhren..." : "Ausfuhren")
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
                            Text("Letzte Befehle")
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
    }

    private func runCommand(_ cmd: String) {
        guard !cmd.isEmpty else { return }
        isRunning = true
        output = ""
        resultType = .idle

        if !recentCommands.contains(cmd) {
            recentCommands.insert(cmd, at: 0)
            if recentCommands.count > 10 { recentCommands.removeLast() }
        }

        guard let url = URL(string: "\(serverURL)/execute") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(["command": cmd])

        URLSession.shared.dataTask(with: req) { data, _, error in
            DispatchQueue.main.async {
                isRunning = false
                if let data = data,
                   let result = try? JSONDecoder().decode(MacAgentResult.self, from: data) {
                    output = result.output
                    resultType = result.success ? .success : .error
                } else if let error = error {
                    output = "Fehler: \(error.localizedDescription)"
                    resultType = .error
                } else {
                    output = "Keine Antwort vom Server"
                    resultType = .error
                }
            }
        }.resume()
    }
}

// MARK: - Mac Agent Result
struct MacAgentResult: Codable {
    let success: Bool
    let output: String
}