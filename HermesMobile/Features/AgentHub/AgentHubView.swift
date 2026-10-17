import SwiftUI
import SwiftData

// MARK: - Clean Home Tab (V3 Minimal)
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

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                heroSection
                    .padding(.top, 20)
                    .padding(.bottom, 44)
                focusSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                shortcutsSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                areasSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 60)
            }
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
        .sheet(isPresented: $showLifeScore) { NavigationStack { NALifeScoreView() } }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Text("nAIce")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .kerning(-0.3)
            Spacer()
            Text(rollup.isLoading ? "..." : "Live")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.15))
        }
    }

    // MARK: - Hero
    private var heroSection: some View {
        VStack(spacing: 0) {
            Text("\(computeLifeScore())")
                .font(.system(size: 72, weight: .ultraLight))
                .foregroundColor(.white)
                .kerning(-3)
            Text("Life Score")
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.white.opacity(0.2))
                .padding(.top, 2)
            Text(heroSubtitle())
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.white.opacity(0.3))
                .padding(.top, 12)
        }
    }

    private func heroSubtitle() -> String {
        var parts: [String] = []
        if let rec = rollup.whoop?.recovery?.score { parts.append("Erholung \(rec)%") }
        if let t = rollup.tasks, t.active > 0 { parts.append("\(t.active) Tasks offen") }
        if waVM.unrepliedChats.count > 0 { parts.append("\(waVM.unrepliedChats.count) WhatsApp") }
        return parts.isEmpty ? "Keine Daten" : parts.joined(separator: " · ")
    }

    // MARK: - Focus Section
    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Was ansteht")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.2))
                .padding(.bottom, 12)

            let items = focusItems()
            if items.isEmpty {
                HStack(spacing: 10) {
                    Circle().fill(Color.ncNeonGreen).frame(width: 5, height: 5)
                    Text("Alles ruhig")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.vertical, 6)
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    HStack(spacing: 10) {
                        Circle().fill(item.color).frame(width: 5, height: 5)
                        Text(item.title)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        if let count = item.count {
                            Text(count)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.15))
                        }
                    }
                    .padding(.vertical, 6)
                    if i < items.count - 1 {
                        Divider().overlay(Color.white.opacity(0.04))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.02))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
        )
    }

    private struct FocusItem {
        let color: Color
        let title: String
        let count: String?
    }

    private func focusItems() -> [FocusItem] {
        var items: [FocusItem] = []
        if let t = rollup.tasks, t.active > 0 {
            items.append(FocusItem(color: .ncAmber, title: "\(t.active) Aufgaben offen", count: "\(t.total)"))
        }
        if waVM.unrepliedChats.count > 0 {
            let name = waVM.unrepliedChats.first?.contact ?? "Jemand"
            items.append(FocusItem(color: .ncNeonGreen, title: "WhatsApp von \(name)", count: "\(waVM.unrepliedChats.count)"))
        }
        if let s = rollup.whoop?.sleep, s.net_hours < 6 {
            items.append(FocusItem(color: .ncRose, title: "Schlafdefizit \(String(format: "%.1f", s.net_hours))h", count: "⚠️"))
        }
        if items.count < 3, let flag = rollup.flags.first {
            items.append(FocusItem(
                color: flag.level == "red" ? .ncRose : flag.level == "yellow" ? .ncAmber : .ncNeonGreen,
                title: flag.text,
                count: nil
            ))
        }
        return Array(items.prefix(3))
    }

    // MARK: - Shortcuts
    private var shortcutsSection: some View {
        HStack(spacing: 5) {
            shortcutButton(icon: "ellipsis.bubble.fill", label: "Chat")
            shortcutButton(icon: "folder.fill", label: "Dateien")
            shortcutButton(icon: "checklist", label: "Aufgaben")
            shortcutButton(icon: "tray.fill", label: "Posteingang")
            shortcutButton(icon: "note.text", label: "Notizen")
        }
    }

    private func shortcutButton(icon: String, label: String) -> some View {
        NavigationLink(destination: shortcutDestination(label)) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 20)).foregroundColor(.white.opacity(0.5))
                Text(label).font(.system(size: 8)).foregroundColor(.white.opacity(0.2))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.02)))
        }
        .buttonStyle(.plain)
    }

    private func shortcutDestination(_ label: String) -> AnyView {
        switch label {
        case "Dateien": return AnyView(NAIceFilesView())
        case "Aufgaben": return AnyView(NAIceTasksView())
        case "Posteingang": return AnyView(NAUnifiedInboxView())
        case "Notizen": return AnyView(NANotesView())
        default: return AnyView(EmptyView())
        }
    }

    // MARK: - Areas
    private var areasSection: some View {
        VStack(spacing: 0) {
            Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showAllAreas.toggle() } } label: {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.15))
                        Text("Alle Bereiche")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    Spacer()
                    Image(systemName: showAllAreas ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.1))
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.02))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
                )
            }
            .buttonStyle(.plain)

            if showAllAreas {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    areaTile("building.2.fill", "Unternehmen", .ncAmber)
                    areaTile("briefcase.fill", "Arbeit", .ncCyan)
                    areaTile("person.2.fill", "CRM", .ncNeonGreen)
                    areaTile("folder.fill", "Dateien", .ncPurple)
                    areaTile("note.text", "Notizen", .ncBlue)
                    areaTile("checklist", "Aufgaben", .ncNeonGreen)
                    areaTile("tray.fill", "Posteingang", .ncNeonGreen)
                    areaTile("camera.viewfinder", "Scanner", .ncCyan)
                    areaTile("brain.head.profile", "Modell", .ncCyan)
                    areaTile("sparkles", "Reflection", .ncPurple)
                    areaTile("bolt.shield.fill", "Service", .ncNeonGreen)
                }
                .padding(.top, 12)
                .padding(.bottom, 4)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.02))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
        )
    }

    private func areaTile(_ icon: String, _ label: String, _ color: Color) -> some View {
        NavigationLink(destination: areaDestination(label)) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 14)).foregroundColor(color)
                Text(label).font(.system(size: 10)).foregroundColor(.white.opacity(0.4))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func areaDestination(_ label: String) -> AnyView {
        switch label {
        case "Unternehmen": return AnyView(NACompaniesView())
        case "Arbeit": return AnyView(WorkDetailView())
        case "CRM": return AnyView(NACRMDetailView())
        case "Dateien": return AnyView(NAIceFilesView())
        case "Notizen": return AnyView(NANotesView())
        case "Aufgaben": return AnyView(NAIceTasksView())
        case "Posteingang": return AnyView(NAUnifiedInboxView())
        case "Scanner": return AnyView(NACameraView())
        case "Modell": return AnyView(NAProfileView())
        case "Reflection": return AnyView(NAReflectionView())
        case "Service": return AnyView(NAServiceStatusView())
        default: return AnyView(EmptyView())
        }
    }

    // MARK: - Helpers
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
