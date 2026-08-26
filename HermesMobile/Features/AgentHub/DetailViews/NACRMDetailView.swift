import SwiftUI

// MARK: - CRM Detail View (Dark Theme + Knowledge)
struct NACRMDetailView: View {
    @ObservedObject private var rollup = NARollupService.shared
    @State private var clients: [NCRMClient] = []
    @State private var isLoading = false
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var showKnowledge = false
    @State private var knowledgeClient: NCRMClient? = nil

    private let baseURL = "https://health.santoslab.de/api/crm"

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CRM").font(.title2.weight(.bold)).foregroundColor(.white)
                        Text("Deine Kunden- und Pipeline-Ubersicht.").font(.subheadline).foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Header Stats
                if let c = rollup.crm {
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            statBox("\(c.total_clients ?? 0)", "Kunden", .ncCyan)
                            statBox("\(c.active ?? 0)", "Aktiv", .ncNeonGreen)
                            statBox("\(c.won_deals ?? 0)", "Gewonnen", .ncAmber)
                        }
                        HStack(spacing: 10) {
                            if let val = c.total_value_eur { statBox("\(val)€", "Wert", .white) }
                            if let rev = c.revenue_eur { statBox("\(rev)€", "Einnahmen", .ncNeonGreen) }
                            if let pending = c.cold_calls_pending { statBox("\(pending)", "Offene Calls", .ncRose) }
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

                // Alerts
                if let alerts = rollup.crm?.alerts, !alerts.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").font(.caption).foregroundColor(.ncRose)
                            Text("Alarme").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                        }
                        ForEach(alerts.prefix(3)) { alert in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(alert.title ?? "").font(.subheadline.weight(.medium)).foregroundColor(.ncRose)
                                Text(alert.summary ?? "").font(.caption).foregroundColor(.gray).lineLimit(2)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.ncRose.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.ncRose.opacity(0.15)))
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

                // Client List
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.3.fill").font(.caption).foregroundColor(.ncCyan)
                        Text("Kunden (\(clients.count))").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                    }

                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass").font(.caption).foregroundColor(.gray)
                        TextField("Suchen...", text: $searchText).font(.subheadline).foregroundColor(.white)
                    }
                    .padding(10)
                    .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 0.5))

                    if isLoading {
                        ProgressView().tint(.ncCyan).frame(maxWidth: .infinity)
                    } else {
                        let filtered = searchText.isEmpty ? clients : clients.filter { $0.name.localizedCaseInsensitiveContains(searchText) || ($0.company ?? "").localizedCaseInsensitiveContains(searchText) }
                        if filtered.isEmpty {
                            Text("Keine Kunden gefunden.").font(.subheadline).foregroundColor(.gray)
                                .padding(.vertical, 20).frame(maxWidth: .infinity)
                        } else {
                            VStack(spacing: 6) {
                                ForEach(filtered.prefix(20)) { client in
                                    clientRow(client)
                                }
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
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 30)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadClients() }
        .sheet(isPresented: $showKnowledge) {
            if let client = knowledgeClient {
                NAKnowledgeSheet(clientName: client.name, clientCompany: client.company)
            }
        }
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
            Text(value).font(.system(size: 15, weight: .bold)).foregroundColor(color)
            Text(label).font(.system(size: 9)).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }

    private func clientRow(_ client: NCRMClient) -> some View {
        HStack(spacing: 10) {
            Circle().fill(statusColor(client.status ?? "")).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(client.name).font(.subheadline.weight(.medium)).foregroundColor(.white)
                if let c = client.company, !c.isEmpty {
                    Text(c).font(.caption).foregroundColor(.gray)
                }
            }
            Spacer()

            // Wissen Button
            Button {
                knowledgeClient = client
                showKnowledge = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "brain.head.profile").font(.system(size: 8))
                    Text("Wissen").font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(.ncCyan)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.ncCyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            if let v = client.value, v > 0 {
                Text("\(v)€").font(.subheadline.weight(.bold)).foregroundColor(.ncNeonGreen)
                    .padding(.leading, 4)
            }
        }
        .padding(8)
        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }

    private func statusColor(_ s: String) -> Color {
        switch s {
        case "active": return .ncNeonGreen
        case "won": return .ncAmber
        case "lost": return .ncRose
        case "dormant": return .gray
        default: return .gray
        }
    }
}