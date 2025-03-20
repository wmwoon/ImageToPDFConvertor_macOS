import SwiftUI
import UniformTypeIdentifiers

struct TrashArea: View {
    @Binding var images: [NSImage]
    @Binding var draggingIndex: Int?
    @Binding var selectedPDFs: [URL]

    var body: some View {
        Text("🗑️ Drag here to delete")
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.red.opacity(0.7))
            .cornerRadius(10)
            .padding()
            .onDrop(of: [UTType.text.identifier, UTType.fileURL.identifier], isTargeted: nil) { providers in
                var didDelete = false

                // 🖼️ Handle image deletion
                if let draggingIndex = draggingIndex {
                    DispatchQueue.main.async {
                        images.remove(at: draggingIndex)
                        self.draggingIndex = nil
                    }
                    didDelete = true
                }
                
                // 📂 Handle PDF deletion
                for provider in providers {
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (data, error) in
                        DispatchQueue.main.async {
                            guard let data = data as? Data,
                                  let fileURL = URL(dataRepresentation: data, relativeTo: nil) else {
                                print("⚠️ Failed to retrieve PDF file URL")
                                return
                            }

                            // 🗑️ Remove PDF if it's in the list
                            if let index = selectedPDFs.firstIndex(of: fileURL) {
                                selectedPDFs.remove(at: index)
                                print("🗑️ Deleted PDF: \(fileURL.lastPathComponent)")
                            }
                        }
                    }
                }

                return didDelete
            }
    }
}
