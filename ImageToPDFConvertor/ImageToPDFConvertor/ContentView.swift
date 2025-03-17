import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var images: [NSImage] = []
    @State private var showPicker = false
    
    var body: some View {
        VStack {
            if images.isEmpty {
                Text("Drag and drop images or select them")
                    .padding()
            } else {
                ScrollView {
                    ForEach(images, id: \.self) { image in
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 100)
                            .padding()
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
                    images.removeAll()  // 🔹 Clears all selected images
                }
                .disabled(images.isEmpty) // 🔹 Disable when there are no images
                .padding()
            }
        }
        
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // ✅ Ensure full-screen drop target
        .contentShape(Rectangle())  // ✅ Makes the whole view interactable
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

                            // ** Try opening file first **
                            if FileManager.default.fileExists(atPath: fileURL.path) {
                                print("📂 File exists, trying to access it...")
                            } else {
                                print("⚠️ File does not exist!")
                            }

                            // ** Attempt security-scoped access **
                            if fileURL.startAccessingSecurityScopedResource() {
                                defer { fileURL.stopAccessingSecurityScopedResource() }  // Always stop access later

                                if let image = NSImage(contentsOf: fileURL) {
                                    images.append(image)  // ✅ Successfully loads image
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
                let urls = try result.get()  // ✅ Get multiple file URLs
                for url in urls {
                    if url.startAccessingSecurityScopedResource() {  // ✅ Fix for sandboxed environments
                        if let image = NSImage(contentsOf: url) {
                            images.append(image)
                        }
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            } catch {
                print("Failed to load images:", error.localizedDescription)  // ✅ Error handling
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
        savePanel.allowedContentTypes = [.pdf] // ✅ Fixed: Using .allowedContentTypes instead of .allowedFileTypes
        savePanel.nameFieldStringValue = "ConvertedImages.pdf"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            pdf.write(to: url)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
