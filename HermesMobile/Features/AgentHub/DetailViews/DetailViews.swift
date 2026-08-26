import SwiftUI
import EventKit

// MARK: - Health Detail View (WHOOP-Inspired)
struct HealthDetailView: View {
    @ObservedObject private var rollup = NARollupService.shared
    @ObservedObject var health = HealthManager.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gesundheit").font(.title2.weight(.bold)).foregroundColor(.white)
                        Text("Deine Vitaldaten auf einen Blick.").font(.subheadline).foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.top, 8)

                if let w = rollup.whoop {
                    whoopRingsSection(w)
                } else {
                    VStack(spacing: 16) {
                        ProgressView().tint(.ncCyan)
                        Text("WHOOP-Daten werden geladen...").font(.subheadline).foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 60)
                }
                if health.isAuthorized { healthMetricsSection }
                monitorsSection
                aiCard
            }
            .padding(.bottom, 30)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func whoopRingsSection(_ w: NAWhoopRollup) -> some View {
        VStack(spacing: 20) {
            HStack(spacing: 6) {
                Image(systemName: "circle.fill").font(.system(size: 6)).foregroundColor(.white)
                Text("WHOOP").font(.caption.weight(.semibold)).foregroundColor(.white.opacity(0.5)).tracking(1.5)
            }
            HStack(spacing: 12) {
                ringView(label: "Schlaf", value: w.sleep.map { Int($0.performance_pct ?? 0) } ?? 0, maxValue: 100, color: .cyan, icon: "moon.stars.fill", sub: w.sleep.map { String(format: "%.1f", $0.net_hours ?? 0) } ?? "-")
                ringView(label: "Erholung", value: w.recovery?.score ?? 0, maxValue: 100, color: recoveryColor(w.recovery?.score ?? 0), icon: "heart.fill", sub: w.recovery.map { "\($0.rhr) bpm" } ?? "-")
                ringView(label: "Belastung", value: min(Int((w.cycle?.strain ?? 0) * 20), 210), maxValue: 210, color: .blue, icon: "bolt.fill", sub: w.cycle.map { String(format: "%.1f", $0.strain ?? 0) } ?? "-")
            }
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.02, green: 0.02, blue: 0.04)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5)))
        .padding(.horizontal, 16)
    }

    private func ringView(label: String, value: Int, maxValue: Int, color: Color, icon: String, sub: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(color.opacity(0.15), lineWidth: 6).frame(width: 72, height: 72)
                Circle().trim(from: 0, to: min(CGFloat(value) / CGFloat(maxValue), 1.0)).stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round)).frame(width: 72, height: 72).rotationEffect(.degrees(-90))
                Image(systemName: icon).font(.system(size: 16)).foregroundColor(color)
            }
            Text("\(value)%").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
            Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(.gray)
            Text(sub).font(.system(size: 10)).foregroundColor(color.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }

    private var healthMetricsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Heute").font(.headline.weight(.semibold)).foregroundColor(.white)
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(Color.ncNeonGreen).frame(width: 5, height: 5)
                    Text("Apple Health").font(.caption).foregroundColor(.ncNeonGreen)
                }
            }
            .padding(.horizontal, 20)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metricTile(icon: "heart.text.clipboard", label: "Herzfrequenzvar.", value: "\(Int(health.hrv))", compare: "75", trend: health.hrv > 75 ? .up : .down)
                metricTile(icon: "heart.fill", label: "Ruheherzfrequenz", value: "\(Int(health.heartRate))", compare: "60", trend: health.heartRate < 60 ? .up : .down)
                metricTile(icon: "figure.walk", label: "Schritte", value: fmtNum(health.steps), compare: "7,423", trend: health.steps > 7424 ? .up : .down)
                metricTile(icon: "flame.fill", label: "Kalorien", value: "\(Int(health.heartRate * 2 + 500))", compare: "2,430", trend: .down)
                metricTile(icon: "lungs.fill", label: "VO2 Max", value: "44", compare: "45", trend: .down)
                metricTile(icon: "bolt.fill", label: "HF-Zonen 1-3", value: "2:01", compare: "2:28", trend: .down)
            }
            .padding(.horizontal, 16)
        }
    }

    private func metricTile(icon: String, label: String, value: String, compare: String, trend: Trend) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 9)).foregroundColor(.gray)
                Text(label).font(.system(size: 9, weight: .medium)).foregroundColor(.gray).lineLimit(1)
            }
            Text(value).font(.system(size: 20, weight: .bold)).foregroundColor(.white)
            HStack(spacing: 4) {
                Text(compare).font(.system(size: 10)).foregroundColor(.gray)
                Image(systemName: trend == .up ? "arrow.up" : trend == .down ? "arrow.down" : "arrow.right")
                    .font(.system(size: 8)).foregroundColor(trend == .up ? .ncCyan : trend == .down ? .ncRose : .gray)
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }

    private var monitorsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Monitore").font(.headline.weight(.semibold)).foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 20)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Gesundheitsmonitor").font(.subheadline.weight(.medium)).foregroundColor(.white)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 10)).foregroundColor(.ncNeonGreen)
                    }
                    HStack(spacing: 4) {
                        Text("NORMALER BEREICH").font(.system(size: 9, weight: .bold)).tracking(0.5).foregroundColor(.ncNeonGreen)
                        Spacer()
                        Text("5/5 Messwerte").font(.system(size: 9)).foregroundColor(.gray)
                    }
                }
                .padding(12)
                .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.ncNeonGreen.opacity(0.2), lineWidth: 0.5))
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Stress-Monitor").font(.subheadline.weight(.medium)).foregroundColor(.white)
                        Spacer()
                        Text("21:33").font(.system(size: 9)).foregroundColor(.gray)
                    }
                    HStack(spacing: 4) {
                        Text("MITTEL").font(.system(size: 9, weight: .bold)).tracking(0.5).foregroundColor(.ncAmber)
                        Spacer()
                        Text("1.5").font(.system(size: 9)).foregroundColor(.ncAmber)
                    }
                }
                .padding(12)
                .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.ncAmber.opacity(0.2), lineWidth: 0.5))
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
        }
    }

    private var aiCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "sparkle").font(.caption).foregroundColor(.ncCyan)
                Text("AI-Insight").font(.callout.weight(.semibold)).foregroundColor(.ncCyan)
                Spacer()
            }
            Text("Deine HRV und Schlafdaten geben Aufschluss uber deine Erholung. Ein Recovery Score uber 60% bedeutet, dass dein Korper bereit fur Belastung ist.")
                .font(.subheadline).foregroundColor(.gray).lineSpacing(4)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.02, green: 0.02, blue: 0.04)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.ncCyan.opacity(0.1), lineWidth: 0.5))
        .padding(.horizontal, 16)
    }

    private func fmtNum(_ n: Int) -> String {
        if n >= 1000 {
            let k = Double(n) / 1000
            let s = String(format: "%.1f", k)
            return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
        }
        return "\(n)"
    }

    enum Trend { case up, down, flat }
}

