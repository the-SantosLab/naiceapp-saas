import SwiftUI

// MARK: - Tasks View
struct NAIceTasksView: View {
    @ObservedObject private var taskService = NATaskService.shared
    @ObservedObject private var rollup = NARollupService.shared
    @State private var showAddSheet = false
    @State private var filterDone = false

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
                            Text("Eigene Tasks + Pipeline-Aufgaben")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        HStack(spacing: 8) {
                            if taskService.isLoading || rollup.isLoading {
                                ProgressView().scaleEffect(0.7).tint(.ncCyan)
                            }
                            Button {
                                withAnimation { filterDone.toggle() }
                            } label: {
                                Image(systemName: filterDone ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(filterDone ? .ncCyan : .gray)
                            }
                            Button {
                                showAddSheet = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.ncCyan)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    let filtered = filterDone ? taskService.tasks.filter { $0.status != "done" } : taskService.tasks

                    if filtered.isEmpty {
                        emptySection.padding(.horizontal, 16)
                    } else {
                        let open = taskService.tasks.filter { $0.status != "done" }.count
                        let done = taskService.tasks.filter { $0.status == "done" }.count
                        HStack(spacing: 12) {
                            statCard(icon: "tray.full.fill", value: "\(taskService.tasks.count)", label: "Gesamt", color: .ncCyan)
                            statCard(icon: "exclamationmark.circle.fill", value: "\(open)", label: "Offen", color: .ncAmber)
                            statCard(icon: "checkmark.circle.fill", value: "\(done)", label: "Erledigt", color: .ncNeonGreen)
                        }
                        .padding(.horizontal, 16)

                        let high = filtered.filter { $0.priority == "high" && $0.status != "done" }
                        if !high.isEmpty {
                            taskSection(title: "Kritisch", icon: "exclamationmark.triangle.fill", tasks: high, accent: .ncRose)
                        }

                        let openTasks = filtered.filter { $0.priority != "high" && $0.status != "done" }
                        if !openTasks.isEmpty {
                            taskSection(title: "Offen (\(openTasks.count))", icon: "circle", tasks: openTasks, accent: .ncCyan)
                        }

                        if !filterDone {
                            let doneTasks = filtered.filter { $0.status == "done" }
                            if !doneTasks.isEmpty {
                                taskSection(title: "Erledigt (\(doneTasks.count))", icon: "checkmark.circle.fill", tasks: doneTasks, accent: .ncNeonGreen)
                            }
                        }
                    }
                }
                .padding(.bottom, 30)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task { await taskService.fetch() }
            .refreshable { await taskService.fetch() }
        }
        .sheet(isPresented: $showAddSheet) {
            AddTaskSheet { title, project, priority, deadline in
                Task { await taskService.addTask(title: title, project: project, priority: priority, deadline: deadline) }
            }
        }
    }

    private func taskSection(title: String, icon: String, tasks: [NATaskItem], accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.caption).foregroundColor(accent)
                Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.white)
                Spacer()
                Text("\(tasks.count)")
                    .font(.caption.weight(.bold)).foregroundColor(accent)
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

    private func taskCard(_ task: NATaskItem, accent: Color) -> some View {
        HStack(spacing: 12) {
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

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(task.status == "done" ? .gray : .white)
                    .strikethrough(task.status == "done")
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let p = task.project {
                        HStack(spacing: 4) {
                            Circle().fill(accent).frame(width: 4, height: 4)
                            Text(p).font(.caption2).foregroundColor(.gray)
                        }
                        .fixedSize()
                    }
                    HStack(spacing: 4) {
                        Circle().fill(task.statusDot).frame(width: 4, height: 4)
                        Text(task.status == "done" ? "Erledigt" : task.status.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.caption2).foregroundColor(.gray)
                    }
                    .fixedSize()
                    if task.isLocal {
                        HStack(spacing: 3) {
                            Image(systemName: "iphone").font(.system(size: 8))
                            Text("Eigen").font(.caption2)
                        }
                        .foregroundColor(.gray.opacity(0.6))
                        .fixedSize()
                    }
                    // Deadline badge
                    if let d = task.deadline, !d.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar").font(.system(size: 8))
                            Text(task.deadlineLabel)
                        }
                        .font(.caption2)
                        .foregroundColor(task.deadlineColor)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(task.deadlineColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                        .fixedSize()
                    }
                }
            }

            Spacer()

            if task.isLocal {
                Button(role: .destructive) {
                    Task { await taskService.deleteTask(task) }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }

    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12)).frame(width: 28, height: 28)
                Image(systemName: icon).font(.system(size: 11)).foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                Text(label).font(.caption2).foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
    }

    private var emptySection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.ncNeonGreen.opacity(0.1)).frame(width: 48, height: 48)
                Image(systemName: "checkmark.circle.fill").font(.title2).foregroundColor(.ncNeonGreen)
            }
            Text("Keine offenen Aufgaben")
                .font(.subheadline.weight(.semibold)).foregroundColor(.white)
            Text("Tippe auf + um einen neuen Task zu erstellen.")
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
    let onSave: (String, String, String, String?) -> Void

    @State private var title = ""
    @State private var project = "nAIce"
    @State private var priority = "medium"
    @State private var deadlineDate = Date().addingTimeInterval(86400 * 7)
    @State private var hasDeadline = false

    let projects = ["nAIce", "foodloop", "Schaffer-Wine", "parcelmate", "einfacHR", "Privat", "Sonstiges"]

    private var deadlineString: String? {
        guard hasDeadline else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: deadlineDate)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Titel")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.gray)
                                .textCase(.uppercase)
                                .tracking(1)
                            TextField("Task eingeben...", text: $title)
                                .font(.body)
                                .foregroundColor(.white)
                                .padding(14)
                                .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                        }

                        // Project
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Projekt")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.gray)
                                .textCase(.uppercase)
                                .tracking(1)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(projects, id: \.self) { p in
                                        Button {
                                            project = p
                                        } label: {
                                            Text(p)
                                                .font(.subheadline)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(project == p ? Color.ncCyan.opacity(0.2) : Color(red: 0.03, green: 0.03, blue: 0.06))
                                                .foregroundColor(project == p ? .ncCyan : .gray)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(project == p ? Color.ncCyan.opacity(0.3) : Color.white.opacity(0.04), lineWidth: 0.5)
                                                )
                                        }
                                        .fixedSize()
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        // Priority
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Priorität")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.gray)
                                .textCase(.uppercase)
                                .tracking(1)
                            HStack(spacing: 10) {
                                prioBtn("Niedrig", value: "low", color: .ncCyan)
                                prioBtn("Mittel", value: "medium", color: .ncAmber)
                                prioBtn("Hoch", value: "high", color: .ncRose)
                            }
                        }

                        // Deadline
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Deadline")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.gray)
                                    .textCase(.uppercase)
                                    .tracking(1)
                                Spacer()
                                Toggle("", isOn: $hasDeadline)
                                    .labelsHidden()
                                    .tint(.ncCyan)
                            }
                            if hasDeadline {
                                DatePicker(
                                    "Datum",
                                    selection: $deadlineDate,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.graphical)
                                .tint(.ncCyan)
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }.foregroundColor(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") {
                        onSave(title, project, priority, deadlineString)
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
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(priority == value ? color.opacity(0.3) : Color.white.opacity(0.04), lineWidth: 0.5)
            )
        }
    }
}