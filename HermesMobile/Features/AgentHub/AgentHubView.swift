import SwiftUI
import SwiftData

struct AgentHubView: View {
    @Query(sort: \MoodEntry.date, order: .reverse) var moods: [MoodEntry]
    @Query(sort: \HabitLog.date, order: .reverse) var habits: [HabitLog]
    @Query(sort: \Expense.date, order: .reverse) var expenses: [Expense]
    @Environment(\.modelContext) var mc
    @State private var showIdea = false
    @State private var newIdea = ""
    @Binding var requestedNewChat: NewChatRequest?
    @ObservedObject private var rollup = NARollupService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Greeting with refresh button
                greetingCard

                // Letzter Sync
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath").font(.caption).foregroundColor(.ncSage)
                    Text("Rollup: \(rollup.rollup?.ts.prefix(16) ?? "–")").font(.system(size: 10)).foregroundColor(.ncMuted)
                    Spacer()
                    if rollup.isLoading {
                        ProgressView().scaleEffect(0.6)
                    }
                }.padding(.horizontal, 4)

                if let err = rollup.lastError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").font(.caption).foregroundColor(.ncRed)
                        Text(err).font(.system(size: 10)).foregroundColor(.ncRed)
                        Spacer()
                    }.padding(.horizontal, 4)
                }

                // Briefings
                if let b = rollup.crm?.briefings, let today = b.today, !today.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Briefings").font(.headline.weight(.semibold)).foregroundColor(.ncWhite)
                        ForEach(today) { briefing in
                            NavigationLink(destination: NABriefingDetailView(briefing: briefing, requestedNewChat: $requestedNewChat)) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(briefing.period == "morning" ? Color.ncAmber.opacity(0.15) : briefing.period == "midday" ? Color.ncNeonGreen.opacity(0.15) : Color.ncCyan.opacity(0.15))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: briefing.period == "morning" ? "sunrise.fill" : briefing.period == "midday" ? "sun.max.fill" : "moon.stars.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(briefing.period == "morning" ? .ncAmber : briefing.period == "midday" ? .ncNeonGreen : .ncCyan)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(briefing.title ?? "").font(.subheadline.weight(.semibold)).foregroundColor(.ncWhite).lineLimit(1)
                                        Text(briefing.body ?? "").font(.caption).foregroundColor(.ncGray).lineLimit(2)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundColor(.ncGray)
                                }
                                .padding(12)
                                .background(Color.ncSurface, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    BriefingPlaceholder(requestedNewChat: $requestedNewChat)
                }

                // Summary Flags (Amelia's Warnungen)
                if !rollup.flags.isEmpty {
                    ForEach(rollup.flags) { flag in
                        HStack(spacing: 10) {
                            Image(systemName: flag.level == "red" ? "exclamationmark.triangle.fill" : flag.level == "yellow" ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundColor(flag.level == "red" ? .ncRed : flag.level == "yellow" ? .ncGold : .ncGreen)
                                .font(.title3)
                            Text(flag.text).font(.subheadline).foregroundColor(.ncDark)
                            Spacer()
                        }
                        .warmCard()
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(
                            flag.level == "red" ? Color.ncRed.opacity(0.3) : flag.level == "yellow" ? Color.ncGold.opacity(0.3) : Color.ncGreen.opacity(0.3)
                        ))
                    }
                }

                // WHOOP – nur Rollup (kein NAiceAPI.shared Fallback mehr)
                if let w = rollup.whoop {
                    NAIceSectionLabel(icon: "heart.circle.fill", title: "Gesundheit")
                    VStack(alignment: .leading, spacing: 14) {
                        recoveryRow(w)
                        Divider().foregroundColor(.ncSand.opacity(0.3))
                        sleepRow(w)
                    }.warmCard()
                } else if rollup.isLoading || NAiceAPI.shared.isLoading {
                    VStack(spacing: 12) { ProgressView(); Text("Lade Gesundheitsdaten...").font(.subheadline).foregroundColor(.ncMuted) }.warmCard()
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "heart.slash").font(.title2).foregroundColor(.ncSand)
                        Text("Keine WHOOP-Daten verfugbar").font(.subheadline).foregroundColor(.ncMuted)
                    }.warmCard()
                }

                // Kalender-Termine (vom Rollup-Server)
                if let c = rollup.calendar, c.count > 0 {
                    NAIceSectionLabel(icon: "calendar", title: "Termine")
                    ForEach(c.events?.prefix(3) ?? []) { event in
                        HStack(spacing: 12) {
                            Image(systemName: "calendar.circle").font(.title3).foregroundColor(.ncSage)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(event.title).font(.subheadline).foregroundColor(.ncDark)
                                if let s = event.start { Text(s).font(.caption).foregroundColor(.ncMuted) }
                            }
                            Spacer()
                        }.warmCard()
                    }
                }

                // Business
                if let b = rollup.business {
                    NAIceSectionLabel(icon: "briefcase.fill", title: "Business")
                    NavigationLink(destination: BusinessOverview()) {
                        HStack(spacing: 8) {
                            Text("Alle Projekte").font(.subheadline).foregroundColor(.ncGreen)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundColor(.ncSand)
                        }
                    }.buttonStyle(.plain)
                    if let f = b.foodloop {
                        bizCard("foodloop", f.total, f.hot ?? 0, f.statuses ?? [:])
                    }
                    if let n = b.naice {
                        bizCard("nAIce", n.total, n.hot ?? 0, n.statuses ?? [:])
                    }
                }

                // Deals
                if let d = rollup.deals, d.active_deals > 0 {
                    NAIceSectionLabel(icon: "eurosign", title: "Deals")
                    HStack {
                        Text("\(d.active_deals) aktive Deals").font(.subheadline.weight(.semibold)).foregroundColor(.ncDark)
                        Spacer()
                        Text("\(d.total_value_eur) €").font(.title3.weight(.bold)).foregroundColor(.ncGreen)
                    }.warmCard()
                    ForEach(d.deals?.prefix(3) ?? []) { deal in
                        NavigationLink(destination: DealDetailView(deal: deal)) {
                            HStack(spacing: 12) {
                                Circle().fill(Color.ncGreen).frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(deal.name).font(.subheadline.weight(.medium)).foregroundColor(.ncDark)
                                    Text(deal.status ?? "").font(.caption).foregroundColor(.ncMuted)
                                }
                                Spacer()
                                Text("\(deal.value) €").font(.subheadline.weight(.bold)).foregroundColor(.ncGreen)
                                Image(systemName: "chevron.right").font(.caption2).foregroundColor(.ncSand)
                            }
                        }.warmCard().buttonStyle(.plain)
                    }
                }

                // CRM
                if let c = rollup.crm, let total = c.total_clients, total > 0 {
                    NAIceSectionLabel(icon: "person.3.fill", title: "CRM")
                    NavigationLink(destination: NACRMDetailView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.3.fill").font(.title3).foregroundColor(.ncSage).frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(total) Kunden").font(.subheadline.weight(.semibold)).foregroundColor(.ncDark)
                                Text("\(c.active ?? 0) aktiv · \(c.won_deals ?? 0) gewonnen · \(c.total_value_eur ?? 0)€ Wert").font(.caption).foregroundColor(.ncMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption2).foregroundColor(.ncSand)
                        }
                    }.warmCard().buttonStyle(.plain)
                    
                    if let alerts = c.alerts, !alerts.isEmpty {
                        ForEach(alerts.prefix(2)) { alert in
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill").font(.caption).foregroundColor(.ncRed)
                                Text(alert.title ?? "").font(.caption).foregroundColor(.ncDark).lineLimit(1)
                                Spacer()
                            }
                            .padding(10)
                            .background(Color.ncRed.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.ncRed.opacity(0.15)))
                        }
                    }
                }

                // Tasks
                if let t = rollup.tasks, t.active > 0 {
                    NAIceSectionLabel(icon: "checklist", title: "Aufgaben")
                    ForEach(t.tasks?.prefix(3) ?? []) { task in
                        HStack(spacing: 12) {
                            Image(systemName: task.priority == "high" ? "exclamationmark.circle.fill" : "circle")
                                .foregroundColor(task.priority == "high" ? .ncRed : .ncSage)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(task.title).font(.subheadline).foregroundColor(.ncDark).lineLimit(2)
                                if let d = task.deadline { Text("Frist: \(d)").font(.caption).foregroundColor(.ncMuted) }
                            }
                            Spacer()
                        }.warmCard()
                    }
                }

                // Lebensbereiche
                NAIceSectionLabel(icon: "square.grid.2x2", title: "Meine Bereiche")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    area("heart.fill", "Gesundheit", .ncRed, AnyView(HealthDetailView()))
                    area("briefcase.fill", "Arbeit", .ncGreen, AnyView(WorkDetailView()))
                    area("person.2.fill", "Beziehungen", .ncSage, AnyView(RelationsDetailView()))
                    area("lightbulb.fill", "Kreativitat", .ncGold, AnyView(CreativityDetailView(naice: NAiceAPI.shared)))
                    area("house.fill", "Alltag", .ncDark, AnyView(DailyDetailView()))
                    area("folder.fill", "Dateien", .ncSage, AnyView(NAIceFilesView()))
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }
        .warmBackground()
        .navigationTitle("nAIce")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await refreshAll() }
    }

    private func refreshAll() async {
        await rollup.fetch()
        await NAJournalService.shared.fetch()
    }

    private var greetingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Circle().fill(Color.ncGreen).frame(width: 48, height: 48)
                    .overlay(Image(systemName: "person.fill").font(.title3).foregroundColor(.white))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hallo Johannes").font(.headline.weight(.bold)).foregroundColor(.ncDark)
                    Text(timeGreeting()).font(.subheadline).foregroundColor(.ncMuted)
                }
                Spacer()
                Button { Task { await refreshAll() } } label: {
                    Image(systemName: "arrow.clockwise").font(.title3).foregroundColor(.ncSage)
                }
                .disabled(rollup.isLoading || NAiceAPI.shared.isLoading)
            }
        }.warmCard()
    }

    private func recoveryRow(_ w: NAWhoopRollup) -> some View {
        Group {
            if let r = w.recovery {
                HStack {
                    Text("Recovery").font(.subheadline).foregroundColor(.ncMuted)
                    Spacer()
                    Text("\(r.score)%").font(.title2.weight(.bold)).foregroundColor(r.score > 60 ? .ncGreen : .ncRed)
                }
                ProgressView(value: Double(r.score) / 100).tint(r.score > 60 ? .ncGreen : .ncRed)
                HStack(spacing: 0) {
                    mini("heart.fill", "\(r.rhr)", "Puls")
                    mini("waveform.path.ecg", "\(r.hrv)ms", "HRV")
                    if let s = r.spo2 { mini("drop.fill", "\(Int(s))%", "SpO2") }
                }
            }
        }
    }

    private func sleepRow(_ w: NAWhoopRollup) -> some View {
        Group {
            if let s = w.sleep {
                HStack {
                    Text("Schlaf").font(.subheadline).foregroundColor(.ncMuted)
                    Spacer()
                    Text(String(format: "%.1fh", s.net_hours)).font(.title3.weight(.bold)).foregroundColor(.ncDark)
                    if let e = s.efficiency_pct { Text("(\(Int(e))%)").font(.caption).foregroundColor(.ncMuted) }
                }
                if s.deep_minutes + s.rem_minutes + s.light_minutes + s.awake_minutes > 0 {
                    let total = Double(s.deep_minutes + s.rem_minutes + s.light_minutes + s.awake_minutes)
                    HStack(spacing: 3) {
                        phaseBar(.ncDark, Double(s.deep_minutes) / total, "Deep")
                        phaseBar(.ncGreen, Double(s.rem_minutes) / total, "REM")
                        phaseBar(Color.ncSand.opacity(0.5), Double(s.light_minutes) / total, "Light")
                        phaseBar(.ncRed.opacity(0.3), Double(s.awake_minutes) / total, "Awake")
                    }
                    HStack {
                        leg("Deep", Color.ncDark); leg("REM", Color.ncGreen)
                        leg("Light", Color.ncSand.opacity(0.5)); leg("Awake", Color.ncRed.opacity(0.3))
                    }
                }
                if let w = w.cycle {
                    HStack {
                        Text("Strain: \(String(format: "%.1f", w.strain ?? 0))").font(.caption).foregroundColor(.ncMuted)
                        Spacer()
                        if let avg = w.avg_hr { Text("Puls O: \(avg)").font(.caption).foregroundColor(.ncMuted) }
                    }
                }
            }
        }
    }

    private func bizCard(_ name: String, _ total: Int, _ hot: Int, _ statuses: [String: Int]) -> some View {
        HStack(spacing: 12) {
            Image(systemName: name == "foodloop" ? "fork.knife" : "brain.head.profile")
                .font(.title3).foregroundColor(.ncSage).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(name.capitalized).font(.subheadline.weight(.semibold)).foregroundColor(.ncDark)
                Text("\(total) Kontakte · \(hot) heiss").font(.caption).foregroundColor(.ncMuted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundColor(.ncSand)
        }.warmCard()
    }

    private func phaseBar(_ color: Color, _ pct: Double, _ label: String) -> some View {
        RoundedRectangle(cornerRadius: 3).fill(color).frame(height: 12)
            .frame(maxWidth: pct > 0.01 ? .infinity : 0)
    }

    private func leg(_ t: String, _ c: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(c).frame(width: 6, height: 6)
            Text(t).font(.system(size: 9)).foregroundColor(.ncMuted)
        }
    }
}

