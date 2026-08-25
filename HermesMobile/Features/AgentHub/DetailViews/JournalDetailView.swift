import SwiftUI

// MARK: - Journal Detail View (alle Einträge aus Rollup)
struct JournalDetailView: View {
    @ObservedObject private var rollup = NARollupService.shared
    @ObservedObject private var journal = NAJournalService.shared
    @State private var showCheckin = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Journal").font(.title2.weight(.bold)).foregroundColor(.ncDark)

                if let j = rollup.rollup?.journal {
                    HStack {
                        Text("\(j.count) Einträge").font(.subheadline).foregroundColor(.ncMuted)
                        if let w = j.this_week { Text("· \(w) diese Woche").font(.caption).foregroundColor(.ncMuted) }
                        if let c = j.avg_clarity_week { Text("· Klarheit Ø \(c)/10").font(.caption).foregroundColor(.ncMuted) }
                        Spacer()
                        Button { showCheckin = true } label: {
                            Image(systemName: "plus.circle.fill").font(.title3).foregroundColor(.ncGreen)
                        }
                    }

                    if let entries = j.entries, !entries.isEmpty {
                        ForEach(entries) { entry in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(entry.text).font(.subheadline).foregroundColor(.ncDark)
                                if let t = entry.created_at {
                                    Text(String(t.prefix(16)).replacingOccurrences(of: "T", with: " "))
                                        .font(.caption).foregroundColor(.ncMuted)
                                }
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.6))
                            .cornerRadius(10)
                        }
                    } else {
                        Text("Noch keine Einträge.").font(.subheadline).foregroundColor(.ncMuted)
                    }
                } else {
                    Text("Lade Journal...").font(.subheadline).foregroundColor(.ncMuted)
                }

                // Lokale Einträge
                if !journal.entries.isEmpty {
                    Divider().foregroundColor(.ncSand.opacity(0.3))
                    Text("Lokal gespeichert").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                    ForEach(journal.entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.text).font(.subheadline).foregroundColor(.ncDark)
                            if let t = entry.created_at {
                                Text(String(t.prefix(10))).font(.caption).foregroundColor(.ncMuted)
                            }
                        }
                        .padding(10).background(Color.ncPaper).cornerRadius(10)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }
        .warmBackground()
        .navigationTitle("Journal")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showCheckin) { JournalCheckinSheet() }
        .task { await journal.fetch() }
    }
}

// MARK: - Journal Checkin Sheet (ausgelagert)
struct JournalCheckinSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedMood = "good"
    @State private var note = ""
    @State private var clarity = 5

    var body: some View {
        NavigationStack {
            Form {
                Section("Wie fühlst du dich?") {
                    HStack(spacing: 20) {
                        moodButton("good", "😊", "Gut")
                        moodButton("neutral", "😐", "Neutral")
                        moodButton("bad", "😔", "Nicht gut")
                    }
                }
                Section("Klarheit") {
                    VStack {
                        Slider(value: Binding(get: { Double(clarity) }, set: { clarity = Int($0) }), in: 1...10, step: 1)
                            .tint(.ncGreen)
                        Text("\(clarity)/10").font(.caption).foregroundColor(.ncMuted)
                    }
                }
                Section("Was beschäftigt dich?") {
                    TextField("Notiz...", text: $note, axis: .vertical)
                }
            }
            .navigationTitle("Journal Eintrag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        Task { await NAJournalService.shared.addEntry(text: note, mood: selectedMood, clarity: clarity) }
                        dismiss()
                    }
                }
            }
        }
    }

    func moodButton(_ m: String, _ emoji: String, _ label: String) -> some View {
        Button {
            selectedMood = m
        } label: {
            VStack(spacing: 4) {
                Text(emoji).font(.title2)
                Text(label).font(.caption2).foregroundColor(selectedMood == m ? .ncGreen : .ncMuted)
            }
            .padding(12)
            .background(selectedMood == m ? Color.ncGreen.opacity(0.08) : Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedMood == m ? Color.ncGreen : Color.gray.opacity(0.3), lineWidth: selectedMood == m ? 1.5 : 0.5))
        }
    }
}