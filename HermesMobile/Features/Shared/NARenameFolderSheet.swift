import SwiftUI

struct NARenameFolderSheet: View {
    let currentName: String
    let onRename: (String) -> Void
    @Binding var isPresented: Bool
    @State private var name = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Ordner umbenennen").font(.headline.weight(.bold)).foregroundColor(.white)
                TextField("Name", text: $name).font(.subheadline).foregroundColor(.white)
                    .padding(14).background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    .padding(.horizontal, 20)
                Button("Speichern") {
                    onRename(name)
                    isPresented = false
                }
                .font(.headline.weight(.semibold)).foregroundColor(.white).frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(name.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.3) : Color.ncCyan, in: RoundedRectangle(cornerRadius: 14))
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty).padding(.horizontal, 20)
                Spacer()
            }
            .padding(.top, 24).background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { isPresented = false }.foregroundColor(.ncCyan)
                }
            }
        }
        .onAppear { name = currentName }
    }
}