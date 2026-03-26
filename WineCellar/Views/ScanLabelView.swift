import SwiftUI
import UIKit

struct ScanLabelView: View {
    @Environment(\.dismiss) private var dismiss

    let onScan: (ScannedWineData) -> Void

    @State private var showingCamera = true
    @State private var isProcessing = false
    @State private var scannedData: ScannedWineData?

    private let scanner = LabelScannerService()

    var body: some View {
        NavigationStack {
            VStack {
                if isProcessing {
                    Spacer()
                    ProgressView("Reading label...")
                        .font(.headline)
                    Spacer()
                } else if let data = scannedData {
                    scanResultView(data)
                } else {
                    ContentUnavailableView {
                        Label("Take a Photo", systemImage: "camera")
                    } description: {
                        Text("Photograph the front label of the wine bottle.")
                    }
                }
            }
            .navigationTitle("Scan Label")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker { image in
                    processImage(image)
                }
            }
        }
    }

    @ViewBuilder
    private func scanResultView(_ data: ScannedWineData) -> some View {
        List {
            Section("Detected Info") {
                resultRow("Producer", value: data.producer)
                resultRow("Wine Name", value: data.name)
                resultRow("Variety", value: data.variety)
                resultRow("Region", value: data.region)
                resultRow("Vintage", value: data.vintage.map { String($0) })
            }

            Section {
                Button("Use These Results") {
                    onScan(data)
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .bold()

                Button("Retake Photo") {
                    scannedData = nil
                    showingCamera = true
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func resultRow(_ label: String, value: String?) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value ?? "Not detected")
                .foregroundStyle(value != nil ? .primary : .tertiary)
        }
    }

    private func processImage(_ image: UIImage) {
        isProcessing = true
        Task {
            let data = await scanner.scan(image: image)
            await MainActor.run {
                scannedData = data
                isProcessing = false
            }
        }
    }
}

// MARK: - UIImagePickerController Wrapper

struct ImagePicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        // Use camera if available, fall back to photo library
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImagePicked: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImagePicked = onImagePicked
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
