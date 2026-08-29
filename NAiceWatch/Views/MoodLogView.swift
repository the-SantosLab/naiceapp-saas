import SwiftUI

struct MoodLogView: View {
    @EnvironmentObject var dataStore: WatchDataStore
    @State private var selectedMood: String? = nil
    @State private var note = ""
    @State private var saved = false

    let moods = [
        ("😊", "Großartig"), ("😐", "Neutral"), ("😕", "Schlecht"),
        ("😢", "Traurig"), ("😡", "Wütend"), ("😴", "Müde"),
        ("🤗", "Dankbar"), ("🤔", "Nachdenklich"), ("🔥", "Motiviert")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Wie fühlst du dich?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
                    ForEach(moods, id: \.0) { (emoji, label) in
                        Button {
                            selectedMood = emoji
                            dataStore.saveMood(emoji, note: note)
                            withAnimation { saved = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation { saved = false }
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text(emoji).font(.title2)
                                Text(label).font(.system(size: 7)).foregroundColor(.gray)
                            }
                            .padding(6)
                            .background(selectedMood == emoji ? Color.cyan.opacity(0.2) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if saved {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("Gespeichert!")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                if !dataStore.moods.isEmpty {
                    Divider().background(.gray.opacity(0.3))

                    Text("Letzte Einträge")
                        .font(.caption2)
                        .foregroundColor(.gray)

                    ForEach(dataStore.moods.prefix(5)) { entry in
                        HStack {
                            Text(entry.emoji).font(.title3)
                            VStack(alignment: .leading, spacing: 1) {
                                if !entry.note.isEmpty {
                                    Text(entry.note).font(.caption2).foregroundColor(.gray).lineLimit(1)
                                }
                                Text(entry.timestamp, style: .time)
                                    .font(.system(size: 8)).foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        .padding(6)
                        .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding()
        }
    }
}