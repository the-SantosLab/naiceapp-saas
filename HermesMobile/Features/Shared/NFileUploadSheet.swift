import SwiftUI
import PhotosUI

struct NFileUploadSheet: View {
    @ObservedObject private var fs = NAFilesService.shared
    @State private var showPicker = false
    @State private var selectedItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Button("Aus Bibliothek wahlen") { showPicker = true }
                    .font(.headline.weight(.semibold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.ncCyan, in: RoundedRectangle(cornerRadius: 14)).padding(.horizontal, 40)
                Spacer()
            }
            .padding(.top, 40)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Upload").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Fertig") { dismiss() }.foregroundColor(.ncCyan) } }
            .photosPicker(isPresented: $showPicker, selection: $selectedItem, matching: .any(of: [.images, .videos]))
            .onChange(of: selectedItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        let name = "upload_\(Int(Date().timeIntervalSince1970)).jpg"
                        await fs.uploadFile(name: name, data: data)
                        await fs.fetchFiles()
                        dismiss()
                    }
                }
            }
        }
    }
}