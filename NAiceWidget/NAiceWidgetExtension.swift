import WidgetKit
import SwiftUI

// MARK: - Widget Data Models (server-driven — full nAIce data)
struct NAiceWidgetData: Codable {
    let cardType: String; let cardTitle: String; let cardMessage: String?; let cardIcon: String
    let balanceScore: Int; let recoveryScore: Int; let hrv: Int; let rhr: Int
    let strain: Double; let sleepHours: Double; let sleepEfficiency: Double
    let respiratoryRate: Double; let spo2: Double
    let nextEvent: String?; let eventsToday: Int; let unreadWA: Int
    let tasksActive: Int; let tasksTotal: Int
    let business: NAiceBusinessData?
    let actions: [NAiceWidgetAction]

    static var empty: NAiceWidgetData {
        NAiceWidgetData(
            cardType: "morning", cardTitle: "☀️ Guten Morgen", cardMessage: "nAIce ist bereit.", cardIcon: "n.square.fill",
            balanceScore: 70, recoveryScore: 0, hrv: 0, rhr: 0,
            strain: 0, sleepHours: 0, sleepEfficiency: 0, respiratoryRate: 0, spo2: 0,
            nextEvent: "", eventsToday: 0, unreadWA: 0, tasksActive: 0, tasksTotal: 0,
            business: nil,
            actions: [
                NAiceWidgetAction(id: "chat", icon: "bubble.left.and.bubble.right", label: "Agent", url: "naice://chat"),
                NAiceWidgetAction(id: "mood", icon: "face.smiling", label: "Stimmung", url: "naice://mood"),
            ]
        )
    }

    static func fetch() async -> NAiceWidgetData {
        guard let url = URL(string: "https://health.santoslab.de/api/naice/widget-data") else { return .empty }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(NAiceWidgetData.self, from: data)
        } catch {
            return .empty
        }
    }

    // Color helpers
    var recoveryColor: Color { recoveryScore >= 67 ? .green : recoveryScore >= 34 ? .orange : .red }

    var recoveryLabel: String {
        recoveryScore >= 80 ? "Hervorragend" : recoveryScore >= 67 ? "Gut" : recoveryScore >= 34 ? "Mittel" : "Erholung nötig"
    }
}

struct NAiceBusinessData: Codable {
    let naice_total: Int; let naice_pitched_today: Int
    let foodloop_total: Int; let foodloop_hot: Int
    let schaffer_views: Int; let schaffer_subscribers: Int; let schaffer_orders: Int
    let parcelmate_users: Int; let parcelmate_shipments: Int
    let deals_active: Int; let deals_total_value: Int
    let deals: [NAiceDealItem]?
}

struct NAiceDealItem: Codable {
    let name: String; let value: Int; let status: String
}

struct NAiceWidgetAction: Codable {
    let id: String; let icon: String; let label: String; let url: String
}

// MARK: - Timeline Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> NAiceEntry {
        NAiceEntry(date: Date(), data: .empty, size: context.displaySize)
    }

    func getSnapshot(in context: Context, completion: @escaping (NAiceEntry) -> Void) {
        Task { let data = await NAiceWidgetData.fetch(); let entry = NAiceEntry(date: Date(), data: data, size: context.displaySize); completion(entry) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NAiceEntry>) -> Void) {
        Task {
            let data = await NAiceWidgetData.fetch()
            let entry = NAiceEntry(date: Date(), data: data, size: context.displaySize)
            let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

struct NAiceEntry: TimelineEntry {
    let date: Date
    let data: NAiceWidgetData
    let size: CGSize?
}

// MARK: - Dispatcher — routes to the correct widget by family
struct NAiceWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                MomentaufnahmeView(d: entry.data)
            case .systemMedium:
                TagesueberblickView(d: entry.data)
            case .systemLarge:
                BusinessPipelineView(d: entry.data)
            case .accessoryCircular:
                LockScreenCircularView(d: entry.data)
            case .accessoryRectangular:
                LockScreenRectangularView(d: entry.data)
            case .accessoryInline:
                LockScreenInlineView(d: entry.data)
            @unknown default:
                MomentaufnahmeView(d: entry.data)
            }
        }
        .containerBackground(for: .widget) { Color.black }
    }
}

