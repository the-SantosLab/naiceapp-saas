import SwiftUI

// MARK: - Deal Detail View with Edit Sheet
struct DealDetailView: View {
    let deal: NADeal
    @State private var showEdit = false
    @State private var editStatus = ""
    @State private var editValue = 0
    @State private var editNotes = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var saveSuccess = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(deal.name).font(.title2.weight(.bold)).foregroundColor(.ncDark)
                        Spacer()
                        Button("Bearbeiten") { startEdit() }
                            .font(.caption.weight(.semibold)).foregroundColor(.ncGreen)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(Color.ncGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.ncGreen.opacity(0.15)))
                    }
                    Text("\(deal.value) €").font(.title.weight(.bold)).foregroundColor(.ncGreen)
                    if let s = deal.status {
                        HStack(spacing: 6) {
                            Circle().fill(statusColor(s)).frame(width: 8, height: 8)
                            Text(s.capitalized).font(.subheadline.weight(.medium)).foregroundColor(statusColor(s))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(statusColor(s).opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                }.warmCard()

                // AI-Tipp
                VStack(spacing: 8) {
                    Text("AI-Tipp").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                    Text("Status und Wert direkt uber den Bearbeiten-Button andern. Die Anderungen werden sofort mit Amelia's CRM synchronisiert.")
                        .font(.subheadline).foregroundColor(.ncMuted)
                }.warmCard()

                if saveSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.ncGreen)
                        Text("Gespeichert!").font(.subheadline).foregroundColor(.ncGreen)
                    }
                    .padding(10)
                    .background(Color.ncGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }
        .warmBackground()
        .navigationTitle("Deal")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEdit) { editSheet }
    }

    private var editSheet: some View {
        NavigationStack {
            Form {
                Section("Status") {
                    Picker("Status", selection: $editStatus) {
                        Text("Lead").tag("lead")
                        Text("Kontaktiert").tag("contacted")
                        Text("Angebot").tag("proposal")
                        Text("Gewonnen").tag("won")
                        Text("Verloren").tag("lost")
                        Text("Bezahlt").tag("paid")
                    }
                }
                Section("Wert (EUR)") {
                    TextField("Wert", value: $editValue, format: .number)
                        .keyboardType(.numberPad)
                }
                Section("Notiz") {
                    TextEditor(text: $editNotes)
                        .frame(minHeight: 80)
                }
                if let err = saveError {
                    Section {
                        Text(err).font(.caption).foregroundColor(.ncRed)
                    }
                }
                Section {
                    Button(action: saveChanges) {
                        if isSaving {
                            ProgressView().scaleEffect(0.8).frame(maxWidth: .infinity)
                        } else {
                            Text("Speichern").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isSaving)
                    .font(.headline.weight(.semibold)).foregroundColor(.white)
                    .listRowBackground(Color.ncGreen)
                }
            }
            .navigationTitle("Deal bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { showEdit = false }
                }
            }
        }
    }

    private func startEdit() {
        editStatus = deal.status?.lowercased() ?? "lead"
        editValue = deal.value
        editNotes = ""
        saveError = nil
        saveSuccess = false
        showEdit = true
    }

    private func saveChanges() {
        isSaving = true
        saveError = nil
        Task {
            do {
                // Find client ID by name if not directly provided
                var clientId = deal.clientId ?? ""
                if clientId.isEmpty {
                    clientId = try await lookupClientIdByName(deal.name)
                }
                guard !clientId.isEmpty else {
                    await MainActor.run { saveError = "Kunde nicht gefunden. Name stimmt nicht mit CRM uberein."; isSaving = false }
                    return
                }
                let urlStr = "https://health.santoslab.de/api/crm/clients/\(clientId)/status"
                guard let url = URL(string: urlStr) else { throw URLError(.badURL) }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                var body: [String: Any] = ["status": editStatus, "stage": editStatus, "value": editValue]
                if !editNotes.isEmpty { body["notes"] = editNotes }
                req.httpBody = try JSONSerialization.data(withJSONObject: body)
                let (_, resp) = try await URLSession.shared.data(for: req)
                if let http = resp as? HTTPURLResponse, http.statusCode >= 400 {
                    throw URLError(.badServerResponse)
                }
                await MainActor.run {
                    saveSuccess = true
                    showEdit = false
                    isSaving = false
                    Task { await NARollupService.shared.fetch() }
                }
            } catch {
                await MainActor.run {
                    saveError = "Fehler: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }

    private func lookupClientIdByName(_ name: String) async throws -> String {
        guard let url = URL(string: "https://health.santoslab.de/api/crm/clients") else { return "" }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(NCRMClientList.self, from: data)
        for client in response.clients {
            if client.name.localizedCaseInsensitiveContains(name) || (client.company ?? "").localizedCaseInsensitiveContains(name) {
                return client.id
            }
        }
        return ""
    }

    private func statusColor(_ s: String) -> Color {
        switch s.lowercased() {
        case "active", "aktiv", "won", "bezahlt", "paid": return .ncGreen
        case "proposal", "angebot": return .ncGold
        case "contacted": return .blue
        case "lost", "verloren": return .ncRed
        default: return .ncMuted
        }
    }
}