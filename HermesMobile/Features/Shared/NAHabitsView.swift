import SwiftUI

// MARK: - Habits View
struct NAHabitsView: View {
    @ObservedObject private var habitsService = NAHabitsService.shared
    @State private var showAddSheet = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Habits")
                            .font(.title2.weight(.bold)).foregroundColor(.white)
                        Text("\(habitsService.currentStreak) Tage Serie · \(habitsService.todayDone)/\(habitsService.habits.count) heute")
                            .font(.subheadline).foregroundColor(.gray)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        if habitsService.isLoading { ProgressView().scaleEffect(0.7).tint(.ncCyan) }
                        Button { showAddSheet = true } label: {
                            Image(systemName: "plus.circle.fill").font(.system(size: 20)).foregroundColor(.ncCyan)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 8)

                // Streak card
                streakCard

                // Today's habits
                if !habitsService.todayUndone.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "circle.dotted").font(.caption).foregroundColor(.ncAmber)
                            Text("Heute offen (\(habitsService.todayUndone.count))").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                        }
                        .padding(.horizontal, 4)
                        ForEach(habitsService.todayUndone) { habit in
                            habitRow(habit, done: false)
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.02, green: 0.02, blue: 0.04)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5)))
                    .padding(.horizontal, 16)
                }

                // All habits
                if !habitsService.habits.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill").font(.caption).foregroundColor(.ncNeonGreen)
                            Text("Alle Habits (\(habitsService.habits.count))").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                        }
                        .padding(.horizontal, 4)
                        ForEach(habitsService.habits) { habit in
                            habitRow(habit, done: !habitsService.todayUndone.contains(where: { $0.id == habit.id }))
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.02, green: 0.02, blue: 0.04)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5)))
                    .padding(.horizontal, 16)
                }

                if habitsService.habits.isEmpty {
                    emptySection
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await habitsService.fetch() }
        .refreshable { await habitsService.fetch() }
        .sheet(isPresented: $showAddSheet) { AddHabitSheet { name, icon, freq, goal, unit, color in Task { await habitsService.addHabit(name: name, icon: icon, frequency: freq, goal: goal, unit: unit, color: color) } } }
    }

    private var streakCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.ncCyan.opacity(0.15), lineWidth: 5).frame(width: 56, height: 56)
                Circle().trim(from: 0, to: min(CGFloat(habitsService.currentStreak) / 30, 1))
                    .stroke(Color.ncCyan, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 56, height: 56).rotationEffect(.degrees(-90))
                Text("\(habitsService.currentStreak)").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(habitsService.currentStreak) Tage Serie").font(.headline.weight(.bold)).foregroundColor(.white)
                Text(habitsService.currentStreak >= 7 ? "Sehr gut! Bleib dran." : "Konsistenz ist der Schlüssel.").font(.caption).foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.02, green: 0.02, blue: 0.04)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5)))
        .padding(.horizontal, 16)
    }

    private func habitRow(_ habit: NAHabit, done: Bool) -> some View {
        HStack(spacing: 12) {
            Button {
                if !done { Task { await habitsService.logHabit(habit) } }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(done ? Color.ncNeonGreen.opacity(0.15) : habit.colorValue.opacity(0.12)).frame(width: 28, height: 28)
                    Image(systemName: done ? "checkmark.circle.fill" : habit.icon)
                        .font(.system(size: 11)).foregroundColor(done ? .ncNeonGreen : habit.colorValue)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name).font(.subheadline.weight(.medium)).foregroundColor(done ? .gray : .white).strikethrough(done)
                if !habit.unit.isEmpty { Text("\(habit.goal) \(habit.unit)").font(.caption2).foregroundColor(.gray) }
            }

            Spacer()

            if done { Text("Erledigt").font(.caption2).foregroundColor(.ncNeonGreen) }
            else { Text(habit.frequency).font(.caption2).foregroundColor(.gray) }
        }
        .padding(12)
        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }

    private var emptySection: some View {
        VStack(spacing: 14) {
            ZStack { Circle().fill(Color.ncCyan.opacity(0.1)).frame(width: 48, height: 48); Image(systemName: "figure.walk").font(.title2).foregroundColor(.ncCyan) }
            Text("Keine Habits").font(.subheadline.weight(.semibold)).foregroundColor(.white)
            Text("Definiere Gewohnheiten, die du täglich tracken willst.").font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)
        }
        .padding(24).frame(maxWidth: .infinity)
        .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        .padding(.horizontal, 16)
    }
}

