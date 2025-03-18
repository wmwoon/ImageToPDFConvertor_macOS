import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var images: [NSImage] = []
    @State private var showPicker = false
    @State private var draggingIndex: Int? = nil
    
    var body: some View {
        VStack {
            if images.isEmpty {
                Text("Drag and drop images or select them")
                    .padding()
            } else {
                VStack {
                    ForEach(Array(images.enumerated()), id: \.element) { index, image in
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 100)
                            .padding()
                            .background(draggingIndex == index ? Color.gray.opacity(0.3) : Color.clear)
                            .onDrag {
                                draggingIndex = index
                                return NSItemProvider(object: "\(index)" as NSString)
                            }
                            .onDrop(of: [UTType.text.identifier], delegate: DropViewDelegate(index: index, images: $images, draggingIndex: $draggingIndex))
                    }
                }
            }

            HStack {
                Button("Select Images") {
                    showPicker = true
                }
                .padding()
                
                Button("Convert to PDF") {
                    savePDF()
                }
                .disabled(images.isEmpty)
                .padding()
                
                Button("Clear Selection") {
                    images.removeAll()
                }
                .disabled(images.isEmpty)
                .padding()
            }

            // 🔥 Drag-to-delete trash area
            TrashArea(images: $images, draggingIndex: $draggingIndex)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            for provider in providers {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (data, error) in
                    DispatchQueue.main.async {
                        guard let data = data as? Data,
                              let fileURL = URL(dataRepresentation: data, relativeTo: nil) else {
                            print("⚠️ Failed to retrieve file URL")
                            return
                        }

                        let fileExtension = fileURL.pathExtension.lowercased()
                        print("🔍 File extension detected: \(fileExtension)")

                        let supportedExtensions = ["jpg", "jpeg", "png", "tiff", "bmp", "gif"]
                        if supportedExtensions.contains(fileExtension) {
                            print("✅ Successfully dropped file: \(fileURL.path)")

                            if FileManager.default.fileExists(atPath: fileURL.path) {
                                print("📂 File exists, trying to access it...")
                            } else {
                                print("⚠️ File does not exist!")
                            }

                            if fileURL.startAccessingSecurityScopedResource() {
                                defer { fileURL.stopAccessingSecurityScopedResource() }

                                if let image = NSImage(contentsOf: fileURL) {
                                    images.append(image)
                                } else {
                                    print("⚠️ Failed to load NSImage from URL: \(fileURL)")
                                }
                            } else {
                                print("⚠️ Failed to access security-scoped resource - Check App Sandbox settings!")
                            }
                        } else {
                            print("⚠️ Unsupported file type: \(fileExtension.isEmpty ? "Unknown" : fileExtension)")
                        }
                    }
                }
            }
            return true
        }
        .fileImporter(isPresented: $showPicker, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            do {
                let urls = try result.get()
                for url in urls {
                    if url.startAccessingSecurityScopedResource() {
                        if let image = NSImage(contentsOf: url) {
                            images.append(image)
                        }
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            } catch {
                print("Failed to load images:", error.localizedDescription)
            }
        }
        .padding()
    }

    func savePDF() {
        let pdf = PDFDocument()

        for (index, image) in images.enumerated() {
            let pdfPage = PDFPage(image: image)
            pdf.insert(pdfPage!, at: index)
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = "ConvertedImages.pdf"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            pdf.write(to: url)
        }
    }
}

// 🔹 Drag & Drop Delegate (Handles rearrange AND deletion)
struct DropViewDelegate: DropDelegate {
    let index: Int
    @Binding var images: [NSImage]
    @Binding var draggingIndex: Int?

    func performDrop(info: DropInfo) -> Bool {
        guard let draggingIndex = draggingIndex, draggingIndex != index else { return false }
        
        let movedImage = images.remove(at: draggingIndex)
        images.insert(movedImage, at: index)

        DispatchQueue.main.async { self.draggingIndex = nil }
        return true
    }

    func dropEntered(info: DropInfo) {
        if let draggingIndex = draggingIndex, draggingIndex != index {
            let movedImage = images.remove(at: draggingIndex)
            images.insert(movedImage, at: index)
            self.draggingIndex = index
        }
    }
}

// 🗑️ Trash Drop Area
struct TrashArea: View {
    @Binding var images: [NSImage]
    @Binding var draggingIndex: Int?
    
    var body: some View {
        Text("🗑️ Drag here to delete")
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.red.opacity(0.7))
            .cornerRadius(10)
            .padding()
            .onDrop(of: [UTType.text.identifier], isTargeted: nil) { providers in
                if let draggingIndex = draggingIndex {
                    DispatchQueue.main.async {
                        images.remove(at: draggingIndex)  // 🔥 Delete image
                        self.draggingIndex = nil
                    }
                    return true
                }
                return false
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
