import SwiftUI

// MARK: - Notes View
struct NANotesView: View {
    @ObservedObject private var notesService = NANotesService.shared
    @State private var showAddSheet = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notizen")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                        Text("\(notesService.notes.count) Notizen")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    if notesService.isLoading {
                        ProgressView().scaleEffect(0.7).tint(.ncCyan)
                    }
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.ncCyan)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                if notesService.notes.isEmpty {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle().fill(Color.ncCyan.opacity(0.1)).frame(width: 48, height: 48)
                            Image(systemName: "note.text")
                                .font(.title2)
                                .foregroundColor(.ncCyan)
                        }
                        Text("Keine Notizen")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                        Text("Tippe auf + um eine Notiz zu erstellen.\nDer KI-Agent kann auch selbst Notizen schreiben.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    .padding(.horizontal, 16)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(notesService.notes) { note in
                            NavigationLink(destination: NoteEditorView(note: note)) {
                                NoteCard(note: note)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await notesService.fetch() }
        .refreshable { await notesService.fetch() }
        .sheet(isPresented: $showAddSheet) {
            AddNoteSheet { title, content in
                Task { await notesService.addNote(title: title, content: content) }
            }
        }
    }
}

// MARK: - Note Card
struct NoteCard: View {
    let note: NANote

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.ncCyan.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: "note.text")
                        .font(.system(size: 11))
                        .foregroundColor(.ncCyan)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(note.formattedDate)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.5))
            }

            if !note.preview.isEmpty {
                Text(note.preview)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .padding(.leading, 36)
            }
        }
        .padding(12)
        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }
}

// MARK: - Note Editor
struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let note: NANote
    @ObservedObject private var notesService = NANotesService.shared

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var isSaving = false
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                // Title
                TextField("Titel", text: $title)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                Divider().background(Color.white.opacity(0.06))

                // Content
                TextEditor(text: $content)
                    .font(.body)
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .background(Color.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        isSaving = true
                        await notesService.updateNote(id: note.id, title: title, content: content)
                        isSaving = false
                        dismiss()
                    }
                } label: {
                    if isSaving {
                        ProgressView().scaleEffect(0.7).tint(.ncCyan)
                    } else {
                        Text("Speichern")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.ncCyan)
                    }
                }
                .disabled(isSaving)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            title = note.title
            content = note.content
        }
        .alert("Notiz löschen?", isPresented: $showDeleteConfirm) {
            Button("Löschen", role: .destructive) {
                Task { await notesService.deleteNote(note); dismiss() }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Diese Notiz wird dauerhaft gelöscht.")
        }
    }
}

// MARK: - Add Note Sheet
struct AddNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (String, String) -> Void

    @State private var title = ""
    @State private var content = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    TextField("Titel", text: $title)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)

                    Divider().background(Color.white.opacity(0.06))

                    TextEditor(text: $content)
                        .font(.body)
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .background(Color.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .overlay(alignment: .topLeading) {
                            if content.isEmpty {
                                Text("Notiz eingeben...")
                                    .font(.body)
                                    .foregroundColor(.gray.opacity(0.5))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                    .allowsHitTesting(false)
                            }
                        }
                }
            }
            .navigationTitle("Neue Notiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }.foregroundColor(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let t = title.trimmingCharacters(in: .whitespaces)
                        onSave(t.isEmpty ? "Notiz" : t, content)
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.ncCyan)
                }
            }
        }
    }
}