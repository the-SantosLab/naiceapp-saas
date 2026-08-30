import SwiftUI

struct HabitsView: View {
    @EnvironmentObject var dataStore: WatchDataStore

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Heutige Habits")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)

                let done = dataStore.habits.filter { $0.done }.count
                let total = dataStore.habits.count

                if total > 0 {
                    HStack(spacing: 4) {
                        Text("\(done)/\(total)")
                            .font(.title3.weight(.bold))
                            .foregroundColor(done == total ? .green : .cyan)
                        Text("erledigt")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                if dataStore.habits.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "figure.walk")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Keine Habits")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text("Sync vom iPhone")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 20)
                } else {
                    ForEach(dataStore.habits) { habit in
                        Button {
                            dataStore.toggleHabit(habit)
                        } label: {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(habit.done ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                                        .frame(width: 28, height: 28)
                                    Image(systemName: habit.done ? "checkmark" : habit.icon)
                                        .font(.system(size: 11))
                                        .foregroundColor(habit.done ? .green : .gray)
                                }

                                Text(habit.name)
                                    .font(.subheadline)
                                    .foregroundColor(habit.done ? .gray : .white)
                                    .strikethrough(habit.done)

                                Spacer()

                                if habit.done {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.green)
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
}