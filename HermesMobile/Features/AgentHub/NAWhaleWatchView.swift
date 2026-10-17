import SwiftUI

struct NAWhaleWatchView: View {
    @State private var loaded = false
    @State private var stats = (high: 0, total: 0, volume: 0)
    @State private var allAlerts: [WhaleAlert] = []
    @State private var errorMsg: String? = nil
    @State private var selectedAlert: WhaleAlert? = nil
    @State private var activeFilter: String = "all"

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
        let market_url: String?
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

    var filteredAlerts: [WhaleAlert] {
        switch activeFilter {
        case "HIGH": return allAlerts.filter { $0.confidence == "HIGH" }
        case "MED": return allAlerts.filter { $0.confidence == "MED" }
        case "LOW": return allAlerts.filter { $0.confidence == "LOW" }
        case "large": return allAlerts.filter { $0.size_usd >= 5000 }
        default: return allAlerts
        }
    }

    var body: some View {
        NavigationStack {
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
                    // Stats
                    HStack(spacing: 12) {
                        statCard("HIGH", "\(stats.high)", .ncNeonGreen)
                        statCard("24h", "\(stats.total)", .white)
                        statCard("Vol.", formatVol(stats.volume), .ncCyan)
                    }
                    .padding(.horizontal, 16).padding(.top, 16)

                    // Filter Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            filterChip("All", "all")
                            filterChip("HIGH", "HIGH")
                            filterChip("MED", "MED")
                            filterChip("LOW", "LOW")
                            filterChip(">$5k", "large")
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                    }

                    if filteredAlerts.isEmpty {
                        Text("Keine Alerts").font(.subheadline).foregroundColor(.gray).padding(.top, 40)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 6) {
                                ForEach(filteredAlerts) { alert in
                                    Button { selectedAlert = alert } label: { alertCard(alert) }
                                        .buttonStyle(.plain)
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
            .sheet(item: $selectedAlert) { alert in
                NAWhaleDetailView(alert: alert)
            }
        }
    }

    func filterChip(_ label: String, _ value: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { activeFilter = value }
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(activeFilter == value ? .white : .gray)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(activeFilter == value ? Color.ncCyan : Color(red: 0.03, green: 0.03, blue: 0.06), in: Capsule())
                .overlay(Capsule().stroke(activeFilter == value ? Color.ncCyan : Color.white.opacity(0.08), lineWidth: 0.5))
        }
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
                allAlerts = Array(r.alerts.prefix(50))
                stats = (r.stats?.high_confidence_24h ?? 0,
                        r.stats?.total_alerts_24h ?? 0,
                        r.stats?.total_volume_tracked_24h_usd ?? 0)
                loaded = true
            }
        } catch {
            await MainActor.run {
                errorMsg = "Fehler: \(error.localizedDescription)"
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

// MARK: - Detail View with Graphical Analysis
struct NAWhaleDetailView: View {
    let alert: NAWhaleWatchView.WhaleAlert
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Hero Section
                    heroSection

                    // Confidence Bar
                    confidenceSection

                    // Market Card
                    sectionCard("Markt") {
                        infoRow("Frage", alert.market)
                        if let url = alert.market_url, !url.isEmpty {
                            Link(destination: URL(string: url)!) {
                                HStack {
                                    Image(systemName: "arrow.up.right.square").font(.caption)
                                    Text("Auf Polymarket öffnen").font(.caption).foregroundColor(.ncCyan)
                                }
                            }
                        }
                    }

                    // Wallet Card
                    sectionCard("Wallet") {
                        infoRow("Adresse", alert.wallet)
                        if alert.wallet_age_hours > 0 {
                            infoRow("Alter", "\(Int(alert.wallet_age_hours))h")
                        }
                        // Wallet age bar
                        let agePct = min(Double(alert.wallet_age_hours) / 168.0, 1.0)
                        VStack(spacing: 4) {
                            HStack {
                                Text("Wallet Alter").font(.caption2).foregroundColor(.gray)
                                Spacer()
                                Text(alert.wallet_age_hours < 24 ? "Sehr frisch" : alert.wallet_age_hours < 72 ? "Frisch" : "Etabliert")
                                    .font(.caption2.weight(.medium)).foregroundColor(alert.wallet_age_hours < 24 ? .ncRose : alert.wallet_age_hours < 72 ? .ncAmber : .ncNeonGreen)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.06)).frame(height: 4)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(alert.wallet_age_hours < 24 ? Color.ncRose : alert.wallet_age_hours < 72 ? Color.ncAmber : Color.ncNeonGreen)
                                        .frame(width: geo.size.width * CGFloat(1 - agePct), height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                        .padding(.top, 4)

                        Text("💰 \(formatVol(Int(alert.size_usd))) Position")
                            .font(.system(size: 12, weight: .medium)).foregroundColor(.white).padding(.top, 4)
                    }

                    // Signals Card
                    if !alert.signals.isEmpty {
                        sectionCard("Signale") {
                            ForEach(alert.signals, id: \.self) { signal in
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill").font(.system(size: 12)).foregroundColor(.ncNeonGreen)
                                    Text(signal).font(.subheadline).foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    // Analysis Score Card (graphical)
                    sectionCard("Analyse") {
                        analysisScoreRow("Positionsgröße", score: positionScore(), maxScore: 40, color: .ncCyan)
                        analysisScoreRow("Wallet-Risiko", score: walletScore(), maxScore: 30, color: .ncAmber)
                        analysisScoreRow("Timing", score: timingScore(), maxScore: 20, color: .ncPurple)
                        analysisScoreRow("Signale", score: signalScore(), maxScore: 10, color: .ncNeonGreen)

                        Divider().overlay(Color.white.opacity(0.06)).padding(.vertical, 8)

                        let total = positionScore() + walletScore() + timingScore() + signalScore()
                        let maxTotal = 100
                        HStack {
                            Text("Gesamt-Score").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                            Spacer()
                            Text("\(total)/\(maxTotal)")
                                .font(.title3.weight(.bold)).foregroundColor(scoreColor(total))
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.06)).frame(height: 6)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(LinearGradient(colors: [.ncRose, .ncAmber, .ncNeonGreen], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * CGFloat(total) / CGFloat(maxTotal), height: 6)
                            }
                        }
                        .frame(height: 6)

                        // Confidence Label
                        HStack {
                            Spacer()
                            Text(confidenceLabel(total))
                                .font(.caption.weight(.medium)).foregroundColor(scoreColor(total))
                            Spacer()
                        }
                        .padding(.top, 4)
                    }

                    // Timing Card
                    sectionCard("Zeit") {
                        infoRow("Erkannt", formatDate(alert.detected_at))
                        infoRow("Vor", timeAgo(alert.detected_at))
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 30)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Alert Detail").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Fertig") { dismiss() }.foregroundColor(.ncCyan) } }
        }
    }

    // MARK: - Hero Section
    var heroSection: some View {
        VStack(spacing: 12) {
            // Confidence ring
            ZStack {
                Circle()
                    .stroke(confidenceColor.opacity(0.12), lineWidth: 6)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: confidencePct())
                    .stroke(confidenceColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                Text(alert.confidence.prefix(1))
                    .font(.title2.weight(.bold)).foregroundColor(confidenceColor)
            }

            Text(formatVol(Int(alert.size_usd)))
                .font(.system(size: 40, weight: .ultraLight)).foregroundColor(.white).kerning(-2)

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: alert.side == "BUY" ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.caption).foregroundColor(alert.side == "BUY" ? .ncNeonGreen : .ncRose)
                    Text(alert.side).font(.subheadline.weight(.semibold))
                        .foregroundColor(alert.side == "BUY" ? .ncNeonGreen : .ncRose)
                }
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background((alert.side == "BUY" ? Color.ncNeonGreen : Color.ncRose).opacity(0.1), in: RoundedRectangle(cornerRadius: 6))

                Text(alert.outcome)
                    .font(.subheadline.weight(.medium)).foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))

                Text(alert.confidence)
                    .font(.system(size: 9, weight: .bold)).foregroundColor(confidenceColor)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(confidenceColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Confidence Score Bar
    var confidenceSection: some View {
        sectionCard("Konfidenz") {
            HStack(spacing: 0) {
                ForEach(["LOW", "MED", "HIGH"], id: \.self) { level in
                    VStack(spacing: 4) {
                        Text(level).font(.system(size: 8, weight: .medium)).foregroundColor(level == alert.confidence ? levelColor(level) : .gray.opacity(0.3))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(level == alert.confidence ? levelColor(level) : Color.white.opacity(0.04))
                            .frame(height: level == alert.confidence ? 20 : 8)
                        if level == alert.confidence {
                            Image(systemName: "chevron.down").font(.system(size: 8)).foregroundColor(levelColor(level))
                        }
                    }
                    if level != "HIGH" {
                        Spacer(minLength: 8)
                    }
                }
            }
            .frame(height: 40)

            HStack {
                Text(confidenceDescription())
                    .font(.system(size: 10)).foregroundColor(.gray)
                Spacer()
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Analysis Score Row
    func analysisScoreRow(_ label: String, score: Int, maxScore: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label).font(.caption).foregroundColor(.gray)
                Spacer()
                Text("\(score)/\(maxScore)").font(.caption.weight(.medium)).foregroundColor(scoreColor(score))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.04)).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(scoreColor(score))
                        .frame(width: geo.size.width * CGFloat(score) / CGFloat(maxScore), height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Section Card
    func sectionCard<Content: View>(_ title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .medium)).foregroundColor(.gray).kerning(1.5)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
    }

    func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).font(.caption).foregroundColor(.gray).frame(width: 60, alignment: .leading)
            Text(value).font(.subheadline).foregroundColor(.white)
            Spacer()
        }
    }

    // MARK: - Scoring
    func positionScore() -> Int {
        let s = Int(alert.size_usd)
        if s >= 25000 { return 40 }
        if s >= 15000 { return 35 }
        if s >= 10000 { return 30 }
        if s >= 5000 { return 20 }
        return 10
    }

    func walletScore() -> Int {
        let h = alert.wallet_age_hours
        if h < 1 { return 30 }
        if h < 6 { return 25 }
        if h < 24 { return 20 }
        if h < 72 { return 10 }
        return 5
    }

    func timingScore() -> Int {
        let hasNiche = alert.signals.contains { $0.contains("Niche") || $0.contains("niche") || $0.contains("timing") }
        if hasNiche { return 20 }
        return 5
    }

    func signalScore() -> Int {
        let count = alert.signals.count
        return min(count * 3, 10)
    }

    func confidencePct() -> CGFloat {
        let total = positionScore() + walletScore() + timingScore() + signalScore()
        return CGFloat(total) / 100.0
    }

    func scoreColor(_ score: Int) -> Color {
        if score >= 70 { return .ncNeonGreen }
        if score >= 40 { return .ncAmber }
        return .ncRose
    }

    func levelColor(_ level: String) -> Color {
        level == "HIGH" ? .ncNeonGreen : level == "MED" ? .ncAmber : .ncRose
    }

    var confidenceColor: Color {
        alert.confidence == "HIGH" ? .ncNeonGreen : alert.confidence == "MED" ? .ncAmber : .ncRose
    }

    func confidenceDescription() -> String {
        let total = positionScore() + walletScore() + timingScore() + signalScore()
        if total >= 70 { return "Hohe Konfidenz – mehrere starke Signale deuten auf echte Whale-Aktivität hin" }
        if total >= 40 { return "Mittlere Konfidenz – einige Signale vorhanden, weitere Beobachtung empfohlen" }
        return "Niedrige Konfidenz – schwache Signale, möglicherweise Rauschen"
    }

    func confidenceLabel(_ total: Int) -> String {
        if total >= 70 { return "🟢 Hohe Relevanz – Whale Alert ernst nehmen" }
        if total >= 40 { return "🟡 Mittlere Relevanz – Beobachten" }
        return "🔴 Geringe Relevanz"
    }

    func formatVol(_ v: Int) -> String {
        if v >= 1000 { return "$\(v/1000)k" }
        return "$\(v)"
    }

    func formatDate(_ iso: String) -> String {
        guard let d = ISO8601DateFormatter().date(from: iso) else { return iso }
        let df = DateFormatter()
        df.dateFormat = "dd.MM.yy HH:mm"
        return df.string(from: d)
    }

    func timeAgo(_ iso: String) -> String {
        guard let d = ISO8601DateFormatter().date(from: iso) else { return "" }
        let sec = Int(Date().timeIntervalSince(d))
        if sec < 60 { return "\(sec)s" }
        if sec < 3600 { return "\(sec/60)m" }
        if sec < 86400 { return "\(sec/3600)h" }
        return "\(sec/86400)d"
    }
}