import SwiftUI
import AVFoundation

// MARK: - Camera View (Scan → Aktion)
struct NACameraView: View {
    @StateObject private var vision = NAVisionService.shared
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var showResult = false
    @State private var result: VisionResult?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scanner")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                        Text("Rechnung, Visitenkarte, Notiz – ein Foto genugt.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Camera Button
                Button {
                    showCamera = true
                } label: {
                    VStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.ncCyan.opacity(0.08))
                                .frame(height: 200)
                                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.ncCyan.opacity(0.2), lineWidth: 1))

                            if let img = capturedImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 190)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.system(size: 48))
                                        .foregroundColor(.ncCyan)
                                    Text("Foto aufnehmen")
                                        .font(.headline.weight(.semibold))
                                        .foregroundColor(.white)
                                    Text("Rechnung, Visitenkarte, Notiz oder Whiteboard")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)

                // Processing
                if vision.isProcessing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.ncCyan)
                        Text("Analysiere Bild...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        HStack(spacing: 6) {
                            Circle().fill(Color.ncCyan).frame(width: 6, height: 6)
                            Text("OCR wird ausgefuhrt")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    )
                    .padding(.horizontal, 16)
                }

                // Result
                if let result = result {
                    resultCard(result)
                        .padding(.horizontal, 16)
                }

                // Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(icon: "bolt.fill", title: "Schnellaktionen")

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        quickAction("doc.viewfinder", "Rechnung", "Betrag + Kategorie", .ncNeonGreen)
                        quickAction("person.text.rectangle", "Visitenkarte", "Kontakt anlegen", .ncCyan)
                        quickAction("note.text", "Notiz", "Journal-Eintrag", .ncAmber)
                        quickAction("rectangle.3.group", "Whiteboard", "Ideen erfassen", .ncPurple)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 30)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCamera) {
            ImagePickerView(sourceType: .camera) { image in
                capturedImage = image
                processImage(image)
            }
        }
    }

    private func processImage(_ image: UIImage) {
        vision.isProcessing = true
        result = nil
        Task {
            let visionResult = await vision.processImage(image)
            await MainActor.run {
                self.result = visionResult
                vision.isProcessing = false
                vision.executeAction(for: visionResult)
            }
        }
    }

    private func resultCard(_ result: VisionResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: result.type.icon)
                    .font(.caption)
                    .foregroundColor(result.type.color)
                Text(result.type.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(result.confidence * 100))%")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Text(result.text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(8)

            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.system(size: 8))
                    .foregroundColor(.ncCyan)
                Text(result.suggestedAction)
                    .font(.caption)
                    .foregroundColor(.ncCyan)
            }
            .padding(8)
            .background(Color.ncCyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(result.type.color.opacity(0.2), lineWidth: 0.5))
        )
    }

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.ncCyan)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
        }
    }

    private func quickAction(_ icon: String, _ title: String, _ subtitle: String, _ color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
            }
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.system(size: 8))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }
}

// MARK: - Image Picker (Camera)
struct ImagePickerView: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImage: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void
        init(onImage: @escaping (UIImage) -> Void) { self.onImage = onImage }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}