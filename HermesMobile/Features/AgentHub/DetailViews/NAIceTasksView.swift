import SwiftUI

// MARK: - Tasks View (Polished)
struct NAIceTasksView: View {
    @ObservedObject private var taskService = NATaskService.shared
    @ObservedObject private var rollup = NARollupService.shared
    @State private var showAddSheet = false
    @State private var filterDone = false
    @State private var editTask: NATaskItem?
    @State private var showEditSheet = false

    var body: some View {
        NavigationStack {
            List {
                // Header
                Section {
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Aufgaben")
                                    .font(.title2.weight(.bold))
                                    .foregroundColor(.white)
                                Text("Eigene Tasks + Pipeline")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            HStack(spacing: 8) {
                                if taskService.isLoading || rollup.isLoading {
                                    ProgressView().scaleEffect(0.7).tint(.ncCyan)
                                }
                                filterButton
                                addButton
                            }
                        }

                        let open = taskService.tasks.filter { $0.status != "done" }.count
                        let done = taskService.tasks.filter { $0.status == "done" }.count
                        let high = taskService.tasks.filter { $0.priority == "high" && $0.status != "done" }.count
                        HStack(spacing: 12) {
                            statCard(icon: "tray.full.fill", value: "\(taskService.tasks.count)", label: "Gesamt", color: .ncCyan)
                            statCard(icon: "exclamationmark.circle.fill", value: "\(open)", label: "Offen", color: .ncAmber)
                            statCard(icon: "checkmark.circle.fill", value: "\(done)", label: "Erledigt", color: .ncNeonGreen)
                            statCard(icon: "exclamationmark.triangle.fill", value: "\(high)", label: "Kritisch", color: .ncRose)
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.black)
                    .listRowSeparator(.hidden)
                }

                let filtered = filterDone
                    ? taskService.tasks.filter { $0.status != "done" }
                    : taskService.tasks

                let highPrio = filtered.filter { $0.priority == "high" && $0.status != "done" }
                let openPrio = filtered.filter { $0.priority != "high" && $0.status != "done" }
                let doneTasks = filtered.filter { $0.status == "done" }

                if filtered.isEmpty {
                    Section {
                        emptySection
                            .listRowBackground(Color.black)
                            .listRowSeparator(.hidden)
                    }
                } else {
                    if !highPrio.isEmpty {
                        Section(header: sectionHeader("Kritisch", count: highPrio.count, accent: .ncRose)) {
                            ForEach(highPrio) { task in
                                taskRow(task, accent: .ncRose)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        if task.isLocal {
                                            Button(role: .destructive) {
                                                Task { await taskService.deleteTask(task) }
                                            } label: { Image(systemName: "trash") }
                                        }
                                    }
                                    .onTapGesture { editTask = task; showEditSheet = true }
                            }
                            .onMove { from, to in taskService.reorderTasks(from: from, to: to) }
                        }
                    }

                    if !openPrio.isEmpty {
                        Section(header: sectionHeader("Offen", count: openPrio.count, accent: .ncCyan)) {
                            ForEach(openPrio) { task in
                                taskRow(task, accent: .ncCyan)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        if task.isLocal {
                                            Button(role: .destructive) {
                                                Task { await taskService.deleteTask(task) }
                                            } label: { Image(systemName: "trash") }
                                        }
                                    }
                                    .onTapGesture { editTask = task; showEditSheet = true }
                            }
                            .onMove { from, to in taskService.reorderTasks(from: from, to: to) }
                        }
                    }

                    if !filterDone && !doneTasks.isEmpty {
                        Section(header: sectionHeader("Erledigt", count: doneTasks.count, accent: .ncNeonGreen)) {
                            ForEach(doneTasks) { task in
                                taskRow(task, accent: .ncNeonGreen)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        if task.isLocal {
                                            Button(role: .destructive) {
                                                Task { await taskService.deleteTask(task) }
                                            } label: { Image(systemName: "trash") }
                                        }
                                    }
                                    .onTapGesture { editTask = task; showEditSheet = true }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task { await taskService.fetch() }
            .refreshable { await taskService.fetch() }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                        .tint(.ncCyan)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddTaskSheet { title, project, priority, deadline, repeatVal, category in
                Task { await taskService.addTask(title: title, project: project, priority: priority, deadline: deadline, repeat: repeatVal, category: category) }
            }
        }
        .sheet(item: $editTask) { task in
            EditTaskSheet(task: task)
        }
    }

    // MARK: - Task Row
    private func taskRow(_ task: NATaskItem, accent: Color) -> some View {
        HStack(spacing: 12) {
            // Checkmark
            Button {
                Task { await taskService.toggleTask(task) }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(task.status == "done" ? Color.ncNeonGreen.opacity(0.15) : accent.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: task.status == "done" ? "checkmark.circle.fill" : "circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(task.status == "done" ? .ncNeonGreen : accent)
                }
            }
            .buttonStyle(.plain)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(task.status == "done" ? .gray : .white)
                    .strikethrough(task.status == "done")
                    .lineLimit(2)

                // Meta row
                HStack(spacing: 6) {
                    // Project badge
                    if let p = task.project {
                        HStack(spacing: 4) {
                            Circle().fill(task.projectColor).frame(width: 5, height: 5)
                            Text(p).font(.system(size: 9)).foregroundColor(.gray)
                        }
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(task.projectColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                        .fixedSize()
                    }

                    // Status
                    HStack(spacing: 3) {
                        Circle().fill(task.statusDot).frame(width: 4, height: 4)
                        Text(task.status == "done" ? "Erledigt" : task.status.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.system(size: 9)).foregroundColor(.gray)
                    }
                    .fixedSize()

                    // Repeat indicator
                    if let r = task.repeat, !r.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 7))
                            Text(task.repeatLabel).font(.system(size: 9))
                        }
                        .foregroundColor(.ncCyan)
                        .padding(.horizontal, 4).padding(.vertical, 2)
                        .background(Color.ncCyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                        .fixedSize()
                    }

                    // Source
                    if task.isLocal {
                        HStack(spacing: 3) {
                            Image(systemName: "iphone").font(.system(size: 7))
                            Text("Eigen").font(.system(size: 9))
                        }
                        .foregroundColor(.gray.opacity(0.6))
                        .fixedSize()
                    }

                    Spacer()

                    // Deadline badge
                    if let d = task.deadline, !d.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar").font(.system(size: 7))
                            Text(task.deadlineLabel)
                        }
                        .font(.system(size: 9))
                        .foregroundColor(task.deadlineColor)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(task.deadlineColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                        .fixedSize()
                    }
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundColor(.gray.opacity(0.3))
        }
        .padding(.vertical, 4)
        .listRowBackground(Color(red: 0.03, green: 0.03, blue: 0.06))
        .listRowSeparator(.hidden)
    }

    // MARK: - Subviews
    private var addButton: some View {
        Button { showAddSheet = true } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.ncCyan)
        }
    }

    private var filterButton: some View {
        Button { withAnimation { filterDone.toggle() } } label: {
            Image(systemName: filterDone ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 16))
                .foregroundColor(filterDone ? .ncCyan : .gray)
        }
    }

    private func sectionHeader(_ title: String, count: Int, accent: Color) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            Text("\(count)")
                .font(.caption.weight(.bold))
                .foregroundColor(accent)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
        }
        .textCase(nil)
    }

    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12)).frame(width: 24, height: 24)
                Image(systemName: icon).font(.system(size: 10)).foregroundColor(color)
            }
            Text(value).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
            Text(label).font(.system(size: 8)).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
    }

    private var emptySection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.ncNeonGreen.opacity(0.1)).frame(width: 48, height: 48)
                Image(systemName: "checkmark.circle.fill").font(.title2).foregroundColor(.ncNeonGreen)
            }
            Text("Keine offenen Aufgaben").font(.subheadline.weight(.semibold)).foregroundColor(.white)
            Text("Tippe auf + um einen Task zu erstellen.\nZiehen zum Sortieren · Wischen zum Löschen")
                .font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)
        }
        .padding(24).frame(maxWidth: .infinity)
        .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
    }
}