// ════════════════════════════════════════════
//  WIDGET 1: Momentaufnahme (Small)
// ════════════════════════════════════════════
struct MomentaufnahmeView: View {
    let d: NAiceWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "n.square.fill").font(.caption).foregroundColor(.ncCyan)
                Text("nAIce").font(.caption.weight(.bold)).foregroundColor(.white)
                Spacer()
            }

            // Recovery row
            HStack(spacing: 6) {
                Circle().fill(d.recoveryColor).frame(width: 8, height: 8)
                Text("\(d.recoveryScore)% Recovery").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                Spacer()
            }

            // Health row
            HStack(spacing: 8) {
                Label("\(d.hrv)", systemImage: "heart.fill").font(.system(size: 9)).foregroundColor(.gray)
                Label("\(d.rhr)", systemImage: "figure.stand").font(.system(size: 9)).foregroundColor(.gray)
                if d.sleepHours > 0 { Label("\(d.sleepHours, specifier: "%.1f")h", systemImage: "moon.fill").font(.system(size: 9)).foregroundColor(.gray) }
            }

            // Divider
            Color.white.opacity(0.08).frame(height: 1)

            // Next event or task count
            if let ev = d.nextEvent, !ev.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "calendar").font(.system(size: 8)).foregroundColor(.ncCyan)
                    Text(ev).font(.system(size: 9)).foregroundColor(.gray).lineLimit(1)
                }
            }
            if d.tasksActive > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "checklist").font(.system(size: 8)).foregroundColor(.ncAmber)
                    Text("\(d.tasksActive) Tasks offen").font(.system(size: 9)).foregroundColor(.gray)
                }
            }

            Spacer(minLength: 0)

            // Quick Action Buttons
            HStack(spacing: 4) {
                ForEach(d.actions.prefix(4), id: \.id) { a in
                    Link(destination: URL(string: a.url)!) {
                        VStack(spacing: 1) {
                            Image(systemName: a.icon).font(.system(size: 9)).foregroundColor(.ncCyan)
                            Text(a.label).font(.system(size: 6)).foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(Color.ncCyan.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .padding(12)
    }
}

// ════════════════════════════════════════════
//  WIDGET 2: Tagesüberblick (Medium)
// ════════════════════════════════════════════
struct TagesueberblickView: View {
    let d: NAiceWidgetData

    var body: some View {
        HStack(spacing: 12) {
            // Left: WHOOP + Business
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "n.square.fill").font(.caption).foregroundColor(.ncCyan)
                    Text("nAIce").font(.caption.weight(.bold)).foregroundColor(.white)
                    Spacer()
                }
                .padding(.bottom, 2)

                // Recovery with ring
                HStack(spacing: 10) {
                    ZStack {
                        Circle().stroke(d.recoveryColor.opacity(0.2), lineWidth: 4).frame(width: 36, height: 36)
                        Circle().trim(from: 0, to: CGFloat(d.recoveryScore) / 100)
                            .stroke(d.recoveryColor, lineWidth: 4).frame(width: 36, height: 36).rotationEffect(.degrees(-90))
                        Text("\(d.recoveryScore)").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(d.recoveryScore)% Recovery").font(.system(size: 11, weight: .semibold)).foregroundColor(.white)
                        Text("HRV \(d.hrv) · RHR \(d.rhr)").font(.system(size: 8)).foregroundColor(.gray)
                        if d.sleepHours > 0 { Text("🌙 \(d.sleepHours, specifier: "%.1f")h · ⚡ \(d.strain, specifier: "%.1f")").font(.system(size: 8)).foregroundColor(.gray) }
                    }
                }

                Color.white.opacity(0.06).frame(height: 1)

                // Business summary
                HStack(spacing: 6) {
                    if let b = d.business {
                        HStack(spacing: 2) { Image(systemName: "brain.head.profile").font(.system(size: 7)); Text("\(b.naice_total)").font(.system(size: 8)) }.foregroundColor(.gray)
                        HStack(spacing: 2) { Image(systemName: "fork.knife").font(.system(size: 7)); Text("\(b.foodloop_total)").font(.system(size: 8)) }.foregroundColor(.gray)
                        HStack(spacing: 2) { Image(systemName: "chart.bar.fill").font(.system(size: 7)); Text("\(b.deals_active)/\(b.deals_total_value/1000)k").font(.system(size: 8)) }.foregroundColor(.gray)
                        HStack(spacing: 2) { Image(systemName: "message.fill").font(.system(size: 7)); Text("\(d.unreadWA)").font(.system(size: 8)) }.foregroundColor(d.unreadWA > 0 ? .orange : .gray)
                    }
                }

                Spacer(minLength: 0)

                // Quick actions
                HStack(spacing: 4) {
                    ForEach(d.actions.prefix(4), id: \.id) { a in
                        Link(destination: URL(string: a.url)!) {
                            HStack(spacing: 3) {
                                Image(systemName: a.icon).font(.system(size: 7)).foregroundColor(.ncCyan)
                                Text(a.label).font(.system(size: 7)).foregroundColor(.gray)
                            }
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Color.ncCyan.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }

            Divider().background(Color.white.opacity(0.1))

            // Right: Tasks + Events
            VStack(alignment: .leading, spacing: 6) {
                if d.tasksActive > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 8)).foregroundColor(.ncAmber)
                        Text("\(d.tasksActive) offene Tasks").font(.system(size: 10, weight: .semibold)).foregroundColor(.white)
                    }
                } else {
                    Text("Keine offenen Tasks").font(.system(size: 10)).foregroundColor(.gray)
                }

                if d.eventsToday > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar").font(.system(size: 8)).foregroundColor(.ncCyan)
                        Text("\(d.eventsToday) Termine heute").font(.system(size: 10)).foregroundColor(.gray)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar").font(.system(size: 8)).foregroundColor(.gray)
                        Text("Keine Termine").font(.system(size: 9)).foregroundColor(.gray)
                    }
                }

                Spacer(minLength: 0)

                // Deal mini-progress bars
                if let deals = d.business?.deals, !deals.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Deals").font(.system(size: 8)).foregroundColor(.gray).textCase(.uppercase)
                        ForEach(deals.prefix(3), id: \.name) { deal in
                            HStack(spacing: 4) {
                                Text(deal.name).font(.system(size: 7)).foregroundColor(.gray).frame(width: 50, alignment: .leading).lineLimit(1)
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.06)).frame(height: 4)
                                        RoundedRectangle(cornerRadius: 2).fill(Color.ncCyan).frame(width: geo.size.width * CGFloat(deal.value) / 105000, height: 4)
                                    }
                                }
                                .frame(height: 4)
                                Text("\(deal.value/1000)k").font(.system(size: 6)).foregroundColor(.gray).frame(width: 30, alignment: .trailing)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
    }
}

