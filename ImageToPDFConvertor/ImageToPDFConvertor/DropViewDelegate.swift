import SwiftUI

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

struct PDFDropDelegate: DropDelegate {
    let index: Int
    @Binding var selectedPDFs: [URL]
    @Binding var draggingIndex: Int?

    func performDrop(info: DropInfo) -> Bool {
        guard let draggingIndex = draggingIndex, draggingIndex != index else { return false }
        
        let movedPDF = selectedPDFs.remove(at: draggingIndex)
        selectedPDFs.insert(movedPDF, at: index)

        DispatchQueue.main.async { self.draggingIndex = nil }
        return true
    }

    func dropEntered(info: DropInfo) {
        if let draggingIndex = draggingIndex, draggingIndex != index {
            let movedPDF = selectedPDFs.remove(at: draggingIndex)
            selectedPDFs.insert(movedPDF, at: index)
            self.draggingIndex = index
        }
    }
}
