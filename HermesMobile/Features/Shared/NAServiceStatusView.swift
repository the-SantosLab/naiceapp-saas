import SwiftUI

// MARK: - Service Status View
struct NAServiceStatusView: View {
    @State private var services: [String: ServiceStatus] = [:]
    @State private var caddyStatus: ServiceStatus? = nil
    @State private var healthy: Bool = false
    @State private var isLoading = true
    @State private var lastRefresh = Date()

    private let serverURL = "https://health.santoslab.de/api/naice/health/check"

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Service Status")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                        Text(lastRefresh, style: .time)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView().scaleEffect(0.7).tint(.ncCyan)
                        }
                        if healthy {
                            statusBadge("Alles OK", .ncNeonGreen)
                        } else {
                            statusBadge("Probleme", .ncRose)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Summary Card
                summaryCard

                // Service List
                VStack(alignment: .leading, spacing: 12) {
                    Text("Dienste")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.gray)
                        .textCase(.uppercase)
                        .tracking(1)
                        .padding(.horizontal, 4)

                    ForEach(Array(services.keys.sorted()), id: \.self) { name in
                        if let s = services[name] {
                            serviceRow(name: name, status: s)
                        }
                    }

                    if let caddy = caddyStatus {
                        Divider().background(Color.white.opacity(0.06))
                        serviceRow(name: "caddy (external)", status: caddy)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                )
                .padding(.horizontal, 16)

                // Health Check Info
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption)
                            .foregroundColor(.ncCyan)
                        Text("Über diesen Check")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                    }
                    Text("Alle 10 Minuten prüft ein Watchdog auf dem Server die Dienste und startet tote Dienste automatisch neu. Hier siehst du den Live-Status aller nAIce-Komponenten.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineSpacing(4)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.ncCyan.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.ncCyan.opacity(0.1), lineWidth: 0.5))
                )
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 30)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
        .refreshable { await refresh() }
    }

    private var summaryCard: some View {
        let total = services.count + (caddyStatus != nil ? 1 : 0)
        let ok = services.values.filter { $0.ok }.count + (caddyStatus?.ok == true ? 1 : 0)

        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 5)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: total > 0 ? CGFloat(ok) / CGFloat(total) : 0)
                    .stroke(healthy ? Color.ncNeonGreen : Color.ncRose,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                Image(systemName: healthy ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.system(size: 18))
                    .foregroundColor(healthy ? .ncNeonGreen : .ncRose)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(ok)/\(total) Dienste verfügbar")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                Text(healthy ? "Alle Systeme laufen stabil" : "Einige Dienste haben Probleme")
                    .font(.caption)
                    .foregroundColor(healthy ? .ncNeonGreen : .ncRose)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 20)
                    .stroke(healthy ? Color.ncNeonGreen.opacity(0.15) : Color.ncRose.opacity(0.15), lineWidth: 0.5))
        )
        .padding(.horizontal, 16)
    }

    private func serviceRow(name: String, status: ServiceStatus) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(status.ok ? Color.ncNeonGreen.opacity(0.12) : Color.ncRose.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: status.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(status.ok ? .ncNeonGreen : .ncRose)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(serviceDisplayName(name))
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                Text(status.message)
                    .font(.caption2)
                    .foregroundColor(status.ok ? .gray : .ncRose)
            }

            Spacer()

            Text(status.ok ? "Online" : "Offline")
                .font(.caption2.weight(.semibold))
                .foregroundColor(status.ok ? .ncNeonGreen : .ncRose)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(status.ok ? Color.ncNeonGreen.opacity(0.1) : Color.ncRose.opacity(0.1))
                )
        }
        .padding(12)
        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }

    private func statusBadge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func serviceDisplayName(_ raw: String) -> String {
        switch raw {
        case "naice": return "nAIce Agent"
        case "whoop": return "WHOOP API"
        case "push": return "Push Service"
        case "cockpit": return "Amelia Cockpit"
        case "caddy": return "Caddy (External)"
        default: return raw
        }
    }

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }
        guard let url = URL(string: serverURL) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                var newServices: [String: ServiceStatus] = [:]
                for (key, value) in result {
                    if key == "healthy" { continue }
                    if key == "caddy" {
                        if let dict = value as? [String: Any] {
                            caddyStatus = ServiceStatus(
                                ok: dict["ok"] as? Bool ?? false,
                                message: dict["message"] as? String ?? "?"
                            )
                        }
                        continue
                    }
                    if let dict = value as? [String: Any] {
                        newServices[key] = ServiceStatus(
                            ok: dict["ok"] as? Bool ?? false,
                            message: dict["message"] as? String ?? "?"
                        )
                    }
                }
                services = newServices
                healthy = result["healthy"] as? Bool ?? false
                lastRefresh = Date()
            }
        } catch {
            services = ["error": ServiceStatus(ok: false, message: error.localizedDescription)]
            healthy = false
        }
    }
}

// MARK: - Service Status Model
struct ServiceStatus {
    let ok: Bool
    let message: String
}

// MARK: - Previews
#Preview {
    NAServiceStatusView()
}