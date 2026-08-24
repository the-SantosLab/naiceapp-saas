import Foundation
import Speech
import AVFoundation

// MARK: - Voice Command Service
@MainActor
class NAVoiceService: ObservableObject {
    static let shared = NAVoiceService()

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    @Published var isListening = false
    @Published var transcribedText = ""
    @Published var lastCommand: VoiceCommand?
    @Published var isAuthorized = false
    @Published var errorMessage: String?

    func requestAuth() async {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .notDetermined {
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                Task { @MainActor in
                    self?.isAuthorized = status == .authorized
                }
            }
        } else {
            isAuthorized = status == .authorized
        }

        // Also request mic
        let micStatus = AVAudioApplication.shared.recordPermission
        if micStatus == .undetermined {
            await AVAudioApplication.requestRecordPermission()
        }
    }

    func startListening() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Spracherkennung nicht verfügbar"
            return
        }

        isListening = true
        transcribedText = ""
        errorMessage = nil

        // Cancel previous task
        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            errorMessage = "Audio-Start fehlgeschlagen: \(error.localizedDescription)"
            isListening = false
            return
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                if let result = result {
                    self?.transcribedText = result.bestTranscription.formattedString
                    if result.isFinal {
                        self?.processCommand(result.bestTranscription.formattedString)
                    }
                }
                if error != nil {
                    self?.stopListening()
                }
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false

        // If we got text but no final result, process anyway
        if !transcribedText.isEmpty && lastCommand == nil {
            processCommand(transcribedText)
        }
    }

    private func processCommand(_ text: String) {
        let lower = text.lowercased()

        if lower.hasPrefix("notiz") || lower.hasPrefix("notiere") || lower.hasPrefix("merke") {
            let noteText = text
                .replacingOccurrences(of: "(?i)^notiz(\\s|:|-|,)", with: "", options: .regularExpression)
                .replacingOccurrences(of: "(?i)^notiere(\\s|:|-|,)", with: "", options: .regularExpression)
                .replacingOccurrences(of: "(?i)^merke(\\s|:|-|,)", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            lastCommand = VoiceCommand(type: .createNote, text: noteText, original: text)

        } else if lower.hasPrefix("aufgabe") || lower.hasPrefix("erinnere") || lower.hasPrefix("to do") || lower.hasPrefix("todo") {
            let taskText = text
                .replacingOccurrences(of: "(?i)^aufgabe(\\s|:|-|,)", with: "", options: .regularExpression)
                .replacingOccurrences(of: "(?i)^erinnere(\\s|:|-|,)", with: "", options: .regularExpression)
                .replacingOccurrences(of: "(?i)^(to do|todo)(\\s|:|-|,)", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            lastCommand = VoiceCommand(type: .createTask, text: taskText, original: text)

        } else if lower.hasPrefix("ausgabe") || lower.hasPrefix("geld") || lower.hasPrefix("bezahlt") {
            let expenseText = text
                .replacingOccurrences(of: "(?i)^ausgabe(\\s|:|-|,)", with: "", options: .regularExpression)
                .replacingOccurrences(of: "(?i)^geld(\\s|:|-|,)", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            lastCommand = VoiceCommand(type: .logExpense, text: expenseText, original: text)

        } else if lower.contains("stimmung") || lower.contains("mood") || lower.contains("gefuhl") {
            let moodText = text.trimmingCharacters(in: .whitespaces)
            if lower.contains("gut") || lower.contains("froh") || lower.contains("happy") {
                lastCommand = VoiceCommand(type: .logMood, text: "gut", original: text)
            } else if lower.contains("schlecht") || lower.contains("traurig") || lower.contains("mude") {
                lastCommand = VoiceCommand(type: .logMood, text: "schlecht", original: text)
            } else {
                lastCommand = VoiceCommand(type: .logMood, text: "mittel", original: text)
            }

        } else {
            lastCommand = VoiceCommand(type: .unknown, text: text, original: text)
        }

        // Auto-clear after 5 seconds
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            self?.lastCommand = nil
        }
    }
}

// MARK: - Voice Command Model
struct VoiceCommand: Identifiable {
    let id = UUID()
    let type: VoiceCommandType
    let text: String
    let original: String
}

enum VoiceCommandType: String {
    case createNote
    case createTask
    case logExpense
    case logMood
    case unknown
}