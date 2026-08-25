import SwiftUI
import SwiftData

// MARK: - Life Dashboard (Analyse-Tab)
struct NAIceLifeView: View {
    @ObservedObject var services: ServiceManager
    @ObservedObject private var rollup = NARollupService.shared
    @ObservedObject private var contacts = NAContactService.shared
    @ObservedObject private var finance = NAFinanceService.shared
    @ObservedObject private var calendarManager = CalendarManager.shared
    @ObservedObject private var health = HealthManager.shared
    @ObservedObject private var waVM = WhatsAppViewModel.shared
    @StateObject private var vm = LifeViewModel()
    @Query(sort: \HabitLog.date, order: .reverse) var habits: [HabitLog]
    @Query(sort: \Expense.date, order: .reverse) var expenses: [Expense]
    @Environment(\.modelContext) private var mc

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Life Dashboard")
                                .font(.title2.weight(.bold))
                                .foregroundColor(.white)
                            Text("Verstehen, wie dein Leben läuft.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // Section 1: Amelias Impression
                    ImpressionCard(text: vm.impressionText, isLoading: rollup.isLoading)

                    // Section 2: Life Balance Radar
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "circle.hexagongrid.fill")
                                .font(.caption)
                                .foregroundColor(.ncCyan)
                            Text("Life Balance")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(vm.overallScore)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(overallScoreColor(vm.overallScore))
                        }
                        .padding(.horizontal, 4)

                        RadarChart(dimensions: vm.dimensions)

                        // Dimensionen als Liste
                        VStack(spacing: 8) {
                            ForEach(vm.dimensions) { dim in
                                dimensionRow(dim)
                            }
                        }

                        // Gesamt-Score
                        HStack {
                            Spacer()
                            Text("Ø Gesamt: \(vm.overallScore)%")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(overallScoreColor(vm.overallScore))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(overallScoreColor(vm.overallScore).opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    )
                    .padding(.horizontal, 16)

                    // Section 3: Nächste 24h
                    TimelineCard(items: vm.timelineItems)
                        .padding(.horizontal, 16)

                    // Section 4: Weekly Trend
                    TrendCard(
                        recoveryData: vm.trendRecoveryData,
                        journalCount: vm.trendJournalCount,
                        dealChange: vm.trendDealChange,
                        workoutCount: vm.trendWorkoutCount,
                        weekSummary: vm.weekSummary
                    )
                    .padding(.horizontal, 16)

                    // Section 5: QuickLog
                    QuickLogSection(mc: mc, habits: habits, expenses: expenses)

                    // Section 6: Bereichs-Kacheln (2x2)
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.grid.2x2")
                                .font(.caption)
                                .foregroundColor(.ncCyan)
                            Text("Bereiche")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 4)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            areaTile(icon: "heart.fill", label: "Gesundheit", color: .ncRose, detail: healthText(), dest: AnyView(HealthDetailView()))
                            areaTile(icon: "eurosign", label: "Finanzen", color: .ncAmber, detail: "\(Int(finance.monthlyTotal))€ diesen Monat", dest: AnyView(FinanceDetailView()))
                            areaTile(icon: "person.2.fill", label: "Menschen", color: .ncNeonGreen, detail: "\(contacts.contacts.count) Kontakte", dest: AnyView(RelationsDetailView()))
                            areaTile(icon: "arrow.trianglehead.clockwise", label: "Gewohnheiten", color: .ncCyan, detail: "\(habits.filter { Calendar.current.isDateInToday($0.date) }.count) heute", dest: AnyView(NAIceHabitsView()))
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
                .padding(.bottom, 30)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await refresh() }
            .task { await refresh() }
        }
    }

    private func refresh() async {
        await rollup.fetch()
        if let r = rollup.rollup {
            vm.compute(from: r)
        }
    }

    private func overallScoreColor(_ s: Int) -> Color {
        s >= 70 ? .ncNeonGreen : s >= 40 ? .ncAmber : .ncRose
    }

    private func healthText() -> String {
        var parts: [String] = []
        if let r = rollup.whoop?.recovery?.score { parts.append("Recovery \(r)%") }
        if health.steps > 0 { parts.append("\(health.steps) Schritte") }
        return parts.isEmpty ? "Verbunden" : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func areaTile(icon: String, label: String, color: Color, detail: String, dest: AnyView) -> some View {
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
                Text(detail)
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func dimensionRow(_ dim: LifeDimension) -> some View {
        HStack(spacing: 10) {
            Text(dim.icon)
                .font(.system(size: 12))
            Text(dim.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 70, alignment: .leading)
            Text("\(dim.score)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(dim.color)
                .frame(width: 28, alignment: .trailing)
            ProgressView(value: Double(dim.score) / 100)
                .tint(dim.color)
                .scaleEffect(x: 1, y: 0.6)
            Image(systemName: dim.trend.rawValue)
                .font(.system(size: 8))
                .foregroundColor(dim.color == .ncNeonGreen ? .ncNeonGreen : dim.color == .ncAmber ? .ncAmber : .ncRose)
            Text(dim.detail)
                .font(.system(size: 8))
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .padding(.horizontal, 4)
    }

    func naBadge(_ icon: String, _ label: String, _ connected: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 8))
            Text(label).font(.system(size: 9))
        }
        .foregroundColor(connected ? .ncNeonGreen : .gray)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background((connected ? Color.ncNeonGreen : Color.gray).opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke((connected ? Color.ncNeonGreen : Color.gray).opacity(0.2), lineWidth: 0.5))
    }
}

// MARK: - QuickLog Section
struct QuickLogSection: View {
    let mc: ModelContext
    let habits: [HabitLog]
    let expenses: [Expense]

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .font(.caption)
                    .foregroundColor(.ncCyan)
                Text("QuickLog")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 4)

            VStack(spacing: 10) {
                QuickLogRow(icon: "face.smiling", label: "Stimmung", done: false, action: {
                    let h = HabitLog(date: Date(), habit: "mood", isCompleted: true, note: "gut")
                    mc.insert(h)
                })

                QuickLogRow(icon: "arrow.trianglehead.clockwise", label: "Gewohnheit", done: false, action: {
                    let h = HabitLog(date: Date(), habit: "habit", isCompleted: true, note: "erledigt")
                    mc.insert(h)
                })

                QuickLogRow(icon: "eurosign", label: "Ausgabe", done: false, action: {
                    let e = Expense(date: Date(), amount: 0, category: "sonstiges", note: "")
                    mc.insert(e)
                })
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        )
        .padding(.horizontal, 16)
    }
}

struct QuickLogRow: View {
    let icon: String
    let label: String
    let done: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: done ? "checkmark.circle.fill" : icon)
                    .font(.system(size: 14))
                    .foregroundColor(done ? .ncNeonGreen : .gray)
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.white)
                Spacer()
                if done {
                    Text("Erledigt ✅")
                        .font(.caption)
                        .foregroundColor(.ncNeonGreen)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding(10)
            .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.03), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}