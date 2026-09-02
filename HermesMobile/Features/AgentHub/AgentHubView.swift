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
    @ObservedObject private var proactive = NAProactiveService.shared
    @ObservedObject private var goals = NAGoalService.shared
    @ObservedObject private var companies = NACompanyService.shared
    @ObservedObject private var waVM = WhatsAppViewModel.shared
    @State private var showLifeScore = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("nAIce")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                        Text(timeGreeting())
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        if rollup.isLoading {
                            ProgressView().scaleEffect(0.7).tint(.ncCyan)
                        }
                        Button { Task { await refreshAll() } } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14))
                                .foregroundColor(.ncCyan)
                        }
                        .disabled(rollup.isLoading)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Life Score (Einer-Blick)
                Button { showLifeScore = true } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().stroke(Color.white.opacity(0.08), lineWidth: 4).frame(width: 44, height: 44)
                            Circle()
                                .trim(from: 0, to: 0.72)
                                .stroke(Color.ncNeonGreen, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 44, height: 44).rotationEffect(.degrees(-90))
                            Text("72").font(.caption.weight(.bold)).foregroundColor(.ncNeonGreen)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Life Score").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                            let unread = waVM.unrepliedChats.count
                            let tasks = rollup.tasks
                            let parts: String = {
                                var p: [String] = []
                                if let rec = rollup.whoop?.recovery?.score { p.append("Recovery \(rec)%") }
                                if let t = tasks, t.active > 0 { p.append("\(t.active) Tasks") }
                                if unread > 0 { p.append("\(unread) WhatsApp") }
                                return p.isEmpty ? "Alles im Blick →" : p.joined(separator: " · ")
                            }()
                            Text(parts).font(.caption).foregroundColor(.gray).lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption2).foregroundColor(.gray)
                    }
                    .padding(12)
                    .background(
                        LinearGradient(colors: [Color.ncNeonGreen.opacity(0.08), Color.ncCyan.opacity(0.04)], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.ncNeonGreen.opacity(0.15), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)

                // Sync status
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                    Text("Rollup: \(rollup.rollup?.ts.prefix(16) ?? "–")")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal, 20)

                if let err = rollup.lastError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.ncRose)
                        Text(err)
                            .font(.system(size: 9))
                            .foregroundColor(.ncRose)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(8)
                    .background(Color.ncRose.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }

                // Briefings
                if let b = rollup.crm?.briefings, let today = b.today, !today.isEmpty {
                    briefingSection(today)
                } else {
                    BriefingPlaceholder(requestedNewChat: $requestedNewChat)
                        .padding(.horizontal, 16)
                }

                // Proaktive Push-Benachrichtigungen
                ProactiveBriefingCard()

                // Summary Flags
                if !rollup.flags.isEmpty {
                    flagsSection
                }

                // WHOOP (Rollup-basiert)
                if let w = rollup.whoop {
                    whoopSection(w)
                } else if rollup.isLoading || NAiceAPI.shared.isLoading {
                    VStack(spacing: 16) {
                        ProgressView().tint(.ncCyan)
                        Text("Lade Gesundheitsdaten...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .padding(.horizontal, 16)
                } else {
                    emptySection(icon: "heart.slash", title: "Keine WHOOP-Daten", message: "Warte auf Aktualisierung vom Server.")
                        .padding(.horizontal, 16)
                }

                // Proaktive Vorschläge
                if !proactive.activeSuggestions.isEmpty {
                    sectionHeader(icon: "sparkle.magnifyingglass", title: "Vorschläge")
                        .padding(.horizontal, 20)
                    VStack(spacing: 6) {
                        ForEach(proactive.activeSuggestions.prefix(5)) { suggestion in
                            NASuggestionCard(suggestion: suggestion, onArchive: { proactive.archiveSuggestion(suggestion.archiveId) })
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Kalender-Termine
                if let c = rollup.calendar, c.count > 0 {
                    sectionHeader(icon: "calendar", title: "Termine")
                        .padding(.horizontal, 20)
                    VStack(spacing: 8) {
                        ForEach(c.events?.prefix(3) ?? []) { event in
                            glassCard {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.ncCyan.opacity(0.12))
                                            .frame(width: 28, height: 28)
                                        Image(systemName: "calendar.circle")
                                            .font(.system(size: 12))
                                            .foregroundColor(.ncCyan)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.title).font(.subheadline.weight(.medium)).foregroundColor(.white)
                                        if let s = event.start { Text(s).font(.caption).foregroundColor(.gray) }
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Business
                if let b = rollup.business {
                    businessSection(b)
                }

                // Deals
                if let d = rollup.deals, d.active_deals > 0 {
                    dealsSection(d)
                }

                // CRM
                if let c = rollup.crm, let total = c.total_clients, total > 0 {
                    crmSection(c)
                }

                // Tasks
                if let t = rollup.tasks, t.active > 0 {
                    tasksSection(t)
                }

                // Meine Bereiche
                sectionHeader(icon: "square.grid.2x2", title: "Meine Bereiche")
                    .padding(.horizontal, 20)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    areaTile("heart.fill", "Gesundheit", .ncRose, HealthDetailView())
                    areaTile("briefcase.fill", "Arbeit", .ncCyan, WorkDetailView())
                    areaTile("person.2.fill", "Beziehungen", .ncNeonGreen, RelationsDetailView())
                    areaTile("lightbulb.fill", "Kreativitat", .ncAmber, CreativityDetailView(naice: NAiceAPI.shared))
                    areaTile("house.fill", "Alltag", .ncBlue, DailyDetailView())
                    areaTile("folder.fill", "Dateien", .ncPurple, NAIceFilesView())
                    areaTile("camera.viewfinder", "Scanner", .ncCyan, NACameraView())
                    areaTile("note.text", "Notizen", .ncBlue, NANotesView())
                    areaTile("figure.walk", "Habits", .ncNeonGreen, NAHabitsView())
                    areaTile("target", "Ziele", .ncAmber, NALifeGoalsView())
                    areaTile("building.2.fill", "Unternehmen", .ncAmber, NACompaniesView())
                    areaTile("tray.fill", "Posteingang", .ncNeonGreen, NAUnifiedInboxView())
                    areaTile("homekit", "Smart Home", .ncAmber, NASmartHomeView())
                    areaTile("apple.terminal", "Mac Agent", .ncPurple, NAMacAgentView())
                    areaTile("bolt.shield.fill", "Service Status", .ncNeonGreen, NAServiceStatusView())
                    areaTile("brain.head.profile", "Johannes-Modell", .ncCyan, NAProfileView())
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 30)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await refreshAll() }
        .task {
            proactive.generate()
            await rollup.fetch()
            await goals.fetch()
            await companies.fetch()
        }
        .sheet(isPresented: $showLifeScore) {
            NavigationStack { NALifeScoreView() }
        }
    }

    // MARK: - Refresh
    private func refreshAll() async {
        await rollup.fetch()
        await NAJournalService.shared.fetch()
        await goals.fetch()
        await companies.fetch()
        await waVM.fetchPending()
        proactive.generate()
    }

    // MARK: - Briefing Section
    private func briefingSection(_ today: [NABriefing]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "sparkle", title: "Briefings")
                .padding(.horizontal, 4)
            VStack(spacing: 8) {
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
                                Text(briefing.title ?? "").font(.subheadline.weight(.semibold)).foregroundColor(.white).lineLimit(1)
                                Text(briefing.body ?? "").font(.caption).foregroundColor(.gray).lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding(12)
                        .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Flags
    private var flagsSection: some View {
        VStack(spacing: 8) {
            ForEach(rollup.flags) { flag in
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(flag.level == "red" ? Color.ncRose.opacity(0.15) : flag.level == "yellow" ? Color.ncAmber.opacity(0.15) : Color.ncNeonGreen.opacity(0.15))
                            .frame(width: 28, height: 28)
                        Image(systemName: flag.level == "red" ? "exclamationmark.triangle.fill" : flag.level == "yellow" ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(flag.level == "red" ? .ncRose : flag.level == "yellow" ? .ncAmber : .ncNeonGreen)
                    }
                    Text(flag.text).font(.subheadline).foregroundColor(.white)
                    Spacer()
                }
                .padding(12)
                .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                    flag.level == "red" ? Color.ncRose.opacity(0.2) : flag.level == "yellow" ? Color.ncAmber.opacity(0.2) : Color.ncNeonGreen.opacity(0.2), lineWidth: 0.5))
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - WHOOP Section
    private func whoopSection(_ w: NAWhoopRollup) -> some View {
        VStack(spacing: 14) {
            sectionHeader(icon: "heart.circle.fill", title: "Gesundheit")
                .padding(.horizontal, 4)

            glassCard {
                VStack(spacing: 14) {
                    if let r = w.recovery {
                        HStack {
                            Text("Recovery").font(.subheadline).foregroundColor(.gray)
                            Spacer()
                            Text("\(r.score)%")
                                .font(.title2.weight(.bold))
                                .foregroundColor(recoveryColor(r.score))
                        }
                        ProgressView(value: Double(r.score) / 100)
                            .tint(recoveryColor(r.score))
                        HStack(spacing: 0) {
                            mini("heart.fill", "\(r.rhr)", "Puls")
                            mini("waveform.path.ecg", "\(r.hrv)ms", "HRV")
                            if let s = r.spo2 { mini("drop.fill", "\(Int(s))%", "SpO2") }
                        }
                    }

                    if let s = w.sleep {
                        Divider().overlay(Color.white.opacity(0.06))
                        HStack {
                            Text("Schlaf").font(.subheadline).foregroundColor(.gray)
                            Spacer()
                            Text(String(format: "%.1fh", s.net_hours)).font(.title3.weight(.bold)).foregroundColor(.white)
                            if let e = s.efficiency_pct { Text("(\(Int(e))%)").font(.caption).foregroundColor(.gray) }
                        }
                        if s.deep_minutes + s.rem_minutes + s.light_minutes + s.awake_minutes > 0 {
                            let total = Double(s.deep_minutes + s.rem_minutes + s.light_minutes + s.awake_minutes)
                            HStack(spacing: 3) {
                                phaseBar(.white, Double(s.deep_minutes) / total, "Deep")
                                phaseBar(.ncNeonGreen, Double(s.rem_minutes) / total, "REM")
                                phaseBar(Color.ncGray, Double(s.light_minutes) / total, "Light")
                                phaseBar(.ncRose.opacity(0.3), Double(s.awake_minutes) / total, "Awake")
                            }
                            HStack(spacing: 12) {
                                leg("Deep", .white); leg("REM", .ncNeonGreen); leg("Light", .ncGray); leg("Awake", .ncRose.opacity(0.3))
                            }
                        }
                    }

                    if let cy = w.cycle {
                        Divider().overlay(Color.white.opacity(0.06))
                        HStack {
                            Text("Strain: \(String(format: "%.1f", cy.strain ?? 0))").font(.caption).foregroundColor(.gray)
                            Spacer()
                            if let avg = cy.avg_hr { Text("Puls Ø: \(avg)").font(.caption).foregroundColor(.gray) }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Business Section
    private func businessSection(_ b: NABusinessRollup) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                sectionHeader(icon: "briefcase.fill", title: "Business")
                Spacer()
                NavigationLink(destination: BusinessOverview()) {
                    HStack(spacing: 4) {
                        Text("Alle").font(.caption).foregroundColor(.ncCyan)
                        Image(systemName: "chevron.right").font(.system(size: 8)).foregroundColor(.ncCyan)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            if let f = b.foodloop {
                bizCard("foodloop", f.total, f.hot ?? 0)
            }
            if let n = b.naice {
                bizCard("nAIce", n.total, n.hot ?? 0)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        )
        .padding(.horizontal, 16)
    }

    private func bizCard(_ name: String, _ total: Int, _ hot: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.ncCyan.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: name == "foodloop" ? "fork.knife" : "brain.head.profile")
                    .font(.system(size: 12))
                    .foregroundColor(.ncCyan)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name.capitalized).font(.subheadline.weight(.semibold)).foregroundColor(.white)
                Text("\(total) Kontakte · \(hot) heiss").font(.caption).foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption2).foregroundColor(.gray)
        }
        .padding(10)
        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.03), lineWidth: 0.5))
    }

    // MARK: - Deals Section
    private func dealsSection(_ d: NADealsRollup) -> some View {
        VStack(spacing: 12) {
            sectionHeader(icon: "creditcard.fill", title: "Deals")
                .padding(.horizontal, 4)
            glassCard {
                HStack {
                    Text("\(d.active_deals) aktive Deals").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                    Spacer()
                    Text("\(d.total_value_eur) €").font(.title3.weight(.bold)).foregroundColor(.ncNeonGreen)
                }
            }
            ForEach(d.deals?.prefix(3) ?? []) { deal in
                NavigationLink(destination: DealDetailView(deal: deal)) {
                    HStack(spacing: 12) {
                        Circle().fill(Color.ncNeonGreen).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(deal.name).font(.subheadline.weight(.medium)).foregroundColor(.white)
                            Text(deal.status ?? "").font(.caption).foregroundColor(.gray)
                        }
                        Spacer()
                        Text("\(deal.value) €").font(.subheadline.weight(.bold)).foregroundColor(.ncNeonGreen)
                        Image(systemName: "chevron.right").font(.caption2).foregroundColor(.gray)
                    }
                    .padding(12)
                    .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        )
        .padding(.horizontal, 16)
    }

    // MARK: - CRM Section
    private func crmSection(_ c: NARollupCRM) -> some View {
        VStack(spacing: 12) {
            sectionHeader(icon: "person.3.fill", title: "CRM")
                .padding(.horizontal, 4)
            NavigationLink(destination: NACRMDetailView()) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.ncNeonGreen.opacity(0.12))
                            .frame(width: 28, height: 28)
                        Image(systemName: "person.3.fill").font(.system(size: 12)).foregroundColor(.ncNeonGreen)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(c.total_clients ?? 0) Kunden").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                        Text("\(c.active ?? 0) aktiv · \(c.won_deals ?? 0) gewonnen · \(c.total_value_eur ?? 0)€ Wert").font(.caption).foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption2).foregroundColor(.gray)
                }
            }
            .buttonStyle(.plain)
            .padding(12)
            .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 0.5))

            if let alerts = c.alerts, !alerts.isEmpty {
                ForEach(alerts.prefix(2)) { alert in
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 8)).foregroundColor(.ncRose)
                        Text(alert.title ?? "").font(.caption).foregroundColor(.ncRose).lineLimit(1)
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.ncRose.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.ncRose.opacity(0.15)))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Tasks Section
    private func tasksSection(_ t: NATasksRollup) -> some View {
        VStack(spacing: 12) {
            sectionHeader(icon: "checklist", title: "Aufgaben")
                .padding(.horizontal, 4)
            ForEach(t.tasks?.prefix(3) ?? []) { task in
                HStack(spacing: 12) {
                    Image(systemName: task.priority == "high" ? "exclamationmark.circle.fill" : "circle")
                        .foregroundColor(task.priority == "high" ? .ncRose : .ncGray)
                        .font(.system(size: 14))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title).font(.subheadline).foregroundColor(.white).lineLimit(2)
                        if let d = task.deadline { Text("Frist: \(d)").font(.caption).foregroundColor(.gray) }
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Shared Components
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.ncCyan)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
        }
    }

    private func glassCard(@ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) { content() }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
    }

    private func emptySection(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.ncCyan.opacity(0.1)).frame(width: 48, height: 48)
                Image(systemName: icon).font(.title2).foregroundColor(.ncCyan)
            }
            Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.white)
            Text(message).font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
    }

    private func areaTile<D: View>(_ icon: String, _ label: String, _ color: Color, _ dest: D) -> some View {
        NavigationLink(destination: dest) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(color)
                }
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func mini(_ i: String, _ v: String, _ l: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: i).font(.caption).foregroundColor(.ncCyan)
            Text(v).font(.caption.weight(.bold)).foregroundColor(.white)
            Text(l).font(.system(size: 8)).foregroundColor(.gray)
        }.frame(maxWidth: .infinity)
    }

    private func phaseBar(_ color: Color, _ pct: Double, _ label: String) -> some View {
        RoundedRectangle(cornerRadius: 3).fill(color).frame(height: 10)
            .frame(maxWidth: pct > 0.01 ? .infinity : 0)
    }

    private func leg(_ t: String, _ c: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(c).frame(width: 5, height: 5)
            Text(t).font(.system(size: 8)).foregroundColor(.gray)
        }
    }
}

