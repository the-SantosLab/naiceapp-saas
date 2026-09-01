import SwiftUI

struct NAMoveSheetView: View {
    let file: NFile
    let folders: [String]
    let onMove: (String) -> Void
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                Text("Verschieben: \(file.name)").font(.subheadline).foregroundColor(.gray)
                Button("Kein Ordner (Stamm)") { onMove(""); isPresented = false }.foregroundColor(.white)
                ForEach(folders, id: \.self) { folder in
                    Button(folder) { onMove(folder); isPresented = false }.foregroundColor(.white)
                }
            }
            .background(Color.black).scrollContentBackground(.hidden)
            .navigationTitle("Verschieben").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Abbrechen") { isPresented = false }.foregroundColor(.ncCyan)
                }
            }
        }
    }
}

// MARK: - Create Folder Sheet
