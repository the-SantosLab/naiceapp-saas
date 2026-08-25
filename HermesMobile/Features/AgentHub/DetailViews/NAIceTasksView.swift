import SwiftUI

// MARK: - Tasks View (Modern Dark Theme)
struct NAIceTasksView: View {
    @ObservedObject private var rollup = NARollupService.shared

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Aufgaben")
                                .font(.title2.weight(.bold))
                                .foregroundColor(.white)
                            Text("Business-Tasks aus Amelia's Pipeline.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        if rollup.isLoading {
                            ProgressView().scaleEffect(0.7).tint(.ncCyan)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    if let t = rollup.tasks, let tasks = t.tasks, !tasks.isEmpty {
                        // High priority section
                        let high = tasks.filter { $0.priority == "high" }
                        if !high.isEmpty {
                            taskSection(title: "Kritisch", icon: "exclamationmark.triangle.fill", tasks: high, accent: .ncRose)
                        }

                        // Others
                        let other = tasks.filter { $0.priority != "high" }
                        if !other.isEmpty {
                            taskSection(title: "Offen (\(other.count))", icon: "circle", tasks: other, accent: .ncCyan)
                        }

                        // Summary
                        VStack(spacing: 8) {
                            HStack(spacing: 12) {
                                glassStat(icon: "tray.full.fill", value: "\(t.total)", label: "Gesamt", color: .ncCyan)
                                glassStat(icon: "exclamationmark.circle.fill", value: "\(t.active)", label: "Aktiv", color: .ncAmber)
                            }
                        }
                        .padding(.horizontal, 16)
                    } else {
                        emptySection
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 30)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Task Section
    private func taskSection(title: String, icon: String, tasks: [NATask], accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(accent)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(tasks.count)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(accent)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
            }
            .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(tasks) { task in
                    taskCard(task, accent: accent)
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

    // MARK: - Task Card
    private func taskCard(_ task: NATask, accent: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(priorityColor(task.priority).opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: task.priority == "high" ? "exclamationmark.circle.fill" : "circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(priorityColor(task.priority))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let p = task.project {
                        HStack(spacing: 4) {
                            Circle().fill(accent).frame(width: 4, height: 4)
                            Text(p).font(.caption2).foregroundColor(.gray)
                        }
                    }
                    if let s = task.status {
                        HStack(spacing: 4) {
                            Circle().fill(statusDot(s)).frame(width: 4, height: 4)
                            Text(s.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }

            Spacer()

            if let d = task.deadline {
                Text(deadlineLabel(d))
                    .font(.caption)
                    .foregroundColor(deadlineColor(d))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(deadlineColor(d).opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(12)
        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }

    // MARK: - Glass Stat
    private func glassStat(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
    }

    // MARK: - Empty State
    private var emptySection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.ncNeonGreen.opacity(0.1)).frame(width: 48, height: 48)
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.ncNeonGreen)
            }
            Text("Keine offenen Aufgaben")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            Text("Alle Tasks aus Amelia's Pipeline sind erledigt.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
    }

    // MARK: - Helpers
    private func priorityColor(_ p: String?) -> Color {
        guard let p = p else { return .ncCyan }
        switch p.lowercased() {
        case "high": return .ncRose
        case "medium": return .ncAmber
        default: return .ncCyan
        }
    }

    private func deadlineLabel(_ d: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        if let date = formatter.date(from: d) {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
            if days < 0 { return "\(abs(days))d uberfallig" }
            if days == 0 { return "Heute" }
            if days == 1 { return "Morgen" }
            return "\(days)d"
        }
        formatter.formatOptions = [.withFullDate]
        if let date = formatter.date(from: d) {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
            if days < 0 { return "Uberfallig" }
            return "\(days)d"
        }
        return d
    }

    private func deadlineColor(_ d: String) -> Color {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        if let date = formatter.date(from: d) {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 99
            if days < 0 { return .ncRose }
            if days == 0 { return .ncAmber }
            return .gray
        }
        return .gray
    }

    private func statusDot(_ s: String) -> Color {
        switch s.lowercased() {
        case "open": return .ncAmber
        case "in_progress": return .ncCyan
        case "done": return .ncNeonGreen
        default: return .gray
        }
    }
}