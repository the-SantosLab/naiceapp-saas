import SwiftUI

// MARK: - Health Detail View
struct HealthDetailView: View {
    @ObservedObject var naice: NAiceAPI
    @ObservedObject var health = HealthManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Gesundheit").font(.title2.weight(.bold)).foregroundColor(.ncDark)
                Text("Deine Vitaldaten auf einen Blick.").font(.subheadline).foregroundColor(.ncMuted)

                if !(naice.whoop?.connected ?? false) {
                    Link(destination: URL(string: "https://health.santoslab.de/auth/whoop")!) {
                        Text("Whoop verbinden").foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.ncGreen, in: RoundedRectangle(cornerRadius: 14))
                    }
                }

                if let w = naice.whoop, w.connected {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Whoop Recovery").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                            Spacer()
                            Text("\(w.recoveryScore)%").font(.largeTitle.weight(.bold))
                                .foregroundColor(w.recoveryScore > 60 ? .ncGreen : .ncRed)
                        }
                        ProgressView(value: Double(w.recoveryScore) / 100)
                            .tint(w.recoveryScore > 60 ? .ncGreen : .ncRed)
                        Divider()
                        hRow("HRV", "\(Int(w.hrv)) ms")
                        hRow("Ruhepuls", "\(w.restingHeartRate) bpm")
                        hRow("Strain", String(format: "%.1f", w.strain))
                        hRow("Schlaf", String(format: "%.1f h", w.sleepHours))
                    }.warmCard()
                }

                if health.isAuthorized {
                    VStack(spacing: 10) {
                        Text("HealthKit").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                        hRow("Schritte", "\(health.steps)")
                        hRow("Puls", "\(Int(health.heartRate)) bpm")
                        hRow("HRV", "\(Int(health.hrv)) ms")
                        hRow("Schlaf", String(format: "%.1f h", health.sleepHours))
                    }.warmCard()
                }

                VStack(spacing: 8) {
                    Text("AI-Tipp").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                    Text("Deine HRV und Schlafdaten geben Aufschluss uber deine Erholung. Ein Recovery Score uber 60% bedeutet, dass dein Korper bereit fur Belastung ist.").font(.subheadline).foregroundColor(.ncMuted)
                }.warmCard()

                VStack(spacing: 8) {
                    Text("Whoop API Echtzeitdaten").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                    Text("Der Whoop-Server liefert deine aktuellen Vitaldaten automatisch. Recovery, HRV, Schlaf und Strain werden mit jeder Aktualisierung synchronisiert.").font(.subheadline).foregroundColor(.ncMuted)
                }.warmCard()
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }
        .warmBackground()
        .navigationTitle("Gesundheit")
        .navigationBarTitleDisplayMode(.large)
    }

    func hRow(_ t: String, _ v: String) -> some View {
        HStack {
            Text(t).font(.subheadline).foregroundColor(.ncDark)
            Spacer()
            Text(v).font(.subheadline.weight(.bold)).foregroundColor(.ncDark)
        }.padding(.vertical, 2)
    }
}

// MARK: - Work Detail View
struct WorkDetailView: View {
    @ObservedObject private var rollup = NARollupService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Arbeit").font(.title2.weight(.bold)).foregroundColor(.ncDark)
                Text("Deine Business-Ubersicht von Amelia.").font(.subheadline).foregroundColor(.ncMuted)