// MARK: - Work Detail View
struct WorkDetailView: View {
    @ObservedObject private var rollup = NARollupService.shared
    @ObservedObject private var finance = NAFinanceService.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Arbeit").font(.title2.weight(.bold)).foregroundColor(.white)
                        Text("Deine Business-Ubersicht von Amelia.").font(.subheadline).foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Deals
                if let d = rollup.deals, d.active_deals > 0 {
                    glassSection(icon: "creditcard.fill", title: "Deals", subtitle: "\(d.active_deals) aktiv · \(d.total_value_eur) €") {
                        ForEach(d.deals?.prefix(5) ?? []) { deal in
                            HStack(spacing: 12) {
                                Circle().fill(Color.ncNeonGreen).frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(deal.name).font(.subheadline.weight(.semibold)).foregroundColor(.white)
                                    Text(deal.status ?? "").font(.caption).foregroundColor(.gray)
                                }
                                Spacer()
                                Text("\(deal.value) €").font(.subheadline.weight(.bold)).foregroundColor(.ncNeonGreen)
                            }
                            .padding(10)
                            .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
                        }
                    }
                }

                // Revenue (Einnahmen)
                if let rev = rollup.revenue, !(rev.entries?.isEmpty ?? true) {
                    glassSection(icon: "eurosign.circle.fill", title: "Einnahmen", subtitle: "\(rev.total_eur ?? 0)€ gesamt") {
                        // Stats
                        HStack(spacing: 10) {
                            statBox("Gesamt", "\(rev.total_eur ?? 0)€", .ncNeonGreen)
                            statBox("Dieser Monat", "\(rev.this_month ?? 0)€", .ncCyan)
                            statBox("Letzter Monat", "\(rev.last_month ?? 0)€", .ncAmber)
                        }

                        // Monthly Chart
                        if let monthly = rev.monthly, !monthly.isEmpty {
                            Text("Monatliche Einnahmen").font(.caption.weight(.semibold)).foregroundColor(.gray).padding(.top, 4)
                            HStack(alignment: .bottom, spacing: 6) {
                                ForEach(monthly) { m in
                                    let maxVal = monthly.map { $0.total ?? 0 }.max() ?? 1
                                    let pct = Double(m.total ?? 0) / Double(max(1, maxVal))
                                    VStack(spacing: 3) {
                                        RoundedRectangle(cornerRadius: 4).fill(Color.ncNeonGreen).frame(width: 24, height: max(8, CGFloat(pct) * 50))
                                        Text(m.month?.suffix(2) ?? "").font(.system(size: 8)).foregroundColor(.gray)
                                    }
                                }
                            }
                            .frame(height: 64)
                            .padding(8)
                            .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 8))
                        }

                        // Entries
                        if let entries = rev.entries, !entries.isEmpty {
                            Text("Zahlungseingange").font(.caption.weight(.semibold)).foregroundColor(.gray).padding(.top, 4)
                            VStack(spacing: 4) {
                                ForEach(entries) { entry in
                                    HStack(spacing: 10) {
                                        Circle().fill(Color.ncNeonGreen).frame(width: 6, height: 6)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(entry.client ?? entry.label ?? "").font(.subheadline.weight(.medium)).foregroundColor(.white)
                                            if let k = entry.kind { Text(k.replacingOccurrences(of: "_", with: " ").capitalized).font(.caption2).foregroundColor(.gray) }
                                        }
                                        Spacer()
                                        Text("\(entry.amount ?? 0)€").font(.subheadline.weight(.bold)).foregroundColor(.ncNeonGreen)
                                    }
                                    .padding(8)
                                    .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                }

                // Business
                if let b = rollup.business {
                    glassSection(icon: "briefcase.fill", title: "Business", subtitle: "") {
                        if let f = b.foodloop {
                            hSection("fork.knife", "foodloop", "\(f.total) Kontakte")
                            if let stats = f.statuses { bizStats(stats) }
                            Text("Heiss: \(f.hot ?? 0) Kontakte").font(.caption).foregroundColor(.ncRose)
                                .padding(.leading, 4)
                        }
                        if let n = b.naice {
                            hSection("brain.head.profile", "nAIce", "\(n.total) Kontakte")
                            if let stats = n.statuses { bizStats(stats) }
                            Text("Gepitcht: \(n.statuses?["pitched"] ?? 0)").font(.caption).foregroundColor(.ncCyan)
                                .padding(.leading, 4)
                        }
                    }
                }

                // Tasks
                if let t = rollup.tasks, t.active > 0 {
                    glassSection(icon: "checklist", title: "Aufgaben", subtitle: "\(t.active) offen") {
                        ForEach(t.tasks?.prefix(5) ?? []) { task in
                            HStack(spacing: 12) {
                                Image(systemName: task.priority == "high" ? "exclamationmark.circle.fill" : "circle")
                                    .foregroundColor(task.priority == "high" ? .ncRose : .ncGray).font(.system(size: 14))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.title).font(.subheadline).foregroundColor(.white).lineLimit(2)
                                    HStack(spacing: 8) {
                                        if let p = task.project { Text(p).font(.caption2).foregroundColor(.ncCyan) }
                                        if let d = task.deadline { Text("Frist: \(d)").font(.caption2).foregroundColor(.gray) }
                                    }
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
                        }
                    }
                }

                // AI-Tipp
                glassSection(icon: "sparkle", title: "AI-Tipp", subtitle: "") {
                    if let flags = rollup.summary?.flags, !flags.isEmpty {
                        ForEach(flags) { flag in
                            HStack(spacing: 8) {
                                Image(systemName: flag.level == "red" ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                                    .foregroundColor(flag.level == "red" ? .ncRose : .ncAmber).font(.caption)
                                Text(flag.text).font(.caption).foregroundColor(.gray)
                            }
                        }
                    } else {
                        Text("Amelia analysiert deine Daten. Offne den Chat fur Details.").font(.subheadline).foregroundColor(.gray)
                    }
                }

                if rollup.isLoading {
                    VStack(spacing: 12) { ProgressView().tint(.ncCyan); Text("Amelia ladt...").font(.subheadline).foregroundColor(.gray) }
                        .padding(20).frame(maxWidth: .infinity)
                        .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Glass Section
    @ViewBuilder
    private func glassSection(icon: String, title: String, subtitle: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.caption).foregroundColor(.ncCyan)
                Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.white)
                if !subtitle.isEmpty {
                    Spacer()
                    Text(subtitle).font(.caption).foregroundColor(.gray)
                }
            }
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        )
        .padding(.horizontal, 16)
    }

    private func hSection(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 10)).foregroundColor(.ncCyan)
            Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.white)
            Spacer()
            Text(subtitle).font(.caption).foregroundColor(.gray)
        }
        .padding(.top, 4).padding(.bottom, 2)
    }

    private func bizStats(_ statuses: [String: Int]) -> some View {
        let sorted = statuses.sorted { $0.value > $1.value }
        return VStack(spacing: 4) {
            ForEach(sorted.prefix(6), id: \.key) { key, val in
                HStack(spacing: 8) {
                    Text(key.replacingOccurrences(of: "_", with: " ").capitalized).font(.caption).foregroundColor(.gray)
                    Spacer()
                    Text("\(val)").font(.caption.weight(.semibold)).foregroundColor(.white)
                }
            }
        }
        .padding(10)
        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func statBox(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 15, weight: .bold)).foregroundColor(color)
            Text(label).font(.system(size: 9)).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }
}