// MARK: - Add Task Sheet
struct AddTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (String, String, String, String?, String?, String?) -> Void

    @State private var title = ""
    @State private var project = "nAIce"
    @State private var priority = "medium"
    @State private var deadlineDate = Date().addingTimeInterval(86400 * 7)
    @State private var hasDeadline = false
    @State private var repeatOption = ""
    @State private var category = ""

    let projects = ["nAIce", "foodloop", "Schaffer-Wine", "parcelmate", "einfacHR", "Privat", "Sonstiges"]
    let repeatOptions = [("", "Nie"), ("daily", "Täglich"), ("weekday", "Wochentags"), ("weekly", "Wöchentlich"), ("monthly", "Monatlich")]

    private var deadlineString: String? {
        guard hasDeadline else { return nil }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: deadlineDate)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        // Title
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Titel").font(.caption.weight(.semibold)).foregroundColor(.gray).textCase(.uppercase).tracking(1)
                            TextField("Task eingeben...", text: $title)
                                .font(.body).foregroundColor(.white).padding(14)
                                .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                        }

                        // Project
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Projekt").font(.caption.weight(.semibold)).foregroundColor(.gray).textCase(.uppercase).tracking(1)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(projects, id: \.self) { p in
                                        Button {
                                            project = p
                                        } label: {
                                            HStack(spacing: 6) {
                                                Circle().fill(projectColor(p)).frame(width: 6, height: 6)
                                                Text(p).font(.subheadline)
                                            }
                                            .padding(.horizontal, 14).padding(.vertical, 8)
                                            .background(project == p ? projectColor(p).opacity(0.15) : Color(red: 0.03, green: 0.03, blue: 0.06))
                                            .foregroundColor(project == p ? projectColor(p) : .gray)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(project == p ? projectColor(p).opacity(0.3) : Color.white.opacity(0.04), lineWidth: 0.5))
                                        }
                                        .fixedSize()
                                    }
                                }.padding(.vertical, 4)
                            }
                        }

                        // Priority
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Priorität").font(.caption.weight(.semibold)).foregroundColor(.gray).textCase(.uppercase).tracking(1)
                            HStack(spacing: 10) {
                                prioBtn("Niedrig", value: "low", color: .ncCyan)
                                prioBtn("Mittel", value: "medium", color: .ncAmber)
                                prioBtn("Hoch", value: "high", color: .ncRose)
                            }
                        }

                        // Repeat
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Wiederholung").font(.caption.weight(.semibold)).foregroundColor(.gray).textCase(.uppercase).tracking(1)
                            HStack(spacing: 8) {
                                ForEach(repeatOptions, id: \.0) { (val, label) in
                                    Button {
                                        repeatOption = val
                                    } label: {
                                        Text(label).font(.subheadline)
                                            .padding(.horizontal, 14).padding(.vertical, 8)
                                            .frame(maxWidth: .infinity)
                                            .background(repeatOption == val ? Color.ncCyan.opacity(0.15) : Color(red: 0.03, green: 0.03, blue: 0.06))
                                            .foregroundColor(repeatOption == val ? .ncCyan : .gray)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(repeatOption == val ? Color.ncCyan.opacity(0.3) : Color.white.opacity(0.04), lineWidth: 0.5))
                                    }
                                }
                            }
                        }

                        // Deadline
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Deadline").font(.caption.weight(.semibold)).foregroundColor(.gray).textCase(.uppercase).tracking(1)
                                Spacer()
                                Toggle("", isOn: $hasDeadline).labelsHidden().tint(.ncCyan)
                            }
                            if hasDeadline {
                                DatePicker("Datum", selection: $deadlineDate, displayedComponents: .date)
                                    .datePickerStyle(.graphical).tint(.ncCyan)
                                    .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Neuer Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() }.foregroundColor(.gray) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") {
                        onSave(title, project, priority, deadlineString, repeatOption.isEmpty ? nil : repeatOption, nil)
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(title.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .ncCyan)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    func prioBtn(_ label: String, value: String, color: Color) -> some View {
        Button {
            priority = value
        } label: {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label).font(.subheadline)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(priority == value ? color.opacity(0.15) : Color(red: 0.03, green: 0.03, blue: 0.06))
            .foregroundColor(priority == value ? color : .gray)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(priority == value ? color.opacity(0.3) : Color.white.opacity(0.04), lineWidth: 0.5))
        }
    }

    func projectColor(_ name: String) -> Color {
        switch name.lowercased() {
        case "naice": return .ncCyan
        case "foodloop": return .ncNeonGreen
        case "schaffer-wine": return .ncAmber
        case "parcelmate": return .ncPurple
        case "einfachr": return .ncBlue
        case "privat": return .ncRose
        default: return .gray
        }
    }
}