// MARK: - Add Habit Sheet
struct AddHabitSheet: View {
    @Environment(\.dismiss) var dismiss
    let onSave: (String, String, String, Int, String, String) -> Void
    @State private var name = ""; @State private var icon = "figure.walk"; @State private var frequency = "daily"
    @State private var goal = 1; @State private var unit = ""; @State private var selectedColor = "#00E5FF"

    let icons = ["figure.walk", "figure.run", "figure.yoga", "book", "drop.fill", "moon.fill", "heart.fill", "brain.head.profile", "leaf.fill", "meditation", "waterbottle.fill", "gym.bike"]
    let frequencies = ["daily", "weekday", "weekly"]
    let colors = ["#00E5FF", "#00E676", "#EF4444", "#F59E0B", "#7C3AED", "#3B82F6"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        TextField("Name (z.B. Meditieren)", text: $name).font(.body).foregroundColor(.white).padding(14)
                            .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 0.5))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Icon").font(.caption.weight(.semibold)).foregroundColor(.gray).textCase(.uppercase).tracking(1)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
                                ForEach(icons, id: \.self) { ic in
                                    Button { icon = ic } label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10).fill(icon == ic ? Color.ncCyan.opacity(0.2) : Color(red: 0.03, green: 0.03, blue: 0.06)).frame(width: 44, height: 44)
                                            Image(systemName: ic).font(.system(size: 14)).foregroundColor(icon == ic ? .ncCyan : .gray)
                                        }
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Farbe").font(.caption.weight(.semibold)).foregroundColor(.gray).textCase(.uppercase).tracking(1)
                            HStack(spacing: 10) {
                                ForEach(colors, id: \.self) { c in
                                    Button { selectedColor = c } label: {
                                        ZStack {
                                            Circle().fill(Color(hex: c)).frame(width: 36, height: 36)
                                            if selectedColor == c { Circle().stroke(Color.white, lineWidth: 2).frame(width: 44, height: 44) }
                                        }
                                    }
                                }
                            }
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Frequenz").font(.caption.weight(.semibold)).foregroundColor(.gray).textCase(.uppercase).tracking(1)
                                Picker("", selection: $frequency) {
                                    ForEach(frequencies, id: \.self) { f in Text(f == "daily" ? "Täglich" : f == "weekday" ? "Wochentags" : "Wöchentlich").tag(f) }
                                }.pickerStyle(.segmented).tint(.ncCyan)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Ziel").font(.caption.weight(.semibold)).foregroundColor(.gray).textCase(.uppercase).tracking(1)
                                HStack(spacing: 6) {
                                    Stepper("\(goal)", value: $goal, in: 1...99).tint(.ncCyan)
                                    TextField("Einheit", text: $unit).font(.subheadline).foregroundColor(.white).frame(width: 60).padding(8)
                                        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Neues Habit").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() }.foregroundColor(.gray) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") { onSave(name, icon, frequency, goal, unit, selectedColor); dismiss() }
                    .font(.headline).foregroundColor(name.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .ncCyan)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Goals View
