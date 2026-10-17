import SwiftUI

struct NAWhaleWatchView: View {
    @State private var loaded = false
    @State private var stats = (high: 0, total: 0, volume: 0)
    @State private var alerts: [WhaleAlert] = []
    @State private var errorMsg: String? = nil

    struct WhaleAlert: Codable, Identifiable {
        let id: Int
        let confidence: String
        let market: String
        let side: String
        let outcome: String
        let size_usd: Double
        let wallet: String
        let wallet_age_hours: Double
        let signals: [String]
        let detected_at: String
    }

    struct Response: Codable {
        let alerts: [WhaleAlert]
        let stats: Stats?
    }
    struct Stats: Codable {
        let high_confidence_24h: Int
        let total_alerts_24h: Int
        let total_volume_tracked_24h_usd: Int
    }

    var body: some View {
        VStack(spacing: 0) {
            if let err = errorMsg {
                Spacer()
                Image(systemName: "exclamationmark.triangle.fill").font(.title2).foregroundColor(.gray)
                Text(err).font(.caption).foregroundColor(.gray).multilineTextAlignment(.center).padding(.horizontal, 40)
                Spacer()
            } else if !loaded {
                Spacer()
                ProgressView().tint(.ncCyan)
                Text("Lade Whale Alerts...").font(.caption).foregroundColor(.gray)
                Spacer()
            } else {
                HStack(spacing: 12) {
                    statCard("HIGH", "\(stats.high)", .ncNeonGreen)
                    statCard("24h", "\(stats.total)", .white)
                    statCard("Vol.", formatVol(stats.volume), .ncCyan)
                }
                .padding(.horizontal, 16).padding(.top, 20)

                if alerts.isEmpty {
                    Text("Keine Alerts in den letzten 24h").font(.subheadline).foregroundColor(.gray).padding(.top, 40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(alerts) { alert in
                                alertCard(alert)
                            }
                        }
                        .padding(.horizontal, 16).padding(.bottom, 20)
                    }
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Whale Watch").navigationBarTitleDisplayMode(.inline)
        .task { await fetch() }
    }

    func statCard(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.semibold)).foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity).padding(12)
        .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.05), lineWidth: 0.5))
    }

    func alertCard(_ a: WhaleAlert) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(a.confidence)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(a.confidence == "HIGH" ? .ncNeonGreen : a.confidence == "MED" ? .ncAmber : .ncRose)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background((a.confidence == "HIGH" ? Color.ncNeonGreen : a.confidence == "MED" ? Color.ncAmber : Color.ncRose).opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
                Spacer()
                Text(timeAgo(a.detected_at)).font(.system(size: 9)).foregroundColor(.gray.opacity(0.5))
            }
            Text(formatVol(Int(a.size_usd)) + " " + a.side + " " + a.outcome)
                .font(.subheadline.weight(.medium)).foregroundColor(.white)
            Text(a.market).font(.caption).foregroundColor(.gray).lineLimit(1)
            if a.wallet_age_hours > 0 {
                Text("Wallet \(a.wallet.prefix(10))... · Fresh \(Int(a.wallet_age_hours))h")
                    .font(.system(size: 8)).foregroundColor(.gray.opacity(0.5))
            }
            if !a.signals.isEmpty {
                HStack(spacing: 3) {
                    ForEach(a.signals, id: \.self) { s in
                        Text(s).font(.system(size: 7)).foregroundColor(.gray.opacity(0.4))
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 2))
                    }
                }
            }
        }
        .padding(12)
        .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }

    func fetch() async {
        do {
            let url = URL(string: "https://health.santoslab.de/api/naice/polymarket/alerts")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let r = try JSONDecoder().decode(Response.self, from: data)
            await MainActor.run {
                alerts = r.alerts.prefix(50).map { $0 }
                stats = (r.stats?.high_confidence_24h ?? 0,
                        r.stats?.total_alerts_24h ?? 0,
                        r.stats?.total_volume_tracked_24h_usd ??0)
                loaded = true
            }
        } catch {
            await MainActor.run {
                errorMsg = "Network error: \(error.localizedDescription)"
                loaded = true
            }
        }
    }

    func formatVol(_ v: Int) -> String {
        if v >= 1000 { return "$\(v/1000)k" }
        return "$\(v)"
    }

    func timeAgo(_ iso: String) -> String {
        guard let d = ISO8601DateFormatter().date(from: iso) else { return "" }
        let sec = Int(Date().timeIntervalSince(d))
        if sec < 60 { return "\(sec)s" }
        if sec < 3600 { return "\(sec/60)m" }
        return "\(sec/3600)h"
    }
}