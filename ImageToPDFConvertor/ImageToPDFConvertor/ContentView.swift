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
                            .frame(width: 800, height: 600)
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
            }
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            for provider in providers {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (data, error) in
                    if let data = data as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        DispatchQueue.main.async {
                            if url.startAccessingSecurityScopedResource() {
                                if let image = NSImage(contentsOf: url) {
                                    images.append(image)  // ✅ Append image to list
                                }
                                url.stopAccessingSecurityScopedResource()
                            }
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