// MARK: - Edit Task Sheet
struct EditTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var taskService = NATaskService.shared
    let task: NATaskItem

    @State private var title = ""
    @State private var project = "nAIce"
    @State private var priority = "medium"
    @State private var deadlineDate = Date()
    @State private var hasDeadline = false
    @State private var repeatOption = ""
    @State private var showDeleteConfirm = false

    let projects = ["nAIce", "foodloop", "Schaffer-Wine", "parcelmate", "einfacHR", "Privat", "Sonstiges"]
    let repeatOptions = [("", "Nie"), ("daily", "Täglich"), ("weekday", "Wochentags"), ("weekly", "Wöchentlich"), ("monthly", "Monatlich")]

    private var deadlineString: String? {
        guard hasDeadline else { return nil }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: deadlineDate)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        TextField("Titel", text: $title)
                            .font(.body).foregroundColor(.white).padding(14)
                            .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 0.5))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(projects, id: \.self) { p in
                                    Button { project = p } label: {
                                        Text(p).font(.subheadline)
                                            .padding(.horizontal, 14).padding(.vertical, 8)
                                            .background(project == p ? Color.ncCyan.opacity(0.2) : Color(red: 0.03, green: 0.03, blue: 0.06))
                                            .foregroundColor(project == p ? .ncCyan : .gray)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }.fixedSize()
                                }
                            }.padding(.vertical, 4)
                        }

                        HStack(spacing: 10) {
                            ForEach([("low", "Niedrig", Color.ncCyan), ("medium", "Mittel", Color.ncAmber), ("high", "Hoch", Color.ncRose)], id: \.0) { (val, label, color) in
                                Button { priority = val } label: {
                                    Text(label).font(.subheadline)
                                        .padding(.horizontal, 16).padding(.vertical, 10)
                                        .frame(maxWidth: .infinity)
                                        .background(priority == val ? color.opacity(0.15) : Color(red: 0.03, green: 0.03, blue: 0.06))
                                        .foregroundColor(priority == val ? color : .gray)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            ForEach(repeatOptions, id: \.0) { (val, label) in
                                Button { repeatOption = val } label: {
                                    Text(label).font(.subheadline)
                                        .padding(.horizontal, 8).padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(repeatOption == val ? Color.ncCyan.opacity(0.15) : Color(red: 0.03, green: 0.03, blue: 0.06))
                                        .foregroundColor(repeatOption == val ? .ncCyan : .gray)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                    .padding(20)
                }
                .overlay(alignment: .bottom) {
                    if task.isLocal {
                        Button(role: .destructive) { showDeleteConfirm = true } label: {
                            Label("Task löschen", systemImage: "trash")
                                .font(.subheadline).frame(maxWidth: .infinity)
                                .padding(14).background(Color.ncRose.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                                .foregroundColor(.ncRose)
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Task bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() }.foregroundColor(.gray) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save(); dismiss() }
                        .font(.headline).foregroundColor(.ncCyan)
                }
            }
        }
        .onAppear {
            title = task.title
            project = task.project ?? "nAIce"
            priority = task.priority
            repeatOption = task.repeat ?? ""
            if let d = task.deadline, !d.isEmpty {
                hasDeadline = true
                let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
                if let date = f.date(from: d) { deadlineDate = date }
            }
        }
        .alert("Task löschen?", isPresented: $showDeleteConfirm) {
            Button("Löschen", role: .destructive) { Task { await taskService.deleteTask(task) }; dismiss() }
            Button("Abbrechen", role: .cancel) { }
        }
    }

    private func save() {
        Task {
            guard let url = URL(string: "https://health.santoslab.de/api/naice/tasks") else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = [
                "action": "update", "task_id": task.id,
                "title": title, "project": project, "priority": priority,
                "repeat": repeatOption.isEmpty ? "" : repeatOption,
                "deadline": deadlineString ?? ""
            ]
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            do { let (_, _) = try await URLSession.shared.data(for: req); await taskService.fetch() } catch {}
        }
    }
}