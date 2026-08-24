import SwiftUI

// MARK: - Cards of the Moment – dynamisches Home
struct CardsOfTheMoment: View {
    @ObservedObject private var context = NAiceContext.shared
    @State private var showVoiceBar = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Kurzinfo").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                Spacer()
                Button {
                    showVoiceBar = true
                } label: {
                    Image(systemName: "waveform").font(.title3).foregroundColor(.ncGreen)
                        .frame(width: 36, height: 36)
                        .background(Color.ncGreen.opacity(0.1))
                        .cornerRadius(10)
                }
            }

            // Life Balance Score
            HStack(spacing: 12) {
                ZStack {
                    Circle().stroke(Color.ncSand.opacity(0.3), lineWidth: 4).frame(width: 48, height: 48)
                    Circle().trim(from: 0, to: CGFloat(context.lifeBalanceScore) / 100)
                        .stroke(Color.ncGreen, lineWidth: 4)
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(-90))
                    Text("\(context.lifeBalanceScore)").font(.system(size: 14, weight: .bold)).foregroundColor(.ncDark)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Life Balance").font(.subheadline.weight(.semibold)).foregroundColor(.ncDark)
                    Text(context.lifeBalanceScore > 70 ? "Gut im Flow!" : context.lifeBalanceScore > 40 ? "Ausgeglichen" : "Achtung, Erholung?")
                        .font(.caption).foregroundColor(context.lifeBalanceScore > 70 ? .ncGreen : .ncMuted)
                }
                Spacer()
            }
            .padding(12)
            .background(Color.white.opacity(0.6))
            .cornerRadius(14)

            // Cross Insights
            if !context.crossInsights.isEmpty {
                ForEach(context.crossInsights.prefix(3), id: \.self) { insight in
                    HStack(spacing: 10) {
                        Image(systemName: "lightbulb.fill").font(.caption).foregroundColor(.ncGold)
                        Text(insight).font(.caption).foregroundColor(.ncDark)
                        Spacer()
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(10)
                }
            }

            // Agent Suggestions
            if !context.agentSuggestions.isEmpty {
                ForEach(context.agentSuggestions.prefix(2)) { suggestion in
                    Button {
                        handleAction(suggestion.action)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: suggestion.icon).font(.title3).foregroundColor(.ncGreen)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title).font(.subheadline.weight(.semibold)).foregroundColor(.ncDark)
                                Text(suggestion.text).font(.caption).foregroundColor(.ncMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption2).foregroundColor(.ncSand)
                        }
                        .padding(12)
                        .background(Color.ncGreen.opacity(0.08))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $showVoiceBar) {
            VoiceCommandBar()
        }
    }

    private func handleAction(_ action: AgentAction) {
        switch action {
        case .openWhatsApp:
            // Switch to WhatsApp tab or open contact
            break
        case .suggestWalk:
            break
        case .scheduleDowntime:
            break
        case .celebrateBirthday(let contactId):
            break
        case .openJournal:
            break
        case .checkCalendar:
            break
        }
    }
}

// MARK: - Voice Command Bar
struct VoiceCommandBar: View {
    @ObservedObject private var voice = NAVoiceService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: voice.isListening ? "waveform.circle.fill" : "mic.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(voice.isListening ? .ncRed : .ncGreen)

            Text(voice.isListening ? "Ich hore zu..." : "Tippe zum Sprechen")
                .font(.headline).foregroundColor(.ncDark)

            if !voice.transcribedText.isEmpty {
                Text(voice.transcribedText)
                    .font(.subheadline).foregroundColor(.ncMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let cmd = voice.lastCommand {
                VStack(spacing: 8) {
                    Label(commandLabel(cmd.type), systemImage: commandIcon(cmd.type))
                        .font(.subheadline.weight(.semibold)).foregroundColor(.ncGreen)
                    Text(cmd.text).font(.caption).foregroundColor(.ncMuted)
                }
                .padding(12)
                .background(Color.ncGreen.opacity(0.1))
                .cornerRadius(12)
            }

            if let err = voice.errorMessage {
                Text(err).font(.caption).foregroundColor(.ncRed)
            }

            Spacer()

            Button(action: {
                if voice.isListening {
                    voice.stopListening()
                } else {
                    voice.startListening()
                }
            }) {
                Text(voice.isListening ? "Stopp" : "Aufnehmen")
                    .font(.headline.weight(.semibold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(voice.isListening ? Color.ncRed : Color.ncGreen)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 32)

            Button("Schliessen") { dismiss() }
                .font(.subheadline).foregroundColor(.ncMuted)
        }
        .padding()
        .background(Color.ncPaper)
        .task { await voice.requestAuth() }
    }

    private func commandLabel(_ type: VoiceCommandType) -> String {
        switch type {
        case .createNote: return "Notiz erstellt"
        case .createTask: return "Aufgabe erstellt"
        case .logExpense: return "Ausgabe geloggt"
        case .logMood: return "Stimmung geloggt"
        case .unknown: return "Nicht erkannt"
        }
    }

    private func commandIcon(_ type: VoiceCommandType) -> String {
        switch type {
        case .createNote: return "note.text"
        case .createTask: return "checklist"
        case .logExpense: return "eurosign"
        case .logMood: return "face.smiling"
        case .unknown: return "questionmark"
        }
    }
}