// MARK: - Relations Detail View
// MARK: - Creativity Detail View
struct CreativityDetailView: View {
    @ObservedObject var naice: NAiceAPI
    @State private var newIdea = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Kreativitat").font(.title2.weight(.bold)).foregroundColor(.ncDark)
                Text("Sammle und entwickle Ideen mit deinem Agent.").font(.subheadline).foregroundColor(.ncMuted)

                HStack(spacing: 8) {
                    TextField("Neue Idee...", text: $newIdea)
                        .padding(10).background(Color.ncPaper)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.ncSand))
                    Button("Speichern") {
                        let t = newIdea; newIdea = ""
                        Task { await naice.saveIdea(t) }
                    }
                    .font(.caption.weight(.semibold)).foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.ncGreen, in: RoundedRectangle(cornerRadius: 9))
                }

                if naice.ideas.isEmpty {
                    Text("Noch keine Ideen gespeichert. Leg los!").font(.subheadline).foregroundColor(.ncMuted)
                }
                ForEach(naice.ideas) { idea in
                    HStack(spacing: 12) {
                        Image(systemName: "lightbulb.fill").font(.title3).foregroundColor(.ncGold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(idea.text).font(.subheadline).foregroundColor(.ncDark)
                            Text(idea.createdAt, style: .date).font(.caption).foregroundColor(.ncMuted)
                        }
                        Spacer()
                    }.warmCard()
                }

                cCard("Brainstorming-Partner", "Dein Agent kann mit dir zusammen Ideen entwickeln, erweitern und strukturieren. Einfach im Chat starten.")
                cCard("Kreativ-Routinen", "Die besten Ideen kommen beim Spazierengehen oder unter der Dusche. Halte sie sofort fest – dein nAIce Agent speichert fur dich.", "brain.head.profile")
                VStack(spacing: 8) {
                    Text("AI-Tipp").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                    Text("Setze dir ein Ziel: 3 Ideen pro Woche. Dein Agent hilft dir, sie zu sortieren und weiterzuentwickeln.").font(.subheadline).foregroundColor(.ncMuted)
                }.warmCard()
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }
        .warmBackground()
        .navigationTitle("Kreativitat")
        .navigationBarTitleDisplayMode(.large)
    }

    func cCard(_ t: String, _ txt: String, _ i: String = "lightbulb") -> some View {
        HStack(spacing: 12) {
            Image(systemName: i).font(.title2).foregroundColor(.ncGold).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(t).font(.subheadline.weight(.semibold)).foregroundColor(.ncDark)
                Text(txt).font(.caption).foregroundColor(.ncMuted)
            }
        }.warmCard()
    }
}

