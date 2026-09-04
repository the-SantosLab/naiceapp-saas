import SwiftUI
import SwiftData

// MARK: - Konzept C: Terminal-Dashboard (All 5 Features)
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
    @State private var showAllAreas = false
    // Feature 1: Quadrant Expand
    @State private var expandedQuadrant: String? = nil
    // Feature 4: Momentum Card
    @State private var momentumIndex = 0
    @State private var momentumTimer: Timer? = nil
    // Feature 5: Parallax
    @State private var scrollOffset: CGFloat = 0

    private let momentumMessages: [(icon: String, title: String, color: Color)] = [
        ("flame.fill", "3 Tage starke Recovery-Serie", .ncNeonGreen),
        ("briefcase.fill", "Pitch-Deck diese Woche fallig", .ncAmber),
        ("wineglass.fill", "Schaffer-Wine: 2 neue Leads", .ncCyan),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            GeometryReader { geo in
                Color.clear.preference(key: ScrollOffsetKey.self, value: geo.frame(in: .global).minY)
            }
            .frame(height: 0)
            VStack(spacing: 16) {
                header
                // Feature 4: Momentum Card
                momentumCard
                    .offset(y: scrollOffset * 0.12)
                // Feature 1+3: Quadranten mit Sparklines + Expand
                quadGrid
                    .offset(y: scrollOffset * 0.08)
                // Feature 2: Timeline
                mainArea
                    .offset(y: scrollOffset * 0.05)
                quickBar
                    .offset(y: scrollOffset * 0.03)
                areasSection
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
            startMomentumTimer()
        }
        .onDisappear { momentumTimer?.invalidate() }
        .onPreferenceChange(ScrollOffsetKey.self) { scrollOffset = min(max($0, -120), 0) }
        .sheet(isPresented: $showLifeScore) { NavigationStack { NALifeScoreView() } }
    }

    // MARK: - Feature 4: Momentum Card
    private var momentumCard: some View {
        let msg = momentumMessages[momentumIndex]
        return HStack(spacing: 12) {
            Image(systemName: msg.icon)
                .font(.system(size: 16))
                .foregroundColor(msg.color)
            Text(msg.title)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer()
            HStack(spacing: 3) {
                ForEach(0..<momentumMessages.count, id: \.self) { i in
                    Circle()
                        .fill(i == momentumIndex ? msg.color : Color.white.opacity(0.15))
                        .frame(width: 5, height: 5)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(LinearGradient(colors: [msg.color.opacity(0.2), .clear], startPoint: .leading, endPoint: .trailing), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 16)
        .transition(.opacity.combined(with: .slide))
        .animation(.easeInOut(duration: 0.6), value: momentumIndex)
    }

    private func startMomentumTimer() {
        momentumTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            withAnimation { momentumIndex = (momentumIndex + 1) % momentumMessages.count }
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("nAIce")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                Text("Ubersicht")
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
    }

    // MARK: - Feature 1+3: Quadranten mit Inline-Expand + Sparklines
    private var quadGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            quadTile(id: "health", label: "Gesundheit", value: rollup.whoop?.recovery.map { "\($0.score)%" } ?? "--", sub: recoverySub(), icon: "heart.fill", color: .ncNeonGreen, sparkValues: sparkHealth())
            quadTile(id: "tasks", label: "Aufgaben", value: "\(rollup.tasks?.active ?? 0)", sub: "offene Tasks", icon: "checklist", color: .ncAmber, sparkValues: sparkTasks())
            quadTile(id: "whatsapp", label: "WhatsApp", value: "\(waVM.unrepliedChats.count)", sub: waVM.unrepliedChats.isEmpty ? "Alles erledigt" : "unbeantwortet", icon: "message.fill", color: .ncRose, sparkValues: sparkWA())
            quadTile(id: "score", label: "Life Score", value: "\(computeLifeScore())", sub: "Aktuell", icon: "sparkle", color: .ncCyan, sparkValues: sparkScore())
        }
        .padding(.horizontal, 16)
    }

    private func quadTile(id: String, label: String, value: String, sub: String, icon: String, color: Color, sparkValues: [CGFloat]) -> some View {
        let isExpanded = expandedQuadrant == id
        return VStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    expandedQuadrant = isExpanded ? nil : id
                }
            }) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(label.uppercased()).font(.system(size: 9, weight: .medium)).foregroundColor(.gray).kerning(0.8)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 7)).foregroundColor(.gray.opacity(0.3))
                    }
                    Text(value).font(.system(size: 26, weight: .light)).foregroundColor(color).minimumScaleFactor(0.6).lineLimit(1)
                    // Feature 3: Sparkline
                    sparkline(values: sparkValues, color: color)
                        .frame(height: 16).padding(.top, 2)
                    Text(sub).font(.system(size: 9)).foregroundColor(.gray).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).stroke(isExpanded ? color.opacity(0.25) : color.opacity(0.1), lineWidth: isExpanded ? 1 : 0.5).background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.02, green: 0.02, blue: 0.04))))
            }
            .buttonStyle(.plain)

            // Feature 1: Inline-Expand
            if isExpanded {
                expandedContent(for: id, color: color)
                    .padding(.horizontal, 12).padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(isExpanded ? 0.25 : 0.1), lineWidth: isExpanded ? 1 : 0.5))
        )
    }

    // Feature 3: Sparkline
    private func sparkline(values: [CGFloat], color: Color) -> some View {
        Canvas { ctx, size in
            guard values.count > 1 else { return }
            let maxV = values.max() ?? 1
            let minV = values.min() ?? 0
            let range = max(maxV - minV, 1)
            let w = size.width
            let h = size.height - 2
            let stepX = w / CGFloat(values.count - 1)

            var path = Path()
            path.move(to: CGPoint(x: 0, y: h - ((values[0] - minV) / range) * h + 1))
            for i in 1..<values.count {
                path.addLine(to: CGPoint(x: CGFloat(i) * stepX, y: h - ((values[i] - minV) / range) * h + 1))
            }
            ctx.stroke(path, with: .color(color.opacity(0.6)), lineWidth: 1.2)

            // Gradient fill
            var fillPath = path
            if let last = values.last {
                fillPath.addLine(to: CGPoint(x: w, y: h + 1))
                fillPath.addLine(to: CGPoint(x: 0, y: h + 1))
                fillPath.closeSubpath()
                ctx.fill(fillPath, with: .linearGradient(
                    Gradient(colors: [color.opacity(0.12), .clear]),
                    startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: h)
                ))
            }
        }
        .frame(height: 16)
    }

    // Feature 1: Expanded quadrant content
    @ViewBuilder
    private func expandedContent(for id: String, color: Color) -> some View {
        switch id {
        case "health": healthExpanded
        case "tasks": tasksExpanded
        case "whatsapp": waExpanded
        case "score": scoreExpanded
        default: EmptyView()
        }
    }

    private var healthExpanded: some View {
        VStack(spacing: 6) {
            if let w = rollup.whoop {
                if let r = w.recovery {
                    row("Recovery", "\(r.score)%", r.score > 65 ? .ncNeonGreen : r.score > 40 ? .ncAmber : .ncRose)
                    row("HRV", "\(r.hrv)ms", .white)
                    row("Ruhepuls", "\(r.rhr) bpm", .white)
                }
                if let s = w.sleep {
                    row("Schlaf", String(format: "%.1fh", s.net_hours), .white)
                    row("Tiefschlaf", "\(s.deep_minutes)min", .ncCyan)
                    row("REM", "\(s.rem_minutes)min", .ncNeonGreen)
                }
                if let c = w.cycle, let strain = c.strain {
                    row("Strain", String(format: "%.1f", strain), strain > 15 ? .ncAmber : .white)
                }
            }
        }
    }

    private var tasksExpanded: some View {
        VStack(spacing: 6) {
            if let t = rollup.tasks {
                row("Aktiv", "\(t.active)", .ncAmber)
                row("Gesamt", "\(t.total)", .white)
                if let tasks = t.tasks {
                    ForEach(tasks.prefix(3)) { task in
                        HStack(spacing: 6) {
                            Circle().fill(Color.ncAmber).frame(width: 4, height: 4)
                            Text(task.title).font(.system(size: 10)).foregroundColor(.gray).lineLimit(1)
                            Spacer()
                            if let p = task.priority {
                                Text(p).font(.system(size: 8)).foregroundColor(.ncAmber)
                            }
                        }
                    }
                }
            }
        }
    }

    private var waExpanded: some View {
        VStack(spacing: 6) {
            if waVM.unrepliedChats.isEmpty {
                Text("Keine unbeantworteten Nachrichten").font(.system(size: 10)).foregroundColor(.gray)
            } else {
                ForEach(Array(waVM.unrepliedChats.prefix(3))) { chat in
                    HStack(spacing: 6) {
                        Circle().fill(Color.ncNeonGreen).frame(width: 4, height: 4)
                        Text(chat.contact).font(.system(size: 10)).foregroundColor(.white).lineLimit(1)
                        Spacer()
                        if let text = chat.lastIncomingText?.prefix(20) {
                            Text(text).font(.system(size: 8)).foregroundColor(.gray).lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    private var scoreExpanded: some View {
        VStack(spacing: 6) {
            let score = computeLifeScore()
            HStack {
                Text("Health").font(.system(size: 10)).foregroundColor(.gray)
                Spacer()
                Text("+\(score > 50 ? score - 50 : 0) Pkt").font(.system(size: 10)).foregroundColor(.ncNeonGreen)
            }
            HStack {
                Text("Tasks").font(.system(size: 10)).foregroundColor(.gray)
                Spacer()
                Text(rollup.tasks?.active == 0 ? "+10 Pkt" : "\(rollup.tasks?.active ?? 0) offen").font(.system(size: 10)).foregroundColor(rollup.tasks?.active == 0 ? .ncNeonGreen : .ncAmber)
            }
            HStack {
                Text("WhatsApp").font(.system(size: 10)).foregroundColor(.gray)
                Spacer()
                Text(waVM.unrepliedChats.isEmpty ? "+5 Pkt" : "\(waVM.unrepliedChats.count) unbeantwortet").font(.system(size: 10)).foregroundColor(waVM.unrepliedChats.isEmpty ? .ncNeonGreen : .ncRose)
            }
        }
    }

    private func row(_ label: String, _ value: String, _ vColor: Color) -> some View {
        HStack {
            Text(label).font(.system(size: 10)).foregroundColor(.gray)
            Spacer()
            Text(value).font(.system(size: 10).weight(.medium)).foregroundColor(vColor)
        }
    }

    // MARK: - Feature 2: Timeline (Jetzt wichtig)
    private var mainArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Jetzt wichtig")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                let total = timelineItems().count
                if total > 0 {
                    Text("\(total) Eintrage")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            if timelineItems().isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 14)).foregroundColor(.ncNeonGreen)
                    Text("Alles ruhig – keine offenen Punkte").font(.subheadline).foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            } else {
                ForEach(Array(timelineItems().enumerated()), id: \.offset) { i, item in
                    timelineRow(item: item)
                    if i < timelineItems().count - 1 {
                        Divider().overlay(Color.white.opacity(0.04)).padding(.leading, 44)
                    }
                }
            }

            Text("Rollup: \(rollup.rollup?.ts.prefix(16) ?? "–")")
                .font(.system(size: 8))
                .foregroundColor(.gray.opacity(0.5))
                .padding(.horizontal, 16)
                .padding(.top, 6).padding(.bottom, 10)
        }
        .background(Color(red: 0.02, green: 0.02, blue: 0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        .padding(.horizontal, 16)
    }

    private struct TimelineItem {
        let icon: String
        let iconColor: Color
        let title: String
        let subtitle: String
        let time: String
    }

    private func timelineItems() -> [TimelineItem] {
        var items: [TimelineItem] = []

        // Morning briefing
        if let crm = rollup.rollup?.crm, let briefings = crm.briefings, let today = briefings.today, !today.isEmpty {
            items.append(TimelineItem(icon: "sunrise.fill", iconColor: .ncAmber, title: "Morning Briefing", subtitle: "\(today.count) \(today.count == 1 ? "Eintrag" : "Eintrage")", time: "07:00"))
        }

        // Tasks
        if let t = rollup.tasks, t.active > 0 {
            items.append(TimelineItem(icon: "checklist", iconColor: .ncAmber, title: "\(t.active) Aufgaben offen", subtitle: "\(t.total) gesamt", time: "laufend"))
        }

        // WhatsApp
        if waVM.unrepliedChats.count > 0 {
            let name = waVM.unrepliedChats.first?.contact ?? "Jemand"
            items.append(TimelineItem(icon: "message.fill", iconColor: .ncNeonGreen, title: "WhatsApp von \(name)", subtitle: "\(waVM.unrepliedChats.count) Nachricht\(waVM.unrepliedChats.count == 1 ? "" : "en")", time: "jetzt"))
        }

        // Flags
        for flag in rollup.flags.prefix(2) {
            let color: Color = flag.level == "red" ? .ncRose : flag.level == "yellow" ? .ncAmber : .ncNeonGreen
            let icon = flag.level == "red" ? "exclamationmark.triangle.fill" : flag.level == "yellow" ? "exclamationmark.circle.fill" : "checkmark.circle.fill"
            items.append(TimelineItem(icon: icon, iconColor: color, title: flag.text, subtitle: "", time: "aktiv"))
        }

        // Sleep
        if let s = rollup.whoop?.sleep {
            items.append(TimelineItem(icon: "moon.stars.fill", iconColor: .ncCyan, title: "Schlaf \(String(format: "%.1f", s.net_hours))h", subtitle: "\(s.deep_minutes)min Tief · \(s.rem_minutes)min REM", time: "letzte Nacht"))
        }

        return items
    }

    private func timelineRow(item: TimelineItem) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(item.iconColor.opacity(0.12))
                    .frame(width: 24, height: 24)
                Image(systemName: item.icon).font(.system(size: 10)).foregroundColor(item.iconColor)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).font(.subheadline).foregroundColor(.white)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle).font(.caption).foregroundColor(.gray)
                }
            }
            Spacer()
            Text(item.time).font(.system(size: 9)).foregroundColor(.gray.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Quick Bar & Areas (unchanged)
    private var quickBar: some View {
        HStack(spacing: 6) {
            quickButton(icon: "ellipsis.bubble.fill", label: "Chat", color: .ncCyan)
            quickButton(icon: "folder.fill", label: "Dateien", color: .ncPurple)
            quickButton(icon: "heart.fill", label: "Health", color: .ncNeonGreen)
            quickButton(icon: "target", label: "Ziele", color: .ncAmber)
            quickButton(icon: "note.text", label: "Notizen", color: .ncBlue)
        }
        .padding(.horizontal, 16)
    }

    private func quickButton(icon: String, label: String, color: Color) -> some View {
        NavigationLink(destination: quickDestination(label)) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 20)).foregroundColor(color)
                Text(label).font(.system(size: 8)).foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.05), lineWidth: 0.5).background(RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.02, green: 0.02, blue: 0.04))))
        }
        .buttonStyle(.plain)
    }

    private func quickDestination(_ label: String) -> AnyView {
        switch label {
        case "Dateien": return AnyView(NAIceFilesView())
        case "Health": return AnyView(HealthDetailView())
        case "Ziele": return AnyView(NALifeGoalsView())
        case "Notizen": return AnyView(NANotesView())
        default: return AnyView(EmptyView())
        }
    }

    private var areasSection: some View {
        VStack(spacing: 0) {
            Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showAllAreas.toggle() } } label: {
                HStack {
                    Image(systemName: "square.grid.2x2").font(.system(size: 12)).foregroundColor(.gray)
                    Text("Alle Bereiche (\(showAllAreas ? "ausblenden" : "16 anzeigen"))")
                        .font(.subheadline.weight(.medium)).foregroundColor(.gray)
                    Spacer()
                    Image(systemName: showAllAreas ? "chevron.up" : "chevron.down").font(.system(size: 10)).foregroundColor(.gray.opacity(0.4))
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if showAllAreas {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    areaTile("heart.fill", "Gesundheit", .ncRose, HealthDetailView())
                    areaTile("briefcase.fill", "Arbeit", .ncCyan, WorkDetailView())
                    areaTile("person.2.fill", "Beziehungen", .ncNeonGreen, RelationsDetailView())
                    areaTile("lightbulb.fill", "Kreativitat", .ncAmber, CreativityDetailView(naice: NAiceAPI.shared))
                    areaTile("house.fill", "Alltag", .ncBlue, DailyDetailView())
                    areaTile("camera.viewfinder", "Scanner", .ncCyan, NACameraView())
                    areaTile("figure.walk", "Habits", .ncNeonGreen, NAHabitsView())
                    areaTile("building.2.fill", "Unternehmen", .ncAmber, NACompaniesView())
                    areaTile("tray.fill", "Posteingang", .ncNeonGreen, NAUnifiedInboxView())
                    areaTile("homekit", "Smart Home", .ncAmber, NASmartHomeView())
                    areaTile("apple.terminal", "Mac Agent", .ncPurple, NAMacAgentView())
                    areaTile("bolt.shield.fill", "Service", .ncNeonGreen, NAServiceStatusView())
                    areaTile("brain.head.profile", "Modell", .ncCyan, NAProfileView())
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Color(red: 0.02, green: 0.02, blue: 0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        .padding(.horizontal, 16)
    }

    private func areaTile<Content: View>(_ icon: String, _ label: String, _ color: Color, _ dest: Content) -> some View {
        NavigationLink(destination: dest) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12)).frame(width: 32, height: 32)
                    Image(systemName: icon).font(.system(size: 14)).foregroundColor(color)
                }
                Text(label).font(.subheadline).foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 9)).foregroundColor(.gray.opacity(0.3))
            }
            .padding(10)
            .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sparkline Data Generators
    private func sparkHealth() -> [CGFloat] {
        let base = CGFloat(rollup.whoop?.recovery?.score ?? 70)
        return (0..<7).map { i in
            base + CGFloat(Int.random(in: -12...12)) + CGFloat(i) * 0.5
        }
    }
    private func sparkTasks() -> [CGFloat] {
        let base = CGFloat(rollup.tasks?.active ?? 4)
        return (0..<7).map { i in
            max(0, base + CGFloat(Int.random(in: -3...3)) - CGFloat(i) * 0.2)
        }
    }
    private func sparkWA() -> [CGFloat] {
        let base = CGFloat(waVM.unrepliedChats.count)
        return (0..<7).map { i in
            max(0, base + CGFloat(Int.random(in: -2...2)) + CGFloat(i) * 0.1)
        }
    }
    private func sparkScore() -> [CGFloat] {
        let base = CGFloat(computeLifeScore())
        return (0..<7).map { i in
            base + CGFloat(Int.random(in: -8...8)) + CGFloat(i) * 0.3
        }
    }

    // MARK: - Helpers
    private func recoverySub() -> String {
        guard let w = rollup.whoop?.recovery else { return "–" }
        var parts: [String] = []
        if w.hrv > 0 { parts.append("HRV \(w.hrv)ms") }
        return parts.isEmpty ? "" : parts.joined(separator: " · ")
    }

    private func computeLifeScore() -> Int {
        var score = 50
        if let rec = rollup.whoop?.recovery?.score { score += Int(Double(rec - 30) * 0.5) }
        if let t = rollup.tasks, t.active == 0 { score += 10 }
        if waVM.unrepliedChats.isEmpty { score += 5 }
        return min(max(score, 0), 100)
    }

    private func refreshAll() async {
        await rollup.fetch()
        await NAJournalService.shared.fetch()
        await goals.fetch()
        await companies.fetch()
        await waVM.fetchPending()
        proactive.generate()
    }
}

// MARK: - Scroll Offset Key
struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}