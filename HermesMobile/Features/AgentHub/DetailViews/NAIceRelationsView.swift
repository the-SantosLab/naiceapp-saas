import SwiftUI

// MARK: - Beziehungen (Modern Dark Theme)
struct RelationsDetailView: View {
    @ObservedObject private var svc = NAContactService.shared
    @ObservedObject private var waVM = WhatsAppViewModel.shared
    @State private var searchText = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Beziehungen")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                        Text("\(svc.contacts.count) Kontakte · Dein soziales CRM")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Search
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    TextField("Suchen...", text: $searchText)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding(12)
                .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                .padding(.horizontal, 16)

                if svc.isLoading {
                    VStack(spacing: 12) {
                        ProgressView().scaleEffect(0.8).tint(.ncCyan)
                        Text("Kontakte laden...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    )
                    .padding(.horizontal, 16)
                } else if let err = svc.lastError {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundColor(.ncRose)
                        Text(err)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        Button {
                            Task { await ServiceManager.shared.requestAll(); await svc.fetchContacts() }
                        } label: {
                            Text("Berechtigung anfragen")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.ncCyan)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.ncCyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.ncRose.opacity(0.2), lineWidth: 0.5))
                    )
                    .padding(.horizontal, 16)
                } else {
                    // Quick Stats
                    let unrepliedCount = waVM.unrepliedChats.count
                    let dueCount = svc.reachoutDue.count
                    if unrepliedCount > 0 || dueCount > 0 {
                        HStack(spacing: 10) {
                            if unrepliedCount > 0 {
                                statCard(nc: unrepliedCount, label: "WhatsApp offen", icon: "message.fill", color: .ncAmber)
                            }
                            if dueCount > 0 {
                                statCard(nc: dueCount, label: "Kontakt fällig", icon: "bell.fill", color: .ncRose)
                            }
                            statCard(nc: svc.contacts.count, label: "Kontakte", icon: "person.2.fill", color: .ncCyan)
                        }
                        .padding(.horizontal, 16)
                    }

                    // Upcoming Birthdays
                    let bdays = svc.upcomingBirthdays
                    if !bdays.isEmpty {
                        sectionCard("🎂 Geburtstage") {
                            ForEach(bdays.prefix(5), id: \.0.id) { contact, days, date in
                                NavigationLink(destination: ContactDetailView(contact: contact)) {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            Circle().fill(Color.ncAmber.opacity(0.12)).frame(width: 28, height: 28)
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(.ncAmber)
                                        }
                                        Text(contact.fullName)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text(days == 0 ? "Heute!" : "in \(days) Tagen")
                                            .font(.caption)
                                            .foregroundColor(days == 0 ? .ncRose : .gray)
                                    }
                                    .padding(10)
                                    .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Reachout Due
                    let due = svc.reachoutDue.prefix(5)
                    if !due.isEmpty {
                        sectionCard("Kontakt fällig") {
                            ForEach(Array(due)) { contact in
                                NavigationLink(destination: ContactDetailView(contact: contact)) {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            Circle().fill(Color.ncRose.opacity(0.12)).frame(width: 28, height: 28)
                                            Image(systemName: "bell.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(.ncRose)
                                        }
                                        Text(contact.fullName)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.white)
                                        Spacer()
                                        if let d = contact.daysSinceContacted {
                                            Text("vor \(d) Tagen")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .padding(10)
                                    .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // WhatsApp pending
                    let unreplied = waVM.unrepliedChats.prefix(10)
                    if !unreplied.isEmpty {
                        sectionCard("WhatsApp offen") {
                            ForEach(Array(unreplied)) { chat in
                                NavigationLink(destination: WhatsAppChatDetailView(chat: chat)) {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            Circle().fill(Color.ncNeonGreen.opacity(0.12)).frame(width: 28, height: 28)
                                            Image(systemName: "message.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(.ncNeonGreen)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(chat.contact)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundColor(.white)
                                            if let text = chat.lastIncomingText {
                                                Text(text)
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                        HStack(spacing: 4) {
                                            if chat.urgency == .red {
                                                Circle().fill(Color.ncRose).frame(width: 6, height: 6)
                                            } else if chat.urgency == .yellow {
                                                Circle().fill(Color.ncAmber).frame(width: 6, height: 6)
                                            }
                                            Text(chat.timeAgo)
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .padding(10)
                                    .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Categorized Contacts
                    let cats = svc.socialCategories()
                    ForEach(cats, id: \.0) { key, items, label in
                        sectionCard(label) {
                            let filtered = searchText.isEmpty ? items : items.filter {
                                $0.fullName.lowercased().contains(searchText.lowercased()) ||
                                ($0.organization ?? "").lowercased().contains(searchText.lowercased())
                            }
                            ForEach(filtered) { contact in
                                NavigationLink(destination: ContactDetailView(contact: contact)) {
                                    ContactRowDarkView(contact: contact)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if svc.contacts.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.3.fill")
                                .font(.title2)
                                .foregroundColor(.gray.opacity(0.5))
                            Text("Keine Kontakte gefunden.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                        )
                        .padding(.horizontal, 16)
                    }
                }

                // AI-Tipp
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
                    Text("Einmal pro Woche eine kurze Nachricht an einen Kontakt kann Beziehungen stärken. Dein Agent erinnert dich.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.ncCyan.opacity(0.1), lineWidth: 0.5))
                )
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 30)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await svc.fetchContacts(); waVM.startAutoRefresh(); await waVM.fetchPending() }
    }

    // MARK: - Cards
    private func sectionCard(_ title: String, @ViewBuilder content: @escaping () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
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

    private func statCard(nc: Int, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text("\(nc)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }
}

// MARK: - Contact Row (Dark Theme)
struct ContactRowDarkView: View {
    let contact: NAContact

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.ncCyan.opacity(0.12))
                    .frame(width: 36, height: 36)
                Text(contact.initials)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.ncCyan)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.fullName)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                if let org = contact.organization {
                    Text(org)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                if let days = contact.daysSinceContacted {
                    Text(days == 0 ? "Heute kontaktiert" : "vor \(days) Tagen")
                        .font(.caption2)
                        .foregroundColor(contact.isReachoutDue ? .ncRose : .gray)
                }
            }
            Spacer()
            if let phone = contact.phoneNumbers.first {
                HStack(spacing: 4) {
                    Button { NAContactService.shared.call(phone: phone) } label: {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.ncNeonGreen)
                            .frame(width: 22, height: 22)
                            .background(Color.ncNeonGreen.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                    }
                    Button { NAContactService.shared.openWhatsApp(phone: phone) } label: {
                        Image(systemName: "message.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.ncNeonGreen)
                            .frame(width: 22, height: 22)
                            .background(Color.ncNeonGreen.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding(10)
        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }
}
