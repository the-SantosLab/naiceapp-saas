import SwiftUI
import SwiftData

struct NAIceLifeView: View {
    @ObservedObject var services: ServiceManager
    @Query(sort: \HabitLog.date, order: .reverse) var habits: [HabitLog]
    @Query(sort: \Expense.date, order: .reverse) var expenses: [Expense]
    @ObservedObject private var context = NAiceContext.shared
    @ObservedObject private var contacts = NAContactService.shared
    @ObservedObject private var finance = NAFinanceService.shared
    @ObservedObject private var calendar = CalendarManager.shared
    @Environment(\.modelContext) private var mc
    @State private var showHabitLog = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Leben").font(.title2.weight(.bold)).foregroundColor(.ncDark)
                    Text("Dein Leben auf einen Blick.").font(.subheadline).foregroundColor(.ncMuted)

                    // Life Balance
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().stroke(Color.ncSand.opacity(0.3), lineWidth: 5).frame(width: 56, height: 56)
                            Circle().trim(from: 0, to: CGFloat(context.lifeBalanceScore) / 100)
                                .stroke(Color.ncGreen, lineWidth: 5).frame(width: 56, height: 56).rotationEffect(.degrees(-90))
                            Text("\(context.lifeBalanceScore)").font(.system(size: 16, weight: .bold)).foregroundColor(.ncDark)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Life Balance").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                            Text(context.lifeBalanceScore > 70 ? "Gut im Flow!" : context.lifeBalanceScore > 40 ? "Ausgeglichen" : "Erholung fallig")
                                .font(.subheadline).foregroundColor(context.lifeBalanceScore > 70 ? .ncGreen : .ncMuted)
                        }
                        Spacer()
                    }.warmCard()

                    // Insights
                    if !context.crossInsights.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Einblicke").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                            ForEach(context.crossInsights.prefix(3), id: \.self) { ins in
                                Label(ins, systemImage: "lightbulb.fill")
                                    .font(.caption).foregroundColor(.ncDark)
                            }
                        }.warmCard()
                    }

                    // Gesundheit
                    NavigationLink(destination: HealthDetailView()) {
                        HStack(spacing: 10) {
                            Image(systemName: "heart.fill").font(.title3).foregroundColor(.ncGreen)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Gesundheit").font(.subheadline.weight(.semibold)).foregroundColor(.ncDark)
                                Text(healthText()).font(.caption).foregroundColor(.ncMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption2).foregroundColor(.ncSand)
                        }
                    }.warmCard().buttonStyle(.plain)

                    // Finanzen
                    NavigationLink(destination: FinanceDetailView()) {
                        HStack(spacing: 10) {
                            Image(systemName: "eurosign").font(.title3).foregroundColor(.ncGold)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Finanzen").font(.subheadline.weight(.semibold)).foregroundColor(.ncDark)
                                Text("\(Int(finance.monthlyTotal))€ diesen Monat").font(.caption).foregroundColor(.ncMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption2).foregroundColor(.ncSand)
                        }
                    }.warmCard().buttonStyle(.plain)

                    // Gewohnheiten
                    NavigationLink(destination: NAIceHabitsView()) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "arrow.trianglehead.clockwise").font(.title3).foregroundColor(.ncSage)
                                Text("Gewohnheiten").font(.subheadline.weight(.semibold)).foregroundColor(.ncDark)
                                Spacer()
                                Text("\(habits.filter { Calendar.current.isDateInToday($0.date) }.count) heute")
                                    .font(.caption2).foregroundColor(.ncMuted)
                            }
                            if let first = context.routines.suggestions.first {
                                Text(first).font(.caption).foregroundColor(.ncMuted)
                            }
                        }
                    }.warmCard().buttonStyle(.plain)

                    // Menschen
                    NavigationLink(destination: RelationsDetailView()) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "person.2.fill").font(.title3).foregroundColor(.ncSage)
                                Text("Menschen").font(.subheadline.weight(.semibold)).foregroundColor(.ncDark)
                                Spacer()
                                Text("\(contacts.contacts.count) Kontakte")
                                    .font(.caption2).foregroundColor(.ncMuted)
                            }
                            let bdays = contacts.upcomingBirthdays
                            if bdays.isEmpty {
                                Text("Keine bevorstehenden Geburtstage.").font(.caption).foregroundColor(.ncMuted)
                            } else {
                                ForEach(bdays.prefix(2), id: \.0.id) { c, d, ds in
                                    Label("\(c.fullName) in \(d) Tagen (\(ds))", systemImage: "star.fill")
                                        .font(.caption).foregroundColor(.ncGold)
                                }
                            }
                        }
                    }.warmCard().buttonStyle(.plain)

                    // WhatsApp offen
                    if WhatsAppViewModel.shared.totalUnread > 0 {
                        NavigationLink(destination: RelationsDetailView()) {
                            HStack(spacing: 10) {
                                Image(systemName: "message.fill").font(.title3).foregroundColor(.ncGreen)
                                Text("\(WhatsAppViewModel.shared.totalUnread) WhatsApp unbeantwortet")
                                    .font(.subheadline.weight(.semibold)).foregroundColor(.ncDark)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption2).foregroundColor(.ncSand)
                            }
                        }.warmCard().buttonStyle(.plain)
                    }

                    // QuickLog
                    QuickLogCard(mc: mc)

                    // Apple Daten Badges
                    HStack(spacing: 6) {
                        naBadge("heart.fill", "Health", HealthManager.shared.isAuthorized)
                        naBadge("calendar", "Kalender", CalendarManager.shared.isAuthorized)
                        naBadge("person.2.fill", "Kontakte", services.contactsAuthorized)
                        naBadge("location.fill", "Standort", services.locationAuthorized)
                        naBadge("bell.fill", "Erinnerungen", services.remindersAuthorized)
                    }.warmCard()

                    // AI-Tipp
                    VStack(spacing: 8) {
                        Text("AI-Tipp").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                        if !context.crossInsights.isEmpty {
                            ForEach(context.crossInsights.prefix(1), id: \.self) { ins in
                                Label(ins, systemImage: "lightbulb.fill").font(.subheadline).foregroundColor(.ncMuted)
                            }
                        } else if let first = context.agentSuggestions.first {
                            Text(first.text).font(.subheadline).foregroundColor(.ncMuted)
                        } else {
                            Text("Deine Daten werden verarbeitet.").font(.subheadline).foregroundColor(.ncMuted)
                        }
                    }.warmCard()
                }
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
            }
            .warmBackground()
            .navigationTitle("Leben")
            .navigationBarTitleDisplayMode(.inline)
            .task { await contacts.fetchContacts() }
        }
    }

    private func healthText() -> String {
        var parts: [String] = []
        if let r = context.rollup.whoop?.recovery?.score { parts.append("Recovery \(r)%") }
        if context.health.steps > 0 { parts.append("\(context.health.steps) Schritte") }
        let eCount = calendar.upcomingEvents.count
        if eCount > 0 { parts.append("\(eCount) Termine") }
        return parts.isEmpty ? "Verbunden" : parts.joined(separator: " · ")
    }

    func naBadge(_ icon: String, _ label: String, _ connected: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 8))
            Text(label).font(.system(size: 9))
        }
        .foregroundColor(connected ? .ncGreen : .ncSand)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background((connected ? Color.ncGreen : Color.ncSand).opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke((connected ? Color.ncGreen : Color.ncSand).opacity(0.2), lineWidth: 0.5))
    }
}