                // Deals
                if let d = rollup.deals, d.active_deals > 0 {
                    hSection("eurosign", "Deals", "\(d.active_deals) aktiv · \(d.total_value_eur) €")
                    ForEach(d.deals?.prefix(5) ?? []) { deal in
                        HStack(spacing: 12) {
                            Circle().fill(Color.ncGreen).frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(deal.name).font(.subheadline.weight(.semibold)).foregroundColor(.ncDark)
                                Text(deal.status ?? "").font(.caption).foregroundColor(.ncMuted)
                            }
                            Spacer()
                            Text("\(deal.value) €").font(.subheadline.weight(.bold)).foregroundColor(.ncGreen)
                        }.warmCard()
                    }
                }

                // Business
                if let b = rollup.business {
                    if let f = b.foodloop {
                        hSection("fork.knife", "foodloop", "\(f.total) Kontakte")
                        if let stats = f.statuses {
                            bizStats(stats)
                        }
                        Text("Heiss: \(f.hot ?? 0) Kontakte").font(.caption).foregroundColor(.ncRed)
                            .padding(.leading, 4)
                    }
                    if let n = b.naice {
                        hSection("brain.head.profile", "nAIce", "\(n.total) Kontakte")
                        if let stats = n.statuses {
                            bizStats(stats)
                        }
                        Text("Gepitcht: \(n.statuses?["pitched"] ?? 0)").font(.caption).foregroundColor(.ncSage)
                            .padding(.leading, 4)
                    }
                }

                // Tasks
                if let t = rollup.tasks, t.active > 0 {
                    hSection("checklist", "Aufgaben", "\(t.active) offen")
                    ForEach(t.tasks?.prefix(5) ?? []) { task in
                        HStack(spacing: 12) {
                            Image(systemName: task.priority == "high" ? "exclamationmark.circle.fill" : "circle")
                                .foregroundColor(task.priority == "high" ? .ncRed : .ncSage)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title).font(.subheadline).foregroundColor(.ncDark).lineLimit(2)
                                HStack(spacing: 8) {
                                    if let p = task.project { Text(p).font(.caption2).foregroundColor(.ncSage) }
                                    if let d = task.deadline { Text("Frist: \(d)").font(.caption2).foregroundColor(.ncMuted) }
                                }
                            }
                            Spacer()
                        }.warmCard()
                    }
                }

                // AI-Tipp
                VStack(spacing: 8) {
                    Text("AI-Tipp").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                    if let flags = rollup.summary?.flags, !flags.isEmpty {
                        ForEach(flags) { flag in
                            HStack(spacing: 8) {
                                Image(systemName: flag.level == "red" ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                                    .foregroundColor(flag.level == "red" ? .ncRed : .ncGold)
                                    .font(.caption)
                                Text(flag.text).font(.caption).foregroundColor(.ncMuted)
                            }
                        }
                    } else {
                        Text("Amelia analysiert deine Daten. Offne den Chat fur Details.").font(.subheadline).foregroundColor(.ncMuted)
                    }
                }.warmCard()

                if rollup.isLoading {
                    VStack(spacing: 12) { ProgressView(); Text("Amelia ladt...").font(.subheadline).foregroundColor(.ncMuted) }.warmCard()
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }
        .warmBackground()
        .navigationTitle("Arbeit")
        .navigationBarTitleDisplayMode(.large)
    }

    func hSection(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.title3).foregroundColor(.ncSage)
            Text(title).font(.headline.weight(.semibold)).foregroundColor(.ncDark)
            Spacer()
            Text(subtitle).font(.caption).foregroundColor(.ncMuted)
        }
        .padding(.top, 4).padding(.bottom, 2)
    }

    func bizStats(_ statuses: [String: Int]) -> some View {
        let sorted = statuses.sorted { $0.value > $1.value }
        return VStack(spacing: 4) {
            ForEach(sorted.prefix(6), id: \.key) { key, val in
                HStack(spacing: 8) {
                    Text(key.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption).foregroundColor(.ncMuted)
                    Spacer()
                    Text("\(val)").font(.caption.weight(.semibold)).foregroundColor(.ncDark)
                }
            }
        }.warmCard()
    }
}

// MARK: - Relations Detail View
struct RelationsDetailView: View {
    @ObservedObject private var svc = NAContactService.shared
    @ObservedObject private var waVM = WhatsAppViewModel.shared
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Beziehungen").font(.title2.weight(.bold)).foregroundColor(.ncDark)
                Text("\(svc.contacts.count) Kontakte · Dein soziales CRM.").font(.subheadline).foregroundColor(.ncMuted)