// MARK: - Proactive Briefing Card
struct ProactiveBriefingCard: View {
    @ObservedObject private var pushService = NAPushService.shared
    @State private var showBriefing = false

    var body: some View {
        if let briefing = pushService.lastBriefing, !briefing.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.ncAmber.opacity(0.12))
                            .frame(width: 28, height: 28)
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.ncAmber)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Letztes Briefing")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                        Text("\(pushService.pendingNotifications.count) Push-Benachrichtigungen")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Button {
                        showBriefing = true
                    } label: {
                        Text("Anzeigen")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.ncCyan)
                    }
                }

                // Latest briefing preview
                Text(String(briefing.prefix(120)) + (briefing.count > 120 ? "..." : ""))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(3)

                if pushService.unreadCount > 0 {
                    Button {
                        pushService.markAllRead()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 8))
                            Text("\(pushService.unreadCount) ungelesen - Als gelesen markieren")
                                .font(.caption2)
                        }
                        .foregroundColor(.ncNeonGreen)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.ncAmber.opacity(0.15), lineWidth: 0.5))
            )
            .padding(.horizontal, 16)
            .sheet(isPresented: $showBriefing) {
                BriefingDetailSheet(briefing: briefing)
            }
        }
    }
}

// MARK: - Briefing Detail Sheet
struct BriefingDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    let briefing: String

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    Text(briefing)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationTitle("Proaktives Briefing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schließen") { dismiss() }.foregroundColor(.ncCyan)
                }
            }
        }
    }
}

extension NACalendarEvent: Identifiable {
    var id: String { title }
}