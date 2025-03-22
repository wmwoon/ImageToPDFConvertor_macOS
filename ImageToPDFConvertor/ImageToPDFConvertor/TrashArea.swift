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
            .onDrop(of: [UTType.text.identifier], isTargeted: nil) { providers in
                print("📥 Received drop with \(providers.count) providers")
                
                // Check if draggingIndex is set directly
                if let index = draggingIndex {
                    print("🔍 Using draggingIndex directly: \(index)")
                    
                    DispatchQueue.main.async {
                        // Check if we're dealing with PDF list
                        if !selectedPDFs.isEmpty && index < selectedPDFs.count {
                            print("🗑️ Deleting PDF at index: \(index), filename: \(selectedPDFs[index].lastPathComponent)")
                            selectedPDFs.remove(at: index)
                        }
                        // Check if we're dealing with image list
                        else if !images.isEmpty && index < images.count {
                            print("🗑️ Deleting image at index: \(index)")
                            images.remove(at: index)
                        } else {
                            print("⚠️ Index \(index) out of bounds for both PDFs and images")
                        }
                        
                        self.draggingIndex = nil
                    }
                    return true
                }
                
                // Fallback to provider-based approach
                for (i, provider) in providers.enumerated() {
                    print("📦 Processing provider \(i+1)")
                    
                    provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { (data, error) in
                        if let error = error {
                            print("❌ Error loading data: \(error.localizedDescription)")
                            return
                        }
                        
                        print("📋 Received data type: \(type(of: data))")
                        
                        if let nsString = data as? NSString {
                            let indexString = nsString as String
                            print("📝 String value: \(indexString)")
                            
                            if let index = Int(indexString) {
                                print("🔢 Converted to index: \(index)")
                                
                                DispatchQueue.main.async {
                                    if !selectedPDFs.isEmpty && index < selectedPDFs.count {
                                        print("🗑️ Deleting PDF at index: \(index)")
                                        selectedPDFs.remove(at: index)
                                    } else if !images.isEmpty && index < images.count {
                                        print("🗑️ Deleting image at index: \(index)")
                                        images.remove(at: index)
                                    } else {
                                        print("⚠️ Index \(index) out of bounds")
                                    }
                                }
                            } else {
                                print("⚠️ Failed to convert string \"\(indexString)\" to Int")
                            }
                        } else {
                            print("⚠️ Data is not an NSString: \(String(describing: data))")
                        }
                    }
                }
                
                return true
            }
    }
}
