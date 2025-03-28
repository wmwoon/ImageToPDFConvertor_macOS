import SwiftUI
import PDFKit
import UniformTypeIdentifiers

// Extension is placed OUTSIDE the ContentView struct
extension ContentView {
    func selectImages() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [.image]
        
        openPanel.begin { result in
            if result == .OK {
                for url in openPanel.urls {
                    if let image = NSImage(contentsOf: url) {
                        DispatchQueue.main.async {
                            self.images.append(image)
                        }
                    }
                }
            }
        }
    }
}

struct ContentView: View {
    @State private var images: [NSImage] = []
    @State private var showPicker = false
    @State private var draggingIndex: Int? = nil
    @State private var showPDFPicker = false
    @State private var selectedPDFs: [URL] = []
    @State private var isTargeted: Bool = false
    private let pdfManager = PDFManager()
    @State private var draggingPDFIndex: Int? = nil
    @State private var draggingImageIndex: Int? = nil
    
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
            if !selectedPDFs.isEmpty {
                VStack {
                    Text("Selected PDFs:")
                        .font(.headline)
                        .padding(.top)
                    
                    // Replace your PDF list in ContentView with this:
                    List {
                        ForEach(Array(selectedPDFs.enumerated()), id: \.element.path) { index, pdfURL in
                            HStack {
                                Text(pdfURL.lastPathComponent)
                                    .padding()
                            }
                            .background(draggingPDFIndex == index ? Color.gray.opacity(0.3) : Color.clear)
                            .contentShape(Rectangle())
                            .onDrag {
                                print("📄 Dragging PDF at index \(index)")
                                self.draggingPDFIndex = index
                                self.draggingIndex = index  // Keep this for compatibility with TrashArea
                                
                                let provider = NSItemProvider(object: "\(index)" as NSString)
                                provider.suggestedName = "pdf-\(index)"  // Add a hint that this is a PDF
                                return provider
                            }
                            .onDrop(of: [UTType.text.identifier], delegate: PDFDropDelegate(index: index, selectedPDFs: $selectedPDFs, draggingIndex: $draggingPDFIndex))
                        }
                    }
                    .frame(height: 150)
                    .padding()
                    .frame(height: 150)
                    .padding()
                }
            } else if !images.isEmpty {
                ForEach(Array(images.enumerated()), id: \.element) { index, image in
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .padding()
                        .background(draggingImageIndex == index ? Color.gray.opacity(0.3) : Color.clear)
                        .onDrag {
                            print("🖼️ Dragging image at index \(index)")
                            self.draggingImageIndex = index
                            self.draggingIndex = index  // Keep this for compatibility with TrashArea
                            
                            let provider = NSItemProvider(object: "\(index)" as NSString)
                            provider.suggestedName = "image-\(index)"  // Add a hint that this is an image
                            return provider
                        }
                        .onDrop(of: [UTType.text.identifier], delegate: DropViewDelegate(index: index, images: $images, draggingIndex: $draggingImageIndex))
                    
                }
            }
            
            Spacer()
            
            HStack {
                Button("Select Images") {
                    selectImages()
                }
                .padding()
                
                Button("Convert to PDF") {
                    guard !images.isEmpty else { return }
                    
                    if let pdf = pdfManager.createPDFFromImages(images: images) {
                        pdfManager.savePDF(pdf, defaultName: "ConvertedImages.pdf")
                    }
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
                    pdfManager.mergePDFs(pdfURLs: selectedPDFs)
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
                .padding(.bottom, 20)
        }
        .background(
            Text("Drop images or PDFs here")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Color.gray)
                .opacity(0.3)
                .padding()
        )
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
                        
                        let imageExtensions = ["jpg", "jpeg", "png", "tiff", "bmp", "gif", "heic"]
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
        
        //PDF file importer
        .fileImporter(isPresented: $showPDFPicker, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { result in
            DispatchQueue.main.async {
                do {
                    let urls = try result.get()
                    print("📂 Selected \(urls.count) PDFs")
                    
                    // Store PDF URLs with security scope bookmarks
                    for url in urls {
                        if url.startAccessingSecurityScopedResource() {
                            selectedPDFs.append(url)
                        } else {
                            print("⚠️ Failed to access security-scoped resource: \(url.path)")
                        }
                    }
                } catch {
                    print("❌ Failed to import PDFs: \(error.localizedDescription)")
                }
            }
        }
        .padding()
    }
    
    func stopAccessingAllPDFs() {
        for url in selectedPDFs {
            url.stopAccessingSecurityScopedResource()
        }
    }
    
    func movePDF(from source: IndexSet, to destination: Int) {
        selectedPDFs.move(fromOffsets: source, toOffset: destination)
    }
}