                // Search
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.ncMuted)
                    TextField("Suchen...", text: $searchText).font(.subheadline)
                }
                .padding(10).background(Color.white.opacity(0.7)).cornerRadius(10)

                if svc.isLoading {
                    VStack(spacing: 12) { ProgressView(); Text("Kontakte laden...").font(.subheadline).foregroundColor(.ncMuted) }.warmCard()
                } else if let err = svc.lastError {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.title2).foregroundColor(.ncRed)
                        Text(err).font(.subheadline).foregroundColor(.ncRed)
                        Button("Berechtigung anfragen") {
                            Task { await ServiceManager.shared.requestAll(); await svc.fetchContacts() }
                        }.buttonStyle(.bordered).tint(.ncGreen)
                    }.warmCard()
                } else {
                    // Upcoming Birthdays
                    let bdays = svc.upcomingBirthdays
                    if !bdays.isEmpty {
                        socialSection("🎂 Geburtstage") {
                            ForEach(bdays.prefix(5), id: \.0.id) { contact, days, date in
                                HStack(spacing: 10) {
                                    Image(systemName: "star.fill").font(.caption).foregroundColor(.ncGold)
                                    NavigationLink(destination: ContactDetailView(contact: contact)) {
                                        Text(contact.fullName).font(.subheadline).foregroundColor(.ncDark)
                                    }
                                    Spacer()
                                    Text(days == 0 ? "Heute!" : "in \(days) Tagen (\(date))")
                                        .font(.caption).foregroundColor(days == 0 ? .ncRed : .ncMuted)
                                }.padding(.vertical, 3)
                            }
                        }
                    }

                    // Reachout Due
                    let due = svc.reachoutDue.prefix(5)
                    if !due.isEmpty {
                        socialSection("Kontakt fallig") {
                            ForEach(Array(due)) { contact in
                                HStack(spacing: 10) {
                                    Image(systemName: "bell.fill").font(.caption).foregroundColor(.ncRed)
                                    NavigationLink(destination: ContactDetailView(contact: contact)) {
                                        Text(contact.fullName).font(.subheadline).foregroundColor(.ncDark)
                                    }
                                    Spacer()
                                    if let d = contact.daysSinceContacted {
                                        Text("vor \(d) Tagen").font(.caption).foregroundColor(.ncMuted)
                                    }
                                }.padding(.vertical, 3)
                            }
                        }
                    }

                    // WhatsApp pending
                    let unrepliedChats = waVM.unrepliedChats.prefix(10)
                    if !unrepliedChats.isEmpty {
                        socialSection("WhatsApp offen") {
                            ForEach(Array(unrepliedChats)) { chat in
                                HStack(spacing: 10) {
                                    Image(systemName: "message.fill").font(.caption).foregroundColor(.ncGreen)
                                    NavigationLink(destination: WhatsAppChatDetailView(chat: chat)) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(chat.contact).font(.subheadline.weight(.semibold)).foregroundColor(.ncDark)
                                            if let text = chat.lastIncomingText {
                                                Text(text).font(.caption).foregroundColor(.ncMuted).lineLimit(1)
                                            }
                                        }
                                    }
                                    Spacer()
                                    HStack(spacing: 4) {
                                        if chat.urgency == .red {
                                            Circle().fill(Color.ncRed).frame(width: 8, height: 8)
                                        } else if chat.urgency == .yellow {
                                            Circle().fill(Color.ncGold).frame(width: 8, height: 8)
                                        }
                                        Text(chat.timeAgo).font(.caption2).foregroundColor(.ncMuted)
                                    }
                                }.padding(.vertical, 3)
                            }
                        }
                    }

                    // Categorized contacts
                    let cats = svc.socialCategories()
                    ForEach(cats, id: \.0) { key, items, label in
                        socialSection(label) {
                            let filtered = searchText.isEmpty ? items : items.filter {
                                $0.fullName.lowercased().contains(searchText.lowercased()) ||
                                ($0.organization ?? "").lowercased().contains(searchText.lowercased())
                            }
                            ForEach(filtered) { contact in
                                NavigationLink(destination: ContactDetailView(contact: contact)) {
                                    ContactRowView(contact: contact)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if svc.contacts.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "person.3.fill").font(.title2).foregroundColor(.ncSage).opacity(0.5)
                            Text("Keine Kontakte gefunden.").font(.subheadline).foregroundColor(.ncMuted)
                        }.warmCard()
                    }
                }

                // AI-Tipp
                VStack(spacing: 8) {
                    Text("AI-Tipp").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                    Text("Einmal pro Woche eine kurze Nachricht an einen Kontakt kann Beziehungen starken. Dein Agent erinnert dich.").font(.subheadline).foregroundColor(.ncMuted)
                }.warmCard()
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }
        .warmBackground()
        .navigationTitle("Beziehungen")
        .navigationBarTitleDisplayMode(.large)
        .task { await svc.fetchContacts(); waVM.startAutoRefresh(); await waVM.fetchPending() }
    }

    func socialSection(_ title: String, @ViewBuilder content: @escaping () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline.weight(.semibold)).foregroundColor(.ncDark)
            content()
        }.warmCard()
    }
}