// ════════════════════════════════════════════
//  WIDGET 3: Nur WHOOP (Small — Big Ring)
// ════════════════════════════════════════════
struct NurWhoopView: View {
    let d: NAiceWidgetData

    var body: some View {
        VStack(spacing: 8) {
            // Large recovery ring
            ZStack {
                Circle().stroke(d.recoveryColor.opacity(0.15), lineWidth: 8).frame(width: 80, height: 80)
                Circle().trim(from: 0, to: CGFloat(d.recoveryScore) / 100)
                    .stroke(d.recoveryColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80).rotationEffect(.degrees(-90))
                VStack(spacing: -4) {
                    Text("\(d.recoveryScore)").font(.system(size: 28, weight: .bold)).foregroundColor(.white)
                    Text("%").font(.system(size: 12, weight: .semibold)).foregroundColor(.gray)
                }
            }

            Text(d.recoveryLabel).font(.system(size: 9)).foregroundColor(d.recoveryColor)

            HStack(spacing: 10) {
                VStack(spacing: 1) {
                    Text("\(d.hrv)").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                    Text("HRV").font(.system(size: 7)).foregroundColor(.gray)
                }
                VStack(spacing: 1) {
                    Text("\(d.rhr)").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                    Text("RHR").font(.system(size: 7)).foregroundColor(.gray)
                }
                if d.sleepHours > 0 {
                    VStack(spacing: 1) {
                        Text("\(d.sleepHours, specifier: "%.1f")").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                        Text("Schlaf").font(.system(size: 7)).foregroundColor(.gray)
                    }
                }
                if d.strain > 0 {
                    VStack(spacing: 1) {
                        Text("\(d.strain, specifier: "%.1f")").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                        Text("Strain").font(.system(size: 7)).foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(12)
    }
}

// ════════════════════════════════════════════
//  WIDGET 4: Business Pipeline (Large)
// ════════════════════════════════════════════
struct BusinessPipelineView: View {
    let d: NAiceWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "n.square.fill").font(.caption).foregroundColor(.ncCyan)
                Text("Business Pipeline").font(.caption.weight(.bold)).foregroundColor(.white)
                Spacer()
            }

            if let b = d.business {
                // Business rows
                businessRow(icon: "brain.head.profile", label: "nAIce", count: "\(b.naice_total) Leads", detail: "\(b.naice_pitched_today) heute gepitcht")
                businessRow(icon: "fork.knife", label: "foodloop", count: "\(b.foodloop_total) Restaurants", detail: "\(b.foodloop_hot) Hot")
                businessRow(icon: "wineglass", label: "Schaffer-Wine", count: "\(b.schaffer_views) Views", detail: "\(b.schaffer_subscribers) Sub · \(b.schaffer_orders) Orders")
                businessRow(icon: "shippingbox", label: "parcelmate", count: "\(b.parcelmate_users) Users", detail: "\(b.parcelmate_shipments) Shipments")

                Color.white.opacity(0.06).frame(height: 1)

                // Deals header
                HStack {
                    Text("💰 Deals: \(b.deals_active) aktiv · \(b.deals_total_value/1000)k€ Wert").font(.system(size: 9, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                }

                // Deal progress bars
                if let deals = b.deals, !deals.isEmpty {
                    ForEach(deals, id: \.name) { deal in
                        HStack(spacing: 6) {
                            Text(deal.name).font(.system(size: 8)).foregroundColor(.gray).frame(width: 60, alignment: .leading).lineLimit(1)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.06)).frame(height: 6)
                                    RoundedRectangle(cornerRadius: 3).fill(dealColor(deal.status)).frame(width: geo.size.width * CGFloat(deal.value) / 105000, height: 6)
                                }
                            }
                            .frame(height: 6)
                            Text("\(deal.value/1000)k").font(.system(size: 7)).foregroundColor(.gray).frame(width: 35, alignment: .trailing)
                            Text(dealStatusLabel(deal.status)).font(.system(size: 7)).foregroundColor(dealColor(deal.status)).frame(width: 40, alignment: .trailing)
                        }
                    }
                }

                Spacer(minLength: 0)

                // Actions
                HStack(spacing: 4) {
                    ForEach(d.actions.prefix(4), id: \.id) { a in
                        Link(destination: URL(string: a.url)!) {
                            HStack(spacing: 3) {
                                Image(systemName: a.icon).font(.system(size: 8)).foregroundColor(.ncCyan)
                                Text(a.label).font(.system(size: 8)).foregroundColor(.gray)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.ncCyan.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
                        }
                    }
                }
            } else {
                Text("Keine Business-Daten").font(.subheadline).foregroundColor(.gray)
            }
        }
        .padding(14)
    }

    func businessRow(icon: String, label: String, count: String, detail: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 10)).foregroundColor(.ncCyan).frame(width: 16)
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(.system(size: 9, weight: .semibold)).foregroundColor(.white)
                Text(count).font(.system(size: 8)).foregroundColor(.gray)
            }
            Spacer()
            Text(detail).font(.system(size: 7)).foregroundColor(.gray.opacity(0.7))
        }
    }

    func dealColor(_ s: String) -> Color {
        switch s {
        case "aktiv": return .ncNeonGreen
        case "beauftragt": return .ncCyan
        case "angebot": return .ncAmber
        case "verloren": return .ncRose
        default: return .gray
        }
    }

    func dealStatusLabel(_ s: String) -> String {
        switch s {
        case "aktiv": return "aktiv"
        case "beauftragt": return "beauftr."
        case "angebot": return "Angebot"
        case "verloren": return "verloren"
        default: return s
        }
    }
}

