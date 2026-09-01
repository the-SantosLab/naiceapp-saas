import SwiftUI

// MARK: - Ziele Dashboard
struct NALifeGoalsView: View {
    @ObservedObject private var goals = NAGoalService.shared
    @State private var showAdd = false
    @State private var filterCategory = "all"

    var filteredGoals: [NALifeGoal] {
        let active = goals.activeGoals
        if filterCategory == "all" { return active }
        return active.filter { $0.category == filterCategory }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ziele").font(.title2.weight(.bold)).foregroundColor(.white)
                        Text("\(goals.activeGoals.count) aktiv · \(goals.completedGoals.count) erledigt").font(.subheadline).foregroundColor(.gray)
                    }
                    Spacer()
                    Button { showAdd = true } label: {
                        Image(systemName: "plus").font(.title3).foregroundColor(.ncCyan)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 8)

                // Kategorie-Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["all", "life", "work", "health", "finance", "social"], id: \.self) { cat in
                            Button {
                                filterCategory = cat
                            } label: {
                                Text(cat == "all" ? "Alle" : categoryLabel(cat))
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(filterCategory == cat ? .white : .gray)
                                    .padding(.horizontal, 14).padding(.vertical, 6)
                                    .background(filterCategory == cat ? Color.ncCyan : Color(red: 0.03, green: 0.03, blue: 0.06), in: Capsule())
                                    .overlay(Capsule().stroke(filterCategory == cat ? Color.ncCyan : Color.white.opacity(0.08), lineWidth: 1))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                if filteredGoals.isEmpty && !goals.isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "target").font(.title).foregroundColor(.gray.opacity(0.5))
                        Text("Keine aktiven Ziele").font(.subheadline).foregroundColor(.gray)
                        Button("Ziel hinzufügen") { showAdd = true }
                            .font(.subheadline).foregroundColor(.ncCyan)
                    }
                    .padding(40).frame(maxWidth: .infinity)
                }

                ForEach(filteredGoals) { (goal: NALifeGoal) in
                    goalCard(goal)
                }

                if !goals.completedGoals.isEmpty {
                    Text("Erledigt").font(.headline).foregroundColor(.gray).padding(.top, 8)
                    ForEach(goals.completedGoals) { (goal: NALifeGoal) in
                        goalCard(goal)
                    }
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .refreshable { await goals.fetch() }
        .task { await goals.fetch() }
        .sheet(isPresented: $showAdd) { NALifeGoalAddSheet() }
    }

    func goalCard(_ goal: NALifeGoal) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(goal.colorSwift.opacity(0.12)).frame(width: 32, height: 32)
                    Image(systemName: goal.icon).font(.system(size: 12)).foregroundColor(goal.colorSwift)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title).font(.subheadline.weight(.semibold)).foregroundColor(.white)
                    Text(goal.description).font(.caption).foregroundColor(.gray).lineLimit(1)
                }
                Spacer()
                if goal.status == "active" {
                    Menu {
                        Button("\(goal.progressPercent)%") {}
                        Button("Abschließen") { Task { await goals.update(goalId: goal.id, status: "completed") } }
                        Button("Pausieren") { Task { await goals.update(goalId: goal.id, status: "paused") } }
                        Button("Löschen", role: .destructive) { Task { await goals.delete(goalId: goal.id) } }
                    } label: {
                        Image(systemName: "ellipsis").font(.caption).foregroundColor(.gray)
                    }
                } else {
                    Image(systemName: "checkmark.circle.fill").font(.caption).foregroundColor(.ncNeonGreen)
                }
            }

            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4).fill(goal.colorSwift).frame(width: geo.size.width * goal.progress, height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text(goal.categoryLabel).font(.caption2).foregroundColor(.gray)
                Spacer()
                Text("\(Int(goal.currentValue))/\(Int(goal.targetValue))").font(.caption2).foregroundColor(goal.colorSwift)
                if let dl = goal.deadline, !dl.isEmpty {
                    Text("· \(dl)").font(.caption2).foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        .padding(.horizontal, 16)
    }

    func categoryLabel(_ c: String) -> String {
        switch c {
        case "life": return "Leben"
        case "work": return "Arbeit"
        case "health": return "Gesundheit"
        case "finance": return "Finanzen"
        case "social": return "Soziales"
        default: return c
        }
    }
}

// MARK: - Add Goal Sheet
struct NALifeGoalAddSheet: View {
    @ObservedObject private var goals = NAGoalService.shared
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var category = "life"
    @State private var targetValue: Double = 100
    @State private var deadline = ""
    @State private var icon = "star.fill"
    @State private var color = "ncCyan"
    @State private var company = ""

    let icons = ["star.fill", "heart.fill", "dollarsign.circle.fill", "book.fill", "figure.walk", "house.fill", "briefcase.fill", "person.2.fill"]
    let colors: [(String, Color)] = [("ncCyan", .ncCyan), ("ncRose", .ncRose), ("ncAmber", .ncAmber), ("ncNeonGreen", .ncNeonGreen), ("ncBlue", .ncBlue), ("ncPurple", .ncPurple)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("Ziel", text: $title).font(.subheadline).foregroundColor(.white)
                    .padding(14).background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                TextField("Beschreibung (optional)", text: $description).font(.subheadline).foregroundColor(.white)
                    .padding(14).background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))

                Picker("Kategorie", selection: $category) {
                    Text("Leben").tag("life"); Text("Arbeit").tag("work"); Text("Gesundheit").tag("health"); Text("Finanzen").tag("finance"); Text("Soziales").tag("social")
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("Zielwert: \(Int(targetValue))").font(.subheadline).foregroundColor(.gray)
                    Slider(value: $targetValue, in: 1...1000, step: 1).tint(.ncCyan)
                }

                HStack(spacing: 8) {
                    ForEach(icons, id: \.self) { ic in
                        Button { icon = ic } label: {
                            Image(systemName: ic).font(.system(size: 14)).foregroundColor(icon == ic ? .white : .gray)
                                .frame(width: 32, height: 32).background(icon == ic ? Color.ncCyan : Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                HStack(spacing: 8) {
                    ForEach(colors, id: \.0) { c in
                        Button { color = c.0 } label: {
                            Circle().fill(c.1).frame(width: 24, height: 24).overlay(Circle().stroke(color == c.0 ? Color.white : Color.clear, lineWidth: 2))
                        }
                    }
                }

                TextField("Deadline (optional, z.B. 2026-12-31)", text: $deadline).font(.subheadline).foregroundColor(.white)
                    .padding(14).background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))

                Button("Ziel speichern") {
                    Task {
                        await goals.addGoal(title: title, description: description, category: category, targetValue: targetValue, deadline: deadline.isEmpty ? nil : deadline, icon: icon, color: color)
                        dismiss()
                    }
                }
                .font(.headline.weight(.semibold)).foregroundColor(.white).frame(maxWidth: .infinity)
                .padding(.vertical, 14).background(Color.ncCyan, in: RoundedRectangle(cornerRadius: 14))
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()
            }
            .padding(20).background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Abbrechen") { dismiss() }.foregroundColor(.ncCyan) }
            }
        }
    }
}