struct NAGoalsView: View {
    @ObservedObject private var goalsService = NAGoalsService.shared
    @State private var showAddSheet = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ziele").font(.title2.weight(.bold)).foregroundColor(.white)
                        Text("\(goalsService.activeGoals.count) aktiv · \(goalsService.completedGoals.count) erreicht").font(.subheadline).foregroundColor(.gray)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        if goalsService.isLoading { ProgressView().scaleEffect(0.7).tint(.ncCyan) }
                        Button { showAddSheet = true } label: { Image(systemName: "plus.circle.fill").font(.system(size: 20)).foregroundColor(.ncCyan) }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 8)

                if goalsService.activeGoals.isEmpty && goalsService.completedGoals.isEmpty {
                    VStack(spacing: 14) {
                        ZStack { Circle().fill(Color.ncAmber.opacity(0.1)).frame(width: 48, height: 48); Image(systemName: "target").font(.title2).foregroundColor(.ncAmber) }
                        Text("Keine Ziele").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                        Text("Setze dir Ziele in Gesundheit, Business, Kreativität und mehr.").font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)
                    }.padding(24).frame(maxWidth: .infinity)
                        .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                        .padding(.horizontal, 16)
                }

                if !goalsService.activeGoals.isEmpty {
                    goalSection("Aktiv", goals: goalsService.activeGoals, accent: .ncCyan)
                }
                if !goalsService.completedGoals.isEmpty {
                    goalSection("Erreicht", goals: goalsService.completedGoals, accent: .ncNeonGreen)
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .task { await goalsService.fetch() }
        .refreshable { await goalsService.fetch() }
        .sheet(isPresented: $showAddSheet) { AddGoalSheet { title, cat, target, deadline in Task { await goalsService.addGoal(title: title, category: cat, target: target, deadline: deadline) } } }
    }

    private func goalSection(_ title: String, goals: [NAGoal], accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "flag.fill").font(.caption).foregroundColor(accent)
                Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.white)
                Spacer(); Text("\(goals.count)").font(.caption.weight(.bold)).foregroundColor(accent).padding(.horizontal, 8).padding(.vertical, 2).background(accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
            }.padding(.horizontal, 4)

            ForEach(goals) { goal in
                goalCard(goal, accent: accent)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.02, green: 0.02, blue: 0.04)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5)))
        .padding(.horizontal, 16)
    }

    private func goalCard(_ goal: NAGoal, accent: Color) -> some View {
        HStack(spacing: 12) {
            ZStack { RoundedRectangle(cornerRadius: 8).fill(accent.opacity(0.12)).frame(width: 28, height: 28); Image(systemName: "flag.fill").font(.system(size: 11)).foregroundColor(accent) }

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title).font(.subheadline.weight(.medium)).foregroundColor(.white).lineLimit(1)
                if !goal.target.isEmpty { Text(goal.target).font(.caption2).foregroundColor(.gray) }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.06)).frame(height: 4)
                        RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: geo.size.width * CGFloat(goal.progress) / 100, height: 4)
                    }
                }.frame(height: 4)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("\(goal.progress)%").font(.caption.weight(.bold)).foregroundColor(accent)
                Text(categoryLabel(goal.category)).font(.system(size: 7)).foregroundColor(.gray)
            }

            if goal.status == "active" {
                Button { Task { await goalsService.updateGoal(goal, status: "completed") } } label: {
                    Image(systemName: "checkmark.circle").font(.caption).foregroundColor(.gray)
                }.buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }

    private func categoryLabel(_ c: String) -> String {
        switch c { case "health": return "Gesundheit"; case "business": return "Business"; case "creative": return "Kreativ"; case "social": return "Sozial"; case "finance": return "Finanzen"; default: return c }
    }
}

// MARK: - Add Goal Sheet
struct AddGoalSheet: View {
    @Environment(\.dismiss) var dismiss
    let onSave: (String, String, String, String) -> Void
    @State private var title = ""; @State private var category = "health"; @State private var target = ""; @State private var deadline = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        TextField("Ziel (z.B. 3x Sport pro Woche)", text: $title).font(.body).foregroundColor(.white).padding(14)
                            .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                        TextField("Beschreibung", text: $target).font(.body).foregroundColor(.white).padding(14)
                            .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                        HStack(spacing: 10) {
                            ForEach([("health", "🫀"), ("business", "💼"), ("creative", "🎨"), ("social", "👥"), ("finance", "💰")], id: \.0) { (cat, icon) in
                                Button { category = cat } label: {
                                    Text("\(icon)").font(.title2).padding(10)
                                        .background(category == cat ? Color.ncCyan.opacity(0.2) : Color(red: 0.03, green: 0.03, blue: 0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        TextField("Deadline (optional, YYYY-MM-DD)", text: $deadline).font(.body).foregroundColor(.white).padding(14)
                            .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    }.padding(20)
                }
            }
            .navigationTitle("Neues Ziel").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() }.foregroundColor(.gray) }
                ToolbarItem(placement: .confirmationAction) { Button("Hinzufügen") { onSave(title, category, target, deadline); dismiss() }.font(.headline).foregroundColor(title.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .ncCyan).disabled(title.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
        }
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0; Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}