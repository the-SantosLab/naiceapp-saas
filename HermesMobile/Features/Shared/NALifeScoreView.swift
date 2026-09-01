import SwiftUI

// MARK: - Life Score Dashboard (Einer-Blick)
struct NALifeScoreView: View {
    @ObservedObject private var health = HealthManager.shared
    @ObservedObject private var rollup = NARollupService.shared
    @ObservedObject private var finance = NAFinanceService.shared
    @ObservedObject private var goals = NAGoalService.shared
    @ObservedObject private var waVM = WhatsAppViewModel.shared
    @ObservedObject private var companies = NACompanyService.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                scoreRing
                healthSection
                tasksSection
                financeSection
                goalsSection
                socialSection
                if !companies.companies.isEmpty { companiesSection }
                if !proactiveBriefing.isEmpty { briefingBar }
            }
            .padding(.bottom, 30)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Score
    private var scoreValue: Int {
        let rec = rollup.whoop?.recovery?.score ?? 50
        let tasks = rollup.tasks?.active ?? 0
        let goalAvg = goals.activeGoals.isEmpty ? 1.0 : goals.activeGoals.reduce(0.0) { $0 + $1.progress } / Double(max(goals.activeGoals.count, 1))
        let unread = waVM.unrepliedChats.count
        let h = min(20, Int(rec / 5))
        let t = min(20, max(0, 20 - tasks * 2))
        let g = Int(goalAvg * 20)
        let s = min(20, max(0, 20 - unread * 3))
        return min(100, max(0, h + t + 20 + g + s))
    }

    private var scoreColor: Color {
        scoreValue >= 80 ? .ncNeonGreen : scoreValue >= 50 ? .ncAmber : .ncRose
    }

    private var scoreLabel: String {
        scoreValue >= 90 ? "Hervorragend 🌟" : scoreValue >= 70 ? "Gut 👍" : scoreValue >= 50 ? "In Ordnung 😐" : scoreValue >= 30 ? "Verbesserungswürdig ⚠️" : "Achtung 🚨"
    }

    private var scoreRing: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.06), lineWidth: 8).frame(width: 80, height: 80)
                Circle().trim(from: 0, to: CGFloat(scoreValue) / 100.0).stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round)).frame(width: 80, height: 80).rotationEffect(.degrees(-90))
                Text("\(scoreValue)").font(.title.weight(.bold)).foregroundColor(.white)
            }
            Text("Life Score").font(.caption).foregroundColor(.gray)
            Text(scoreLabel).font(.caption2).foregroundColor(scoreColor)
        }
        .padding(.top, 8)
    }

    private var healthSection: some View {
        sectionCard(icon: "heart.fill", title: "Gesundheit", color: .ncRose) {
            HStack(spacing: 16) {
                if let rec = rollup.whoop?.recovery {
                    item("\(rec.score ?? 0)%", "Recovery", recColor(rec.score ?? 0))
                    item("\(rec.hrv ?? 0)", "HRV", .ncCyan)
                }
                item("\(health.steps)", "Schritte", .ncNeonGreen)
            }
        }
    }

    private var tasksSection: some View {
        sectionCard(icon: "checklist", title: "Aufgaben", color: .ncAmber) {
            if let t = rollup.tasks {
                HStack(spacing: 16) {
                    item("\(t.active)", "Offen", .ncAmber)
                    item("\(t.total)", "Gesamt", .ncCyan)
                }
            }
        }
    }

    private var financeSection: some View {
        sectionCard(icon: "dollarsign.circle.fill", title: "Finanzen", color: .ncNeonGreen) {
            HStack(spacing: 16) {
                item("\(Int(finance.expenses.reduce(0) { $0 + $1.amount }))€", "Ausgaben", .ncRose)
                item("\(Int(finance.incomeTotal))€", "Einnahmen", .ncNeonGreen)
            }
        }
    }

    private var goalsSection: some View {
        sectionCard(icon: "target", title: "Ziele", color: .ncCyan) {
            if goals.activeGoals.isEmpty {
                Text("Keine aktiven Ziele").font(.caption).foregroundColor(.gray)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(goals.activeGoals.prefix(6)) { goal in
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle().stroke(Color.white.opacity(0.06), lineWidth: 4).frame(width: 32, height: 32)
                                    Circle().trim(from: 0, to: CGFloat(goal.progress)).stroke(goal.colorSwift, style: StrokeStyle(lineWidth: 4, lineCap: .round)).frame(width: 32, height: 32).rotationEffect(.degrees(-90))
                                    Image(systemName: goal.icon).font(.system(size: 10)).foregroundColor(goal.colorSwift)
                                }
                                Text("\(goal.progressPercent)%").font(.system(size: 9)).foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
        }
    }

    private var socialSection: some View {
        sectionCard(icon: "message.fill", title: "Kommunikation", color: .ncPurple) {
            let unread = waVM.unrepliedChats.count
            HStack(spacing: 16) {
                item("\(unread)", "WhatsApp offen", unread > 0 ? .ncRose : .ncNeonGreen)
            }
        }
    }

    private var companiesSection: some View {
        sectionCard(icon: "building.2.fill", title: "Unternehmen", color: .ncAmber) {
            HStack(spacing: 12) {
                ForEach(companies.companies.prefix(4)) { co in
                    VStack(spacing: 4) {
                        Text(co.logoEmoji).font(.title2)
                        Text("\(Int(co.revenueMtd))/\(Int(co.revenueGoalMtd))€").font(.system(size: 8)).foregroundColor(.gray)
                    }
                }
            }
        }
    }

    private var proactiveBriefing: String {
        let p = NAProactiveService.shared
        p.generateBriefing()
        return p.briefing
    }

    private var briefingBar: some View {
        HStack {
            Image(systemName: "sparkle").font(.caption).foregroundColor(.ncAmber)
            Text(proactiveBriefing).font(.caption).foregroundColor(.gray)
            Spacer()
        }
        .padding(12).background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    // MARK: - Reusable Components
    private func sectionCard(icon: String, title: String, color: Color, @ViewBuilder content: @escaping () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption).foregroundColor(color)
                Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.white)
            }
            content()
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        .padding(.horizontal, 16)
    }

    private func item(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.weight(.bold)).foregroundColor(color)
            Text(label).font(.system(size: 9)).foregroundColor(.gray)
        }
    }

    private func recColor(_ s: Int) -> Color {
        s >= 60 ? .ncNeonGreen : s >= 33 ? .ncAmber : .ncRose
    }
}