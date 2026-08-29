import SwiftUI

struct TasksView: View {
    @EnvironmentObject var dataStore: WatchDataStore

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Aufgaben")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)

                let open = dataStore.tasks.filter { !$0.done }.count
                let high = dataStore.tasks.filter { !$0.done && $0.priority == "high" }.count

                HStack(spacing: 12) {
                    VStack(spacing: 2) {
                        Text("\(open)").font(.title3.weight(.bold)).foregroundColor(.cyan)
                        Text("Offen").font(.caption2).foregroundColor(.gray)
                    }
                    VStack(spacing: 2) {
                        Text("\(high)").font(.title3.weight(.bold)).foregroundColor(.red)
                        Text("Kritisch").font(.caption2).foregroundColor(.gray)
                    }
                    VStack(spacing: 2) {
                        Text("\(dataStore.tasks.count)").font(.title3.weight(.bold)).foregroundColor(.gray)
                        Text("Gesamt").font(.caption2).foregroundColor(.gray)
                    }
                }

                if dataStore.tasks.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checklist")
                            .font(.title2).foregroundColor(.gray)
                        Text("Keine Tasks").font(.subheadline).foregroundColor(.gray)
                        Text("Sync vom iPhone").font(.caption2).foregroundColor(.gray)
                    }
                    .padding(.top, 20)
                } else {
                    ForEach(dataStore.tasks) { task in
                        Button {
                            dataStore.toggleTask(task)
                        } label: {
                            HStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(task.done ? Color.green.opacity(0.15) : priorityColor(task.priority).opacity(0.12))
                                        .frame(width: 22, height: 22)
                                    Image(systemName: task.done ? "checkmark" : "circle.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(task.done ? .green : priorityColor(task.priority))
                                }

                                VStack(alignment: .leading, spacing: 0) {
                                    Text(task.title)
                                        .font(.system(size: 12))
                                        .foregroundColor(task.done ? .gray : .white)
                                        .strikethrough(task.done)
                                        .lineLimit(2)
                                    if let p = task.project {
                                        Text(p).font(.system(size: 8)).foregroundColor(.gray)
                                    }
                                }

                                Spacer()

                                if task.done {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 8)).foregroundColor(.green)
                                } else if task.priority == "high" {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 8)).foregroundColor(.red)
                                }
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
    }

    private func priorityColor(_ p: String) -> Color {
        switch p.lowercased() {
        case "high": return .red
        case "medium": return .orange
        default: return .cyan
        }
    }
}