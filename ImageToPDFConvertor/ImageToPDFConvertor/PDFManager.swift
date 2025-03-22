import PDFKit
import AppKit

class PDFManager {
    static let shared = PDFManager() // Singleton instance for app-wide access
    
    // Allow instantiation if needed for specific cases
    init() {}
    
    func mergePDFs(pdfURLs: [URL]) {
        guard !pdfURLs.isEmpty else {
            print("⚠️ No PDFs to merge")
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = "MergedDocument.pdf"
        savePanel.prompt = "Save Merged PDF"
        
        if savePanel.runModal() == .OK, let outputURL = savePanel.url {
            let mergedPDF = PDFDocument()
            
            for pdfURL in pdfURLs {
                if pdfURL.startAccessingSecurityScopedResource() {
                    defer { pdfURL.stopAccessingSecurityScopedResource() }
                    
                    if let pdfDocument = PDFDocument(url: pdfURL) {
                        for pageIndex in 0..<pdfDocument.pageCount {
                            if let page = pdfDocument.page(at: pageIndex) {
                                mergedPDF.insert(page, at: mergedPDF.pageCount)
                            }
                        }
                    } else {
                        print("❌ Failed to load PDF: \(pdfURL.path)")
                    }
                } else {
                    print("⚠️ Access to PDF denied: \(pdfURL.path)")
                }
            }
            
            if mergedPDF.pageCount > 0 {
                if mergedPDF.write(to: outputURL) {
                    print("✅ Merged PDF saved to: \(outputURL.path)")
                } else {
                    print("❌ Failed to save merged PDF")
                }
            } else {
                print("⚠️ No pages found to merge!")
            }
        }
    }
    
    // Add function to convert images to PDF
    func createPDFFromImages(images: [NSImage]) -> PDFDocument? {
        guard !images.isEmpty else {
            print("⚠️ No images to convert")
            return nil
        }
        
        let pdf = PDFDocument()
        
        for (index, image) in images.enumerated() {
            if let pdfPage = PDFPage(image: image) {
                pdf.insert(pdfPage, at: index)
            }
        }
        
        return pdf.pageCount > 0 ? pdf : nil
    }
    
    // Function to save a PDF document
    func savePDF(_ pdf: PDFDocument, defaultName: String = "Document.pdf") {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = defaultName
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            if pdf.write(to: url) {
                print("✅ PDF saved to: \(url.path)")
            } else {
                print("❌ Failed to save PDF")
            }
        }
    }
}
