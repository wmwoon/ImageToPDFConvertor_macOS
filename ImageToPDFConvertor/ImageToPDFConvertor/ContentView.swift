import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var images: [NSImage] = []
    @State private var showPicker = false
    @State private var draggingIndex: Int? = nil
    @State private var showPDFPicker = false
    @State private var selectedPDFs: [URL] = []
    @State private var isTargeted: Bool = false
    private let pdfMerger = PDFMerger() // ✅ Create an instance

    // ✅ Keep savePDF inside ContentView
    func savePDF() {
        let pdf = PDFDocument()
        
        for (index, image) in images.enumerated() {
            if let pdfPage = PDFPage(image: image) {
                pdf.insert(pdfPage, at: index)
            }
        }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = "ConvertedImages.pdf"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            pdf.write(to: url)
        }
    }
    
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

                    List {
                            ForEach(Array(selectedPDFs.enumerated()), id: \.element) { index, pdfURL in
                                Text(pdfURL.lastPathComponent)
                                    .padding()
                                    .background(draggingIndex == index ? Color.gray.opacity(0.3) : Color.clear)
                                    .onDrag {
                                        draggingIndex = index
                                        return NSItemProvider(object: "\(index)" as NSString)
                                    }
                                    .onDrop(of: [UTType.text.identifier], delegate: PDFDropDelegate(index: index, selectedPDFs: $selectedPDFs, draggingIndex: $draggingIndex))
                            }
                        }
                    .frame(height: 150)
                    .padding()
                }
            } else if !images.isEmpty {
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
                    pdfMerger.mergePDFs(pdfURLs: selectedPDFs)
                }
                .padding()
                
                Button("Clear Selection") {
                    images.removeAll()
                    selectedPDFs.removeAll()
                }
                .disabled(images.isEmpty && selectedPDFs.isEmpty)
                .padding()
            }
            
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
                                }
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
                print("❌ Failed to load images:", error.localizedDescription)
            }
        }
        .fileImporter(isPresented: $showPDFPicker, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { result in
            DispatchQueue.main.async {
                do {
                    selectedPDFs = try result.get()
                    print("📂 Selected PDFs: \(selectedPDFs.map { $0.path })")
                } catch {
                    print("❌ Failed to import PDFs:", error.localizedDescription)
                }
            }
        }
        .padding()
    }

    func movePDF(from source: IndexSet, to destination: Int) {
        selectedPDFs.move(fromOffsets: source, toOffset: destination)
    }
}
