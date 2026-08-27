import SwiftUI

// MARK: - Mac Agent View (Persistent State via Service)
struct NAMacAgentView: View {
    @ObservedObject private var mac = NAMacAgentService.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mac Agent")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                        Text(mac.macConnected ? "Verbunden mit deinem Mac" : "Warte auf Mac Client...")
                            .font(.subheadline)
                            .foregroundColor(mac.macConnected ? .ncNeonGreen : .gray)
                    }
                    Spacer()
                    Circle()
                        .fill(mac.macConnected ? Color.ncNeonGreen : Color.ncAmber)
                        .frame(width: 8, height: 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Status wenn Hintergrund läuft
                if mac.isRunning && mac.statusText != "" {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.6).tint(.ncCyan)
                        Text(mac.statusText)
                            .font(.caption)
                            .foregroundColor(.ncCyan)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }

                // Action Picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(NAMacAgentService.ActionMode.allCases, id: \.rawValue) { mode in
                            Button {
                                mac.actionMode = mode
                                mac.command = ""
                                mac.output = ""
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: mode.icon).font(.system(size: 9))
                                    Text(mode.rawValue).font(.caption)
                                }
                                .foregroundColor(mac.actionMode == mode ? .white : .gray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(mac.actionMode == mode ? Color.ncCyan : Color(red: 0.03, green: 0.03, blue: 0.06), in: Capsule())
                                .overlay(Capsule().stroke(mac.actionMode == mode ? Color.ncCyan : Color.white.opacity(0.08), lineWidth: 1))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Input
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: mac.actionMode.icon)
                            .font(.caption)
                            .foregroundColor(.ncCyan)
                        TextField(placeholder(for: mac.actionMode), text: $mac.command)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                            .onSubmit { mac.runCommand() }
                    }
                    .padding(12)
                    .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 0.5))

                    Button { mac.runCommand() } label: {
                        HStack(spacing: 6) {
                            if mac.isRunning { ProgressView().scaleEffect(0.6).tint(.white) }
                            Text(mac.isRunning ? "Lauft im Hintergrund..." : "An Mac senden")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(mac.command.isEmpty || mac.isRunning ? Color.gray.opacity(0.3) : Color.ncCyan, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(mac.command.isEmpty || mac.isRunning)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                // Quick Commands
                if mac.actionMode == .shell {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Schnellbefehle").font(.caption.weight(.semibold)).foregroundColor(.gray).padding(.horizontal, 20)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            quickBtn("whoami", "terminal")
                            quickBtn("date", "calendar")
                            quickBtn("df -h", "externaldrive")
                            quickBtn("sw_vers", "apple.logo")
                            quickBtn("ls ~/Desktop/", "folder")
                            quickBtn("ps aux | head 10", "memorychip")
                            quickBtn("open /Applications/", "app")
                            quickBtn("pwd", "arrow.right")
                        }
                        .padding(.horizontal, 16)
                    }
                } else if mac.actionMode == .openApp {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Apps").font(.caption.weight(.semibold)).foregroundColor(.gray).padding(.horizontal, 20)
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
                }

                // Output (bleibt auch nach View-Wechsel erhalten!)
                if !mac.output.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "terminal")
                                .font(.caption)
                                .foregroundColor(mac.resultType == .success ? .ncNeonGreen : .ncRose)
                            Text("Output von deinem Mac")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.gray)
                            Spacer()
                            Button { UIPasteboard.general.string = mac.output } label: {
                                Image(systemName: "doc.on.doc").font(.caption).foregroundColor(.gray)
                            }.buttonStyle(.plain)
                        }
                        ScrollView([.horizontal, .vertical]) {
                            Text(mac.output)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(mac.resultType == .success ? .white.opacity(0.9) : .ncRose)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 300)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.01, green: 0.01, blue: 0.02))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(mac.resultType == .success ? Color.ncNeonGreen.opacity(0.1) : Color.ncRose.opacity(0.1), lineWidth: 0.5)))
                    .padding(.horizontal, 16)
                }

                // Recent Commands
                if !mac.recentCommands.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock").font(.caption).foregroundColor(.gray)
                            Text("Letzte Aktionen").font(.caption.weight(.semibold)).foregroundColor(.gray)
                        }
                        ForEach(mac.recentCommands.prefix(5), id: \.self) { cmd in
                            Button {
                                mac.command = cmd
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
        .onAppear { mac.checkConnected() }
    }

    private func placeholder(for mode: NAMacAgentService.ActionMode) -> String {
        switch mode {
        case .shell: return "Befehl eingeben..."
        case .readFile: return "Dateipfad (z.B. ~/Desktop/note.txt)"
        case .openApp: return "App-Name (z.B. Safari)"
        case .screenshot: return "Screenshot wird aufgenommen..."
        case .findFiles: return "Muster (z.B. *.pdf, *.swift)"
        case .listDir: return "Ordner (z.B. ~/Desktop)"
        }
    }

    private func quickBtn(_ label: String, _ icon: String) -> some View {
        Button {
            mac.command = label
            mac.runCommand()
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
}