// MARK: - Contact Row View
struct ContactRowView: View {
    let contact: NAContact
    var icon: String? = nil
    var showActions: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.ncGreen.opacity(0.15)).frame(width: 40, height: 40)
                Text(contact.initials).font(.system(size: 14, weight: .semibold)).foregroundColor(.ncGreen)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.fullName).font(.subheadline.weight(.semibold)).foregroundColor(.ncDark)
                if let org = contact.organization { Text(org).font(.caption).foregroundColor(.ncMuted) }
                if let days = contact.daysSinceContacted {
                    Text(days == 0 ? "Heute kontaktiert" : "vor \(days) Tagen")
                        .font(.caption2).foregroundColor(contact.isReachoutDue ? .ncRed : .ncSage)
                }
            }
            Spacer()
            if showActions, let phone = contact.phoneNumbers.first {
                HStack(spacing: 4) {
                    Button { NAContactService.shared.call(phone: phone) } label: {
                        Image(systemName: "phone.fill").font(.caption).foregroundColor(.ncGreen)
                            .frame(width: 24, height: 24).background(Color.ncGreen.opacity(0.1)).cornerRadius(6)
                    }
                    Button { NAContactService.shared.openWhatsApp(phone: phone) } label: {
                        Image(systemName: "message.fill").font(.caption).foregroundColor(.ncGreen)
                            .frame(width: 24, height: 24).background(Color.ncGreen.opacity(0.1)).cornerRadius(6)
                    }
                }
            }
            Image(systemName: "chevron.right").font(.caption2).foregroundColor(.ncSand)
        }
        .padding(.vertical, 6).padding(.horizontal, 8)
        .background(Color.white.opacity(0.5)).cornerRadius(8)
    }
}

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

