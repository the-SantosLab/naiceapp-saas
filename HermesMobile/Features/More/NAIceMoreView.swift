import SwiftUI

// MARK: - Rewritten More Tab mit echten Daten
struct NAIceMoreView: View {
    @State private var showVoiceBar = false
    @ObservedObject private var waVM = WhatsAppViewModel.shared
    @ObservedObject private var rollup = NARollupService.shared
    @ObservedObject private var pushReg = PushRegistrar.shared
    @State private var pushRegistered = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Mehr").font(.title2.weight(.bold)).foregroundColor(.ncDark)
                    Text("Alle Integrationen, Optionen und Infos.").font(.subheadline).foregroundColor(.ncMuted)

                    // Apple Dienste
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🍎 Apple Dienste").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                        integrationRow("heart.fill", "Apple Health", HealthManager.shared.isAuthorized ? "Verbunden" : "Nicht verbunden")
                        integrationRow("calendar", "Kalender", CalendarManager.shared.isAuthorized ? "Verbunden" : "Nicht verbunden")
                        integrationRow("person.2.fill", "Kontakte", NAContactService.shared.contacts.isEmpty ? "Nicht verbunden" : "\(NAContactService.shared.contacts.count) Kontakte")
                        integrationRow("mic.fill", "Spracherkennung", NAVoiceService.shared.isAuthorized ? "Bereit" : "Nicht autorisiert")
                        integrationRow("lock.fill", "Verschl. Notizen", NACryptoService.shared.isUnlocked ? "Entsperrt" : "Gesperrt")
                        integrationRow("bell.fill", "Push", pushReg.statusText)
                    }.warmCard()

                    // KI & Agent
                    VStack(alignment: .leading, spacing: 8) {
                        Text("✨ KI & Agent").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                        integrationRow("arrow.trianglehead.clockwise", "KI-Workflows", "\(NAWorkflowService.shared.workflows.count) aktiv")
                        integrationRow("waveform", "Sprach-Befehle", "Bereit", action: { showVoiceBar = true })
                        integrationRow("message.fill", "WhatsApp", "\(waVM.totalUnread) offen")
                        if let t = rollup.tasks {
                            integrationRow("checklist", "Business-Tasks", "\(t.active) aktiv")
                        }
                    }.warmCard()

                    // Server
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🖥 Server").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                        integrationRow("server.rack", "Server", "health.santoslab.de")
                        integrationRow("brain.head.profile", "Agent Memory", "Aktiv")
                        integrationRow("n.square.fill", "Mac Agent", "8 Aktionen")
                    }.warmCard()

                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ℹ️ Info").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                        HStack {
                            Text("Version").font(.subheadline).foregroundColor(.ncDark)
                            Spacer()
                            Text(NAConstants.appVersion).font(.subheadline).foregroundColor(.ncMuted)
                        }
                        HStack {
                            Text("Build").font(.subheadline).foregroundColor(.ncDark)
                            Spacer()
                            Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–").font(.subheadline).foregroundColor(.ncMuted)
                        }
                        HStack {
                            Text("Server").font(.subheadline).foregroundColor(.ncDark)
                            Spacer()
                            Text("health.santoslab.de").font(.subheadline).foregroundColor(.ncMuted)
                        }
                        Button("Nach Updates suchen") {
                            Task { await NAUpdateService.shared.checkForUpdates() }
                        }
                        .font(.subheadline).foregroundColor(.ncGreen)
                    }.warmCard()

                    // Rechtliches
                    VStack(alignment: .leading, spacing: 8) {
                        Text("⚖️ Rechtliches").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                        Link("santoslab.de", destination: NAConstants.websiteURL)
                            .font(.subheadline).foregroundColor(.ncGreen)
                        Link("nAIce.app", destination: NAConstants.naiceAppURL)
                            .font(.subheadline).foregroundColor(.ncGreen)
                        Link("App installieren", destination: NAConstants.appStoreURL)
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
                        Button("Push registrieren") {
                            UIApplication.shared.registerForRemoteNotifications()
                            pushRegistered = true
                        }
                        .font(.subheadline).foregroundColor(.ncGreen)
                        if pushReg.registrationError != nil {
                            Button("Erneut registrieren") {
                                pushReg.registrationError = nil
                                UIApplication.shared.registerForRemoteNotifications()
                            }
                            .font(.subheadline).foregroundColor(.ncRed)
                        }
                    }.warmCard()
                }
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
            }
            .warmBackground()
            .navigationTitle("Mehr")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showVoiceBar) { VoiceCommandBar() }
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