// MARK: - Briefing Placeholder
struct BriefingPlaceholder: View {
    @Binding var requestedNewChat: NewChatRequest?
    @ObservedObject private var rollup = NARollupService.shared
    @State private var isGenerating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.ncCyan.opacity(0.1))
                    .frame(width: 56, height: 56)
                Image(systemName: "sparkle")
                    .font(.title2)
                    .foregroundColor(.ncCyan)
            }

            VStack(spacing: 6) {
                Text("Amelia meldet sich bald")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.ncWhite)
                Text("Morgen-, Mittags- und Abend-Briefings erscheinen hier, sobald Amelia sie fur dich erstellt.")
                    .font(.caption)
                    .foregroundColor(.ncGray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            if isGenerating {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.ncCyan)
                    Text("Erstelle Briefing...")
                        .font(.caption)
                        .foregroundColor(.ncGray)
                }
            } else {
                Button {
                    Task { await generateBriefing() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.caption)
                        Text("Jetzt Briefing anfordern")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(.ncCyan)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.ncCyan.opacity(0.3), lineWidth: 1)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.ncCyan.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
            }

            if let err = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.ncRose)
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.ncRose)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.ncSurface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.02),
                            .clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private func generateBriefing() async {
        isGenerating = true
        errorMessage = nil
        do {
            guard let url = URL(string: "https://health.santoslab.de/api/crm/briefing/generate") else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body = ["period": "morning"]
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode < 400 else {
                throw URLError(.badServerResponse)
            }
            // Refresh rollup to show the new briefing
            await rollup.fetch()
        } catch {
            errorMessage = "Fehler: \(error.localizedDescription)"
        }
        isGenerating = false
    }
}

extension NACalendarEvent: Identifiable {
    var id: String { title }
}