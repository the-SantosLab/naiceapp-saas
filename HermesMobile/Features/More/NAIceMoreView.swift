import SwiftUI

// MARK: - Rewritten More Tab
struct NAIceMoreView: View {
    @State private var showVoiceBar = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Mehr").font(.title2.weight(.bold)).foregroundColor(.ncDark)
                    Text("Alle Integrationen und Optionen.").font(.subheadline).foregroundColor(.ncMuted)

                    // Apple Dienste
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🍎 Apple Dienste").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                        integrationRow("heart.fill", "Apple Health", HealthManager.shared.isAuthorized ? "Verbunden" : "Nicht verbunden")
                        integrationRow("calendar", "Kalender", CalendarManager.shared.isAuthorized ? "Verbunden" : "Nicht verbunden")
                        integrationRow("person.2.fill", "Kontakte", NAContactService.shared.contacts.isEmpty ? "Nicht verbunden" : "\(NAContactService.shared.contacts.count) Kontakte")
                        integrationRow("mic.fill", "Spracherkennung", NAVoiceService.shared.isAuthorized ? "Bereit" : "Nicht autorisiert")
                        integrationRow("lock.fill", "Verschl. Notizen", NACryptoService.shared.isUnlocked ? "Entsperrt" : "Gesperrt")
                    }.warmCard()

                    // KI & Agent
                    VStack(alignment: .leading, spacing: 8) {
                        Text("✨ KI & Agent").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                        integrationRow("arrow.trianglehead.clockwise", "KI-Workflows", "\(NAWorkflowService.shared.workflows.count) aktiv")
                        integrationRow("waveform", "Sprach-Befehle", "Bereit", action: { showVoiceBar = true })
                        integrationRow("message.fill", "WhatsApp-Tracker", "\(WhatsAppViewModel.shared.totalUnread) offen")
                    }.warmCard()

                    // Finanzen
                    VStack(alignment: .leading, spacing: 8) {
                        Text("💰 Finanzen").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                        integrationRow("eurosign", "Budget", "\(NAFinanceService.shared.budgets.count) Kategorien")
                        integrationRow("cart.fill", "Ausgaben", "\(NAFinanceService.shared.expenses.count) erfasst")
                    }.warmCard()

                    // Server
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🖥 Server").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                        integrationRow("server.rack", "Server", "Verbunden")
                        integrationRow("brain.head.profile", "Memory", "Aktiv")
                    }.warmCard()

                    // App Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ℹ️ App").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                        HStack {
                            Text("Version").font(.subheadline).foregroundColor(.ncDark)
                            Spacer()
                            Text("20260825.0200").font(.subheadline).foregroundColor(.ncMuted)
                        }
                        Button("Nach Updates suchen") {
                            Task { await NAUpdateService.shared.checkForUpdates() }
                        }
                        .font(.subheadline).foregroundColor(.ncGreen)
                    }.warmCard()

                    // Quick Actions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("⚡ Aktionen").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                        Button("Sprach-Befehl") { showVoiceBar = true }
                            .font(.subheadline).foregroundColor(.ncGreen)
                        Button("Workflows prüfen") {
                            Task { await NAWorkflowService.shared.checkTriggers() }
                        }
                        .font(.subheadline).foregroundColor(.ncGreen)
                    }.warmCard()
                }
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
            }
            .warmBackground()
            .navigationTitle("Mehr")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showVoiceBar) {
            VoiceCommandBar()
        }
    }

    func integrationRow(_ icon: String, _ label: String, _ status: String, action: (() -> Void)? = nil) -> some View {
        Button(action: { action?() }) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.caption).foregroundColor(.ncSage).frame(width: 20)
                Text(label).font(.subheadline).foregroundColor(.ncDark)
                Spacer()
                Text(status).font(.caption).foregroundColor(.ncMuted)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}