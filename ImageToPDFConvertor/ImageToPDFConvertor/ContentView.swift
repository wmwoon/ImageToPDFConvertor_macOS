import SwiftUI
import PDFKit
import UniformTypeIdentifiers

func mergePDFs(pdfURLs: [URL], outputURL: URL) {
    let mergedPDF = PDFDocument()

    for pdfURL in pdfURLs {
        if let pdfDocument = PDFDocument(url: pdfURL) {
            for pageIndex in 0..<pdfDocument.pageCount {
                if let page = pdfDocument.page(at: pageIndex) {
                    mergedPDF.insert(page, at: mergedPDF.pageCount)
                }
            }
        } else {
            print("❌ Failed to load PDF: \(pdfURL.path)")
        }
    }

    if mergedPDF.pageCount > 0 {
        if mergedPDF.write(to: outputURL) {
            print("✅ Merged PDF saved to: \(outputURL.path)")
        } else {
            print("❌ Failed to save merged PDF.")
        }
    } else {
        print("⚠️ No pages found to merge!")
    }
}

struct ContentView: View {
    @State private var images: [NSImage] = []
    @State private var showPicker = false
    @State private var draggingIndex: Int? = nil
    @State private var showPDFPicker = false
    @State private var selectedPDFs: [URL] = []
    @State private var isTargeted: Bool = false
    
    var body: some View {
        VStack {
            Text("Drag & Drop PDFs or Images Here")
                    .font(.title2)
                    .padding()
                    .background(isTargeted ? Color.blue.opacity(0.2) : Color.clear)
                    .cornerRadius(10)
            if !selectedPDFs.isEmpty {
                VStack {
                    Text("Selected PDFs:")
                        .font(.headline)
                        .padding(.top)

                    List(selectedPDFs, id: \.self) { pdfURL in
                        Text(pdfURL.lastPathComponent)
                            .onDrag {
                                return NSItemProvider(object: pdfURL.absoluteString as NSString) // 🔥 Make PDF draggable
                            }
                    }
                    .frame(height: 150) // Adjust height as needed
                }
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
                
                Button("Select PDFs to Merge") {
                    showPDFPicker = true
                }
                .padding()
                
                Button("Merge PDFs") {
                    guard !selectedPDFs.isEmpty else {
                        print("⚠️ No PDFs selected for merging.")
                        return
                    }
                    
                    let outputPDF = URL(fileURLWithPath: "/Users/waimeng/Desktop/merged.pdf")
                    mergePDFs(pdfURLs: selectedPDFs, outputURL: outputPDF)
                }
                .padding()
                
                Button("Clear Selection") {
                    images.removeAll()
                    selectedPDFs.removeAll()
                }
                .disabled(images.isEmpty && selectedPDFs.isEmpty)
                .padding()
            }
            
            // 🔥 Drag-to-delete trash area
            TrashArea(images: $images, draggingIndex: $draggingIndex, selectedPDFs: $selectedPDFs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
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

                        let imageExtensions = ["jpg", "jpeg", "png", "tiff", "bmp", "gif"]
                        if imageExtensions.contains(fileExtension) {
                            print("✅ Successfully dropped image: \(fileURL.path)")
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
                        } else if fileExtension == "pdf" {
                            print("✅ Successfully dropped PDF: \(fileURL.path)")
                            selectedPDFs.append(fileURL)
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
        
        .fileImporter(isPresented: $showPDFPicker, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { result in
            DispatchQueue.main.async {
                do {
                    selectedPDFs = try result.get()  // ✅ Assign selected PDFs
                    print("📂 Selected PDFs: \(selectedPDFs.map { $0.path })")
                } catch {
                    print("❌ Failed to import PDFs:", error.localizedDescription)
                }
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
    @Binding var selectedPDFs: [URL]
    
    var body: some View {
        Text("🗑️ Drag here to delete")
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.red.opacity(0.7))
            .cornerRadius(10)
            .padding()
            .onDrop(of: [UTType.text.identifier, UTType.fileURL.identifier], isTargeted: nil) { providers in
                if let draggingIndex = draggingIndex {
                    DispatchQueue.main.async {
                        images.remove(at: draggingIndex)
                        self.draggingIndex = nil
                    }
                    return true
                }
                
                // 🔥 Handle PDFs
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
                return true
            }
    }
}