// ════════════════════════════════════════════
//  LOCK SCREEN WIDGETS
// ════════════════════════════════════════════
struct LockScreenCircularView: View {
    let d: NAiceWidgetData

    var body: some View {
        ZStack {
            Circle().stroke(d.recoveryColor.opacity(0.2), lineWidth: 6).frame(width: 50, height: 50)
            Circle().trim(from: 0, to: CGFloat(d.recoveryScore) / 100)
                .stroke(d.recoveryColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 50, height: 50).rotationEffect(.degrees(-90))
            VStack(spacing: -2) {
                Text("\(d.recoveryScore)").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                Text("%").font(.system(size: 8)).foregroundColor(.gray)
            }
        }
    }
}

struct LockScreenRectangularView: View {
    let d: NAiceWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill").font(.system(size: 8)).foregroundColor(d.recoveryColor).frame(width: 12)
                Text("\(d.recoveryScore)%  ·  \(d.hrv) HRV  ·  \(d.rhr) RHR").font(.system(size: 10)).foregroundColor(.white)
            }
            if d.tasksActive > 0 || d.unreadWA > 0 {
                HStack(spacing: 6) {
                    if d.tasksActive > 0 { HStack(spacing: 2) { Image(systemName: "checklist").font(.system(size: 7)); Text("\(d.tasksActive)").font(.system(size: 9)) }.foregroundColor(.gray) }
                    if let b = d.business { HStack(spacing: 2) { Image(systemName: "chart.bar.fill").font(.system(size: 7)); Text("\(b.deals_active)").font(.system(size: 9)) }.foregroundColor(.gray) }
                    if d.unreadWA > 0 { HStack(spacing: 2) { Image(systemName: "message.fill").font(.system(size: 7)); Text("\(d.unreadWA)").font(.system(size: 9)) }.foregroundColor(.orange) }
                }
            }
        }
        .padding(8)
    }
}