// MARK: - Daily Detail View
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
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Alltag").font(.title2.weight(.bold)).foregroundColor(.ncDark)
                Text("Dein Tag im Uberblick.").font(.subheadline).foregroundColor(.ncMuted)

                // Wetter + Standort
                VStack(spacing: 10) {
                    HStack {
                        if let w = weather.weather {
                            Image(systemName: w.iconName).font(.title).foregroundColor(.ncGold)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(Int(w.temperature))°C · \(w.condition)").font(.headline).foregroundColor(.ncDark)
                                Text(w.locationName).font(.subheadline).foregroundColor(.ncMuted)
                            }
                        } else if weather.isLoading {
                            ProgressView().scaleEffect(0.7)
                            Text("Wetter laden...").font(.subheadline).foregroundColor(.ncMuted)
                        } else {
                            Image(systemName: "location.slash").font(.title2).foregroundColor(.ncSand)
                            Text("Standort nicht verfugbar").font(.subheadline).foregroundColor(.ncMuted)
                        }
                        Spacer()
                        Button { Task { await weather.fetchWeather() } } label: {
                            Image(systemName: "arrow.clockwise").font(.caption).foregroundColor(.ncSage)
                        }
                    }
                }.warmCard()

                // Termine
                let events = calendar.upcomingEvents.isEmpty ? calendar.todayEvents : calendar.upcomingEvents
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "calendar").font(.title3).foregroundColor(.ncSage)
                        Text(events.isEmpty ? "Keine Termine" : "Nachste Termine").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                        Spacer()
                        Text(events.isEmpty ? "" : "\(events.count)")
                            .font(.caption).foregroundColor(.white)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Color.ncGreen, in: Capsule())
                    }
                    if events.isEmpty {
                        Text("Keine anstehenden Termine im Kalender.").font(.subheadline).foregroundColor(.ncMuted)
                    } else {
                        ForEach(events.prefix(5), id: \.eventIdentifier) { event in
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 4).fill(Color.ncGreen).frame(width: 3, height: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title).font(.subheadline.weight(.semibold)).foregroundColor(.ncDark)
                                    Text(event.startDate, style: .date).font(.caption).foregroundColor(.ncMuted)
                                    + Text("  ").font(.caption).foregroundColor(.ncMuted)
                                    + Text(event.startDate, style: .time).font(.caption).foregroundColor(.ncMuted)
                                }
                            }
                        }
                    }
                }.warmCard()

                // Morgendlicher Check-in
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "sunrise.fill").font(.title3).foregroundColor(.ncGold)
                        Text("Guten Morgen, Johannes").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                        Spacer()
                    }
                    let tempStr = weather.weather.map { "\(Int($0.temperature))°C · \($0.condition) in \($0.locationName)" } ?? "–"
                    let eventStr = calendar.todayEvents.isEmpty ? "Keine Termine heute" : "\(calendar.todayEvents.count) Termin(e) heute"
                    Text("\(tempStr). \(eventStr).")
                        .font(.subheadline).foregroundColor(.ncMuted)
                    if health.heartRate > 0 {
                        Text("Ruhepuls: \(Int(health.heartRate)) bpm · \(Int(health.hrv)) ms HRV · \(health.steps) Schritte bisher")
                            .font(.caption).foregroundColor(.ncSage)
                    }
                    if rollup.flags.isEmpty {
                        Text("Alles im grunen Bereich!").font(.caption).foregroundColor(.ncGreen)
                    } else {
                        ForEach(rollup.flags.prefix(2)) { flag in
                            Label(flag.text, systemImage: flag.level == "red" ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                                .font(.caption).foregroundColor(flag.level == "red" ? .ncRed : .ncGold)
                        }
                    }
                }.warmCard()

                // Routinen & Gewohnheiten
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "arrow.trianglehead.clockwise").font(.title3).foregroundColor(.ncSage)
                        Text("Routinen (\(routines.completedToday)/\(routines.routines.count) heute)").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                        Spacer()
                        Text("\(routines.currentStreak) Tage Serie")
                            .font(.caption).foregroundColor(.white)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Color.ncGreen, in: Capsule())
                    }
                    ForEach(routines.routines) { routine in
                        HStack(spacing: 10) {
                            Image(systemName: routine.icon).font(.title3).foregroundColor(.ncGold).frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(routine.name).font(.subheadline.weight(.semibold)).foregroundColor(.ncDark)
                                Text(routine.description).font(.caption).foregroundColor(.ncMuted)
                            }
                            Spacer()
                            Button {
                                routines.completeRoutine(routine.id)
                            } label: {
                                Image(systemName: routine.lastCompleted != nil ? "checkmark.circle.fill" : "circle")
                                    .font(.title3).foregroundColor(routine.lastCompleted != nil ? .ncGreen : .ncSand)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    if !routines.suggestions.isEmpty {
                        Text(routines.suggestions.first ?? "Keine Vorschlage.")
                            .font(.caption).foregroundColor(.ncSage).padding(.top, 4)
                    }
                }.warmCard()

                // Standort-basierte Erinnerungen
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "mappin.and.ellipse").font(.title3).foregroundColor(.ncSage)
                        Text("Standort-Erinnerungen").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                        Spacer()
                        Button(action: { showingNewLocation = true }) {
                            Image(systemName: "plus.circle.fill").font(.title3).foregroundColor(.ncGreen)
                        }
                    }
                    if locations.reminders.isEmpty {
                        Text("Noch keine Standort-Erinnerungen. Tippe auf + um eine zu erstellen.")
                            .font(.subheadline).foregroundColor(.ncMuted)
                    } else {
                        ForEach(Array(locations.reminders.enumerated()), id: \.offset) { idx, reminder in
                            HStack(spacing: 10) {
                                Image(systemName: reminder.isEnabled ? "bell.fill" : "bell.slash")
                                    .font(.caption).foregroundColor(reminder.isEnabled ? .ncSage : .ncMuted)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(reminder.name).font(.subheadline.weight(.semibold)).foregroundColor(.ncDark)
                                    Text(reminder.note).font(.caption).foregroundColor(.ncMuted)
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { locations.reminders[idx].isEnabled },
                                    set: { v in locations.toggleReminder(reminder.id) }
                                )).labelsHidden().tint(.ncGreen)
                            }
                        }
                    }
                }.warmCard()

                // Abendliche Reflexion
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "moon.stars.fill").font(.title3).foregroundColor(.ncGold)
                        Text("Abendliche Reflexion").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                        Spacer()
                        Button {
                            // Navigate to journal in Home tab
                        } label: {
                            Image(systemName: "square.and.pencil").font(.title3).foregroundColor(.ncGreen)
                        }
                    }
                    Text("Was war gut heute? Was morgen besser? Mach einen kurzen Journal-Eintrag.")
                        .font(.subheadline).foregroundColor(.ncMuted)
                    let weekCount = rollup.journal?.this_week ?? 0
                    if weekCount > 0 {
                        Text("\(weekCount) Eintrage diese Woche").font(.caption).foregroundColor(.ncSage)
                    } else {
                        Text("Noch kein Eintrag heute.").font(.caption).foregroundColor(.ncMuted)
                    }
                }.warmCard()

                // AI-Tipp aus Rollup
                VStack(spacing: 8) {
                    Text("AI-Tipp").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                    if rollup.flags.isEmpty {
                        Text(routines.suggestions.first ?? "Routinen geben Struktur, aber Flexibilitat macht glucklich.")
                            .font(.subheadline).foregroundColor(.ncMuted)
                    } else {
                        ForEach(rollup.flags) { flag in
                            Label(flag.text, systemImage: flag.level == "red" ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                                .font(.subheadline).foregroundColor(flag.level == "red" ? .ncRed : .ncGold)
                        }
                    }
                }.warmCard()
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }
        .warmBackground()
        .navigationTitle("Alltag")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await weather.fetchWeather()
            await calendar.loadUpcoming()
            await routines.refreshSuggestions()
        }
        .sheet(isPresented: $showingNewLocation) {
            newLocationSheet
        }
    }

    private var newLocationSheet: some View {
        NavigationStack {
            Form {
                TextField("Name (z.B. Zuhause)", text: $newLocationName)
                TextField("Notiz (z.B. Einkaufe mitbringen)", text: $newLocationNote)
                Button("Hinzufugen") {
                    let reminder = NALocationReminder(
                        name: newLocationName,
                        latitude: NAWeatherService.shared.weather != nil ? 47.85 : 0,
                        longitude: NAWeatherService.shared.weather != nil ? 10.28 : 0,
                        radius: 100,
                        onEntry: true,
                        onExit: false,
                        note: newLocationNote
                    )
                    locations.addReminder(reminder)
                    newLocationName = ""
                    newLocationNote = ""
                    showingNewLocation = false
                }
                .disabled(newLocationName.isEmpty)
            }
            .navigationTitle("Neue Erinnerung")
            .navigationBarTitleDisplayMode(.inline)
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