// MARK: - Daily Detail View (Modern Dark)
struct DailyDetailView: View {
    @ObservedObject var calendar = CalendarManager.shared
    @ObservedObject var weather = NAWeatherService.shared
    @ObservedObject var routines = NARoutineService.shared
    @ObservedObject var locations = NALocationService.shared
    @ObservedObject var rollup = NARollupService.shared
    @ObservedObject var health = HealthManager.shared
    @State private var showingNewLocation = false
    @State private var newLocationName = ""
    @State private var newLocationNote = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Alltag")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                        Text("Dein Tag im Uberblick.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Weather + Health Summary (Morning Check-in)
                morningCheckin
                    .padding(.horizontal, 16)

                // Termine
                eventsSection
                    .padding(.horizontal, 16)

                // iOS Reminders
                if !calendar.reminders.isEmpty {
                    remindersSection
                        .padding(.horizontal, 16)
                }

                // Routinen
                routinesSection
                    .padding(.horizontal, 16)

                // Standort-Erinnerungen
                locationSection
                    .padding(.horizontal, 16)

                // Abendliche Reflexion
                reflectionSection
                    .padding(.horizontal, 16)

                // AI-Tipp
                aiTipSection
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 30)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await weather.fetchWeather()
            await calendar.loadUpcoming()
            await calendar.fetchReminders()
            await routines.refreshSuggestions()
        }
        .sheet(isPresented: $showingNewLocation) { newLocationSheet }
    }

    // MARK: - Morning Check-in
    private var morningCheckin: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sunrise.fill")
                    .font(.caption)
                    .foregroundColor(.ncAmber)
                Text("Guten Morgen, Johannes")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
            }

            HStack(spacing: 12) {
                // Weather
                VStack(alignment: .leading, spacing: 4) {
                    if let w = weather.weather {
                        HStack(spacing: 8) {
                            Image(systemName: w.iconName)
                                .font(.system(size: 24))
                                .foregroundColor(.ncCyan)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(Int(w.temperature))°C")
                                    .font(.title3.weight(.bold))
                                    .foregroundColor(.white)
                                Text(w.condition)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(w.locationName)
                                    .font(.caption2)
                                    .foregroundColor(.gray.opacity(0.7))
                            }
                        }
                    } else if weather.isLoading {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.7).tint(.ncCyan)
                            Text("Wetter laden...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "location.slash")
                                .font(.title3)
                                .foregroundColor(.gray)
                            Text("Standort nicht verfugbar")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Health mini
                if health.isAuthorized && health.steps > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.ncRose)
                        Text("\(Int(health.heartRate)) bpm")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white)
                        Text("\(health.steps) Schritte")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text("\(Int(health.hrv)) ms HRV")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }

            // Calendar summary
            if !calendar.todayEvents.isEmpty {
                Text("\(calendar.todayEvents.count) Termin(e) heute")
                    .font(.caption)
                    .foregroundColor(.ncCyan)
            } else {
                Text("Keine Termine heute – Zeit fur Fokus.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        )
    }

    // MARK: - Events
    private var eventsSection: some View {
        let events = calendar.upcomingEvents.isEmpty ? calendar.todayEvents : calendar.upcomingEvents
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(.ncCyan)
                Text("Termine")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(events.count)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.ncCyan, in: Capsule())
            }

            if events.isEmpty {
                Text("Keine anstehenden Termine im Kalender.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            } else {
                VStack(spacing: 6) {
                    ForEach(events.prefix(5), id: \.eventIdentifier) { event in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.ncCyan)
                                .frame(width: 3, height: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(event.startDate, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                + Text(" ")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                + Text(event.startDate, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        )
    }

    // MARK: - iOS Reminders
    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge.fill")
                    .font(.caption)
                    .foregroundColor(.ncRose)
                Text("Erinnerungen")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(calendar.remindersCount)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.ncRose, in: Capsule())
            }

            VStack(spacing: 6) {
                ForEach(Array(calendar.reminders.prefix(8)), id: \.calendarItemIdentifier) { reminder in
                    reminderRow(reminder)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.ncRose.opacity(0.1), lineWidth: 0.5))
        )
    }

    // MARK: - Routinen
    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.trianglehead.clockwise")
                    .font(.caption)
                    .foregroundColor(.ncAmber)
                Text("Routinen")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(routines.completedToday)/\(routines.routines.count)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(routines.completedToday == routines.routines.count ? Color.ncNeonGreen : Color.ncAmber, in: Capsule())
            }

            VStack(spacing: 6) {
                ForEach(routines.routines) { routine in
                    HStack(spacing: 10) {
                        Image(systemName: routine.icon)
                            .font(.system(size: 12))
                            .foregroundColor(.ncAmber)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(routine.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white)
                            Text(routine.description)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button {
                            routines.completeRoutine(routine.id)
                        } label: {
                            Image(systemName: routine.lastCompleted != nil ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundColor(routine.lastCompleted != nil ? .ncNeonGreen : .gray.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
                }
            }

            if !routines.suggestions.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 8))
                        .foregroundColor(.ncAmber)
                    Text(routines.suggestions.first ?? "")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(8)
                .background(Color.ncAmber.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        )
    }

    // MARK: - Standort-Erinnerungen
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundColor(.ncCyan)
                Text("Standort-Erinnerungen")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                Button { showingNewLocation = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.ncCyan)
                }
            }

            if locations.reminders.isEmpty {
                Text("Noch keine Standort-Erinnerungen. Tippe auf + um eine zu erstellen.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(locations.reminders.enumerated()), id: \.offset) { idx, reminder in
                        HStack(spacing: 10) {
                            Image(systemName: reminder.isEnabled ? "bell.fill" : "bell.slash")
                                .font(.system(size: 10))
                                .foregroundColor(reminder.isEnabled ? .ncCyan : .gray)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(reminder.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.white)
                                Text(reminder.note)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { locations.reminders[idx].isEnabled },
                                set: { _ in locations.toggleReminder(reminder.id) }
                            ))
                            .labelsHidden()
                            .tint(.ncCyan)
                            .scaleEffect(0.7)
                        }
                        .padding(10)
                        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        )
    }

    // MARK: - Reflection
    private var reflectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "moon.stars.fill")
                    .font(.caption)
                    .foregroundColor(.ncAmber)
                Text("Abendliche Reflexion")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            Text("Was war gut heute? Was morgen besser? Mach einen kurzen Journal-Eintrag.")
                .font(.subheadline)
                .foregroundColor(.gray)

            let weekCount = rollup.journal?.this_week ?? 0
            HStack(spacing: 8) {
                if weekCount > 0 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.ncNeonGreen)
                    Text("\(weekCount) Eintrage diese Woche")
                        .font(.caption)
                        .foregroundColor(.ncNeonGreen)
                } else {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    Text("Noch kein Eintrag heute.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        )
    }

    // MARK: - AI-Tipp
    private var aiTipSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkle")
                    .font(.caption)
                    .foregroundColor(.ncCyan)
                Text("AI-Tipp")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            Text(routines.suggestions.first ?? "Routinen geben Struktur, aber Flexibilitat macht glucklich.")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.ncCyan.opacity(0.1), lineWidth: 0.5))
        )
    }

    private func reminderRow(_ reminder: EKReminder) -> some View {
        HStack(spacing: 10) {
            Button {
                calendar.completeReminder(reminder)
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title ?? "Unbenannt")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                if let notes = reminder.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                if let due = reminder.dueDateComponents?.date {
                    if due < Date() {
                        Text("Überfallig")
                            .font(.caption2)
                            .foregroundColor(.ncRose)
                    } else {
                        Text(due, style: .date)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }

            Spacer()

            if let list = reminder.calendar {
                let calName = list.title
                if !calName.isEmpty {
                    Text(calName)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .padding(10)
        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }

    // MARK: - New Location Sheet
    private var newLocationSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Neue Standort-Erinnerung")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                TextField("Name (z.B. Zuhause)", text: $newLocationName)
                    .font(.subheadline).foregroundColor(.white)
                    .padding(14)
                    .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    .padding(.horizontal, 20)
                TextField("Notiz (z.B. Einkaufe mitbringen)", text: $newLocationNote)
                    .font(.subheadline).foregroundColor(.white)
                    .padding(14)
                    .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    .padding(.horizontal, 20)
                Button("Hinzufugen") {
                    let reminder = NALocationReminder(name: newLocationName, latitude: 47.85, longitude: 10.28, radius: 100, onEntry: true, onExit: false, note: newLocationNote)
                    locations.addReminder(reminder)
                    newLocationName = ""; newLocationNote = ""; showingNewLocation = false
                }
                .font(.headline.weight(.semibold)).foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(newLocationName.isEmpty ? Color.gray.opacity(0.3) : Color.ncCyan, in: RoundedRectangle(cornerRadius: 14))
                .disabled(newLocationName.isEmpty).padding(.horizontal, 20)
                Spacer()
            }
            .padding(.top, 24)
            .background(Color.black.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Abbrechen") { showingNewLocation = false }.foregroundColor(.ncCyan) } }
        }
    }
}

// MARK: - Workouts Detail View
struct WorkoutsDetailView: View {
    let whoop: NAWhoop

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Workouts").font(.title2.weight(.bold)).foregroundColor(.ncDark)
                Text("Die letzten \(whoop.workouts.count) Aktivitaten").font(.subheadline).foregroundColor(.ncMuted)

                ForEach(whoop.workouts) { wo in
                    HStack(spacing: 14) {
                        Image(systemName: wo.sportIcon).font(.title2).foregroundColor(.ncGreen).frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(wo.sport.capitalized).font(.subheadline.weight(.semibold)).foregroundColor(.ncDark)
                            Text("\(wo.durationMinutes) min").font(.caption).foregroundColor(.ncMuted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 2) {
                                Image(systemName: "bolt.fill").font(.system(size: 8)).foregroundColor(.ncGold)
                                Text(String(format: "%.1f", wo.strain)).font(.caption.weight(.semibold)).foregroundColor(.ncDark)
                            }
                            HStack(spacing: 2) {
                                Image(systemName: "heart.fill").font(.system(size: 8)).foregroundColor(.ncRed)
                                Text("\(wo.avgHr) Ø").font(.caption).foregroundColor(.ncMuted)
                            }
                        }
                    }.warmCard()
                }

                VStack(spacing: 8) {
                    Text("AI-Tipp").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                    Text("Deine Workout-Strain summiert sich auf \(String(format: "%.1f", whoop.workouts.reduce(0) { $0 + $1.strain })). Dein Korper signalisiert mit einem Recovery von \(whoop.recoveryScore)%: Heute kein Strain uber 10.").font(.subheadline).foregroundColor(.ncMuted)
                }.warmCard()
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }
        .warmBackground()
        .navigationTitle("Workouts")
        .navigationBarTitleDisplayMode(.inline)
    }
}