import PDFKit

class PDFManager {
    static let shared = PDFManager() // Singleton instance (optional)

    private init() {} // Prevents external instantiation

    func mergePDFs(pdfURLs: [URL]) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = "MergedDocument.pdf"
        savePanel.prompt = "Save Merged PDF"
        
        if savePanel.runModal() == .OK, let outputURL = savePanel.url {
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
    }
}