struct LockScreenInlineView: View {
    let d: NAiceWidgetData

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill").font(.system(size: 10)).foregroundColor(d.recoveryColor)
            Text("\(d.recoveryScore)% Recovery").font(.system(size: 10)).foregroundColor(.white)
            if d.tasksActive > 0 {
                Text("· \(d.tasksActive) Tasks").font(.system(size: 10)).foregroundColor(.gray)
            }
        }
    }
}

// ════════════════════════════════════════════
//  WIDGET CONFIGS
// ════════════════════════════════════════════
struct NAiceWidget: Widget {
    let kind = "com.santoslab.naice.widget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            NAiceWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("nAIce")
        .description("Momentaufnahme + Tagesüberblick + Business.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct NAiceLockScreenWidget: Widget {
    let kind = "com.santoslab.naice.lockscreen"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            NAiceWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("nAIce Lock Screen")
        .description("Recovery, Tasks, Business auf dem Sperrbildschirm.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Premium nAIce Colors for Widgets
extension Color {
    static let ncCyan = Color(red: 0, green: 0.898, blue: 1)
    static let ncAmber = Color(red: 0.961, green: 0.62, blue: 0.043)
    static let ncRose = Color(red: 0.937, green: 0.267, blue: 0.267)
    static let ncNeonGreen = Color(red: 0, green: 0.902, blue: 0.463)
    static let ncPurple = Color(red: 0.486, green: 0.227, blue: 0.929)
}