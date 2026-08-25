import SwiftUI

// MARK: - Tasks View (Rollup Tasks + Hermes Tasks)
struct NAIceTasksView: View {
    @ObservedObject private var rollup = NARollupService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Aufgaben").font(.title2.weight(.bold)).foregroundColor(.ncDark)
                    Text("Business-Tasks aus Amelia's Pipeline.").font(.subheadline).foregroundColor(.ncMuted)

                    if let t = rollup.tasks, let tasks = t.tasks, !tasks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Business (\(t.active) aktiv)").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                            ForEach(tasks) { task in
                                taskCard(task)
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").font(.title3).foregroundColor(.ncGreen)
                            Text("Keine offenen Aufgaben").font(.subheadline).foregroundColor(.ncMuted)
                        }.warmCard()
                    }
                }
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
            }
            .warmBackground()
            .navigationTitle("Aufgaben")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func taskCard(_ task: NATask) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: task.priority == "high" ? "exclamationmark.circle.fill" : "circle")
                    .foregroundColor(priorityColor(task.priority)).font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title).font(.subheadline.weight(.medium)).foregroundColor(.ncDark)
                    if let p = task.project { Text(p).font(.caption2).foregroundColor(.ncSage) }
                }
                Spacer()
                if let d = task.deadline { Text(deadlineLabel(d)).font(.caption).foregroundColor(deadlineColor(d)) }
            }
            if let s = task.status {
                HStack(spacing: 4) {
                    Circle().fill(statusDot(s)).frame(width: 6, height: 6)
                    Text(s.capitalized).font(.caption2).foregroundColor(.ncMuted)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.6))
        .cornerRadius(10)
    }

    private func priorityColor(_ p: String?) -> Color {
        guard let p = p else { return .ncSage }
        switch p.lowercased() {
        case "high": return .ncRed
        case "medium": return .ncGold
        default: return .ncSage
        }
    }

    private func deadlineLabel(_ d: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        if let date = formatter.date(from: d) {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
            if days < 0 { return "\(abs(days)) Tage überfällig" }
            if days == 0 { return "Heute" }
            if days == 1 { return "Morgen" }
            return "In \(days) Tagen"
        }
        // Try shorter format
        formatter.formatOptions = [.withFullDate]
        if let date = formatter.date(from: d) {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
            if days < 0 { return "Überfällig" }
            return "In \(days) Tagen"
        }
        return d
    }

    private func deadlineColor(_ d: String) -> Color {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        if let date = formatter.date(from: d) {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 99
            if days < 0 { return .ncRed }
            if days == 0 { return .ncGold }
            return .ncMuted
        }
        return .ncMuted
    }

    private func statusDot(_ s: String) -> Color {
        switch s.lowercased() {
        case "open": return .ncGold
        case "in_progress": return .blue
        case "done": return .ncGreen
        default: return .ncMuted
        }
    }
}