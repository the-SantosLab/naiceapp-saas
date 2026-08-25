import SwiftUI

// MARK: - Business Overview (alle 4 Projekte)
struct BusinessOverview: View {
    @ObservedObject private var rollup = NARollupService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Business").font(.title2.weight(.bold)).foregroundColor(.ncDark)
                Text("Übersicht aller Projekte und Pipeline.").font(.subheadline).foregroundColor(.ncMuted)

                if let b = rollup.business {
                    // Foodloop
                    if let f = b.foodloop {
                        NavigationLink(destination: BusinessPipelineView(project: f, name: "foodloop")) {
                            projectCard(icon: "fork.knife", name: "Foodloop", total: f.total, hot: f.hot ?? 0, statuses: f.statuses ?? [:])
                        }.buttonStyle(.plain)
                    }

                    // nAIce
                    if let n = b.naice {
                        NavigationLink(destination: BusinessPipelineView(project: n, name: "nAIce")) {
                            projectCard(icon: "brain.head.profile", name: "nAIce", total: n.total, hot: n.hot ?? 0, statuses: n.statuses ?? [:])
                        }.buttonStyle(.plain)
                    }

                    // Schaffer Wine
                    if let s = b.schaffer {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Schaffer Wine").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                            HStack(spacing: 16) {
                                if let l = s.b2b_leads { mini("person.badge.plus", "\(l)", "B2B") }
                                if let p = s.pageviews_today { mini("eye", "\(p)", "Views") }
                                if let sub = s.subscribers { mini("person.2", "\(sub)", "Abos") }
                                if let o = s.orders { mini("cart", "\(o)", "Orders") }
                            }
                        }.warmCard()
                    }

                    // Parcelmate
                    if let p = b.parcelmate {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Parcelmate").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                            HStack(spacing: 16) {
                                if let u = p.users { mini("person.3", "\(u)", "Users") }
                                if let sh = p.shipments { mini("shippingbox", "\(sh)", "Shipments") }
                                if let n = p.newsletter_leads { mini("envelope", "\(n)", "Leads") }
                            }
                        }.warmCard()
                    }

                    // Deals from Rollup
                    if let d = rollup.deals, d.active_deals > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Deals").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                                Spacer()
                                Text("\(d.active_deals) aktiv · \(d.total_value_eur) €").font(.subheadline).foregroundColor(.ncGreen)
                            }
                            ForEach(d.deals?.prefix(5) ?? []) { deal in
                                NavigationLink(destination: DealDetailView(deal: deal)) {
                                    HStack(spacing: 10) {
                                        Circle().fill(statusColor(deal.status ?? "")).frame(width: 8, height: 8)
                                        Text(deal.name).font(.subheadline).foregroundColor(.ncDark)
                                        Spacer()
                                        Text("\(deal.value) €").font(.subheadline.weight(.bold)).foregroundColor(.ncGreen)
                                        Image(systemName: "chevron.right").font(.caption2).foregroundColor(.ncSand)
                                    }
                                }.buttonStyle(.plain)
                            }
                        }.warmCard()
                    }
                } else {
                    Text("Lade Business-Daten...").font(.subheadline).foregroundColor(.ncMuted)
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }
        .warmBackground()
        .navigationTitle("Business")
        .navigationBarTitleDisplayMode(.large)
    }

    private func projectCard(icon: String, name: String, total: Int, hot: Int, statuses: [String: Int]) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundColor(.ncSage).frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(name.capitalized).font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                Text("\(total) Kontakte · \(hot) heiss (\(hot > 0 ? Int(Double(hot)/Double(total)*100) : 0)%)")
                    .font(.caption).foregroundColor(.ncMuted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundColor(.ncSand)
        }.warmCard()
    }

    private func statusColor(_ s: String) -> Color {
        switch s.lowercased() {
        case "aktiv": return .ncGreen
        case "angebot": return .ncGold
        case "beauftragt": return .blue
        default: return .ncMuted
        }
    }
}

// MARK: - Business Pipeline Detail
struct BusinessPipelineView: View {
    let project: NABusinessProject
    let name: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(name.capitalized).font(.title2.weight(.bold)).foregroundColor(.ncDark)
                Text("Pipeline Übersicht").font(.subheadline).foregroundColor(.ncMuted)

                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(project.total)").font(.title.weight(.bold)).foregroundColor(.ncGreen)
                        Text("Kontakte gesamt").font(.caption).foregroundColor(.ncMuted)
                    }
                    Spacer()
                    if let h = project.hot, h > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(h)").font(.title.weight(.bold)).foregroundColor(.ncRed)
                            Text("heiss (\(Int(Double(h)/Double(project.total)*100))%)").font(.caption).foregroundColor(.ncMuted)
                        }
                    }
                }.warmCard()

                // Statuses
                if let statuses = project.statuses, !statuses.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                        ForEach(Array(statuses.sorted(by: { $0.value > $1.value })), id: \.key) { key, count in
                            VStack(spacing: 4) {
                                HStack {
                                    Text(key.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .font(.subheadline).foregroundColor(.ncDark)
                                    Spacer()
                                    Text("\(count)").font(.subheadline.weight(.bold)).foregroundColor(.ncDark)
                                }
                                ProgressView(value: Double(count) / Double(project.total))
                                    .tint(key == "hot" ? .ncRed : key == "pitched" ? .ncGold : .ncGreen)
                            }
                        }
                    }.warmCard()
                }

                // Emails
                if let emails = project.emails, !emails.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email-Statistik").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                        ForEach(Array(emails.sorted(by: { $0.key < $1.key })), id: \.key) { key, count in
                            HStack {
                                Text(key.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.subheadline).foregroundColor(.ncDark)
                                Spacer()
                                Text("\(count)").font(.subheadline.weight(.bold)).foregroundColor(.ncGreen)
                            }
                        }
                        if let pt = project.pitched_today {
                            HStack {
                                Text("Heute gepitcht").font(.subheadline).foregroundColor(.ncDark)
                                Spacer()
                                Text("\(pt)").font(.subheadline.weight(.bold)).foregroundColor(.ncGold)
                            }
                        }
                        if let rw = project.replies_week {
                            HStack {
                                Text("Antworten diese Woche").font(.subheadline).foregroundColor(.ncDark)
                                Spacer()
                                Text("\(rw)").font(.subheadline.weight(.bold)).foregroundColor(.ncGreen)
                            }
                        }
                    }.warmCard()
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }
        .warmBackground()
        .navigationTitle(name.capitalized)
        .navigationBarTitleDisplayMode(.inline)
    }
}