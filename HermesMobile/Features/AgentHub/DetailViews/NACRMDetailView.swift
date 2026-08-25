import SwiftUI

// MARK: - CRM Detail View
struct NACRMDetailView: View {
    @ObservedObject private var rollup = NARollupService.shared
    @State private var clients: [NCRMClient] = []
    @State private var isLoading = false
    @State private var selectedTab = 0
    @State private var searchText = ""

    private let baseURL = "https://health.santoslab.de/api/crm"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Header Stats
                if let c = rollup.crm {
                    HStack(spacing: 12) {
                        statBox("\(c.total_clients ?? 0)", "Kunden", .ncGreen)
                        statBox("\(c.active ?? 0)", "Aktiv", .ncSage)
                        statBox("\(c.won_deals ?? 0)", "Gewonnen", .ncGold)
                    }
                    HStack(spacing: 12) {
                        if let val = c.total_value_eur {
                            statBox("\(val)€", "Wert", .ncDark)
                        }
                        if let rev = c.revenue_eur {
                            statBox("\(rev)€", "Einnahmen", .ncGreen)
                        }
                        if let pending = c.cold_calls_pending {
                            statBox("\(pending)", "Offene Calls", .ncRed)
                        }
                    }
                }

                // Alerts
                if let alerts = rollup.crm?.alerts, !alerts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Alarme").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                        ForEach(alerts.prefix(3)) { alert in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(alert.title ?? "").font(.subheadline.weight(.medium)).foregroundColor(.ncRed)
                                Text(alert.summary ?? "").font(.caption).foregroundColor(.ncMuted).lineLimit(2)
                            }
                            .padding(10)
                            .background(Color.ncRed.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.ncRed.opacity(0.15)))
                        }
                    }.warmCard()
                }

                // Client List
                VStack(alignment: .leading, spacing: 8) {
                    Text("Kunden (\(clients.count))").font(.headline.weight(.semibold)).foregroundColor(.ncDark)

                    HStack {
                        Image(systemName: "magnifyingglass").font(.caption).foregroundColor(.ncSand)
                        TextField("Suchen...", text: $searchText).font(.subheadline)
                    }
                    .padding(10)
                    .background(Color.ncPaper, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.ncSand.opacity(0.3)))

                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        let filtered = searchText.isEmpty ? clients : clients.filter { $0.name.localizedCaseInsensitiveContains(searchText) || ($0.company ?? "").localizedCaseInsensitiveContains(searchText) }
                        if filtered.isEmpty {
                            Text("Keine Kunden gefunden.").font(.subheadline).foregroundColor(.ncMuted)
                        } else {
                            ForEach(filtered.prefix(20)) { client in
                                clientRow(client)
                            }
                        }
                    }
                }.warmCard()
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }
        .warmBackground()
        .navigationTitle("CRM")
        .navigationBarTitleDisplayMode(.large)
        .task { await loadClients() }
    }

    private func loadClients() async {
        isLoading = true
        guard let url = URL(string: "\(baseURL)/clients") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(NCRMClientList.self, from: data)
            clients = response.clients
        } catch {}
        isLoading = false
    }

    private func statBox(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.weight(.bold)).foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.ncMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private func clientRow(_ client: NCRMClient) -> some View {
        HStack(spacing: 10) {
            Circle().fill(statusColor(client.status ?? "")).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(client.name).font(.subheadline.weight(.medium)).foregroundColor(.ncDark)
                if let c = client.company, !c.isEmpty {
                    Text(c).font(.caption).foregroundColor(.ncMuted)
                }
            }
            Spacer()
            if let v = client.value, v > 0 {
                Text("\(v)€").font(.subheadline.weight(.bold)).foregroundColor(.ncGreen)
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private func statusColor(_ s: String) -> Color {
        switch s {
        case "active": return .ncGreen
        case "won": return .ncGold
        case "lost": return .ncRed
        case "dormant": return .ncSand
        default: return .ncMuted
        }
    }
}