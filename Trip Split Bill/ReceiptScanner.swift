//
//  ReceiptScanner.swift
//  Trip Split Bill
//
//  Created by Kelvin on 08/08/25.
//

import SwiftUI
import UIKit
import Vision
import VisionKit

// MARK: - Receipt Scanner
struct ReceiptScannerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onScanComplete: (ReceiptData) -> Void
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = context.coordinator
        return scannerViewController
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: ReceiptScannerView
        
        init(_ parent: ReceiptScannerView) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // Process the scanned document
            guard scan.pageCount > 0 else {
                parent.isPresented = false
                return
            }
            
            let image = scan.imageOfPage(at: 0)
            processReceiptImage(image) { receiptData in
                DispatchQueue.main.async {
                    self.parent.onScanComplete(receiptData)
                    self.parent.isPresented = false
                }
            }
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Document camera failed with error: \(error)")
            parent.isPresented = false
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.isPresented = false
        }
        
        private func processReceiptImage(_ image: UIImage, completion: @escaping (ReceiptData) -> Void) {
            guard let cgImage = image.cgImage else {
                completion(ReceiptData(image: image))
                return
            }
            
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    completion(ReceiptData(image: image))
                    return
                }
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                let receiptData = self.parseReceiptText(recognizedText, image: image)
                completion(receiptData)
            }
            
            request.recognitionLevel = .accurate
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
        
        private func parseReceiptText(_ text: String, image: UIImage) -> ReceiptData {
            var receiptData = ReceiptData(image: image)
            
            let lines = text.components(separatedBy: .newlines)
            
            // Extract total amount (look for patterns like "Total: 150000" or "TOTAL 150.000")
            for line in lines {
                let cleanLine = line.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                
                if cleanLine.contains("TOTAL") || cleanLine.contains("JUMLAH") {
                    let numbers = extractNumbers(from: cleanLine)
                    if let amount = numbers.first, amount > 1000 { // Minimum reasonable amount
                        receiptData.totalAmount = amount
                    }
                }
                
                // Extract merchant name (usually first few lines)
                if receiptData.merchantName.isEmpty && !cleanLine.isEmpty &&
                   !cleanLine.contains("RECEIPT") &&
                   !cleanLine.contains("STRUK") &&
                   !isDateLine(cleanLine) &&
                   !containsOnlyNumbers(cleanLine) {
                    receiptData.merchantName = line.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            // Extract items (lines with price patterns)
            receiptData.items = extractItems(from: lines)
            
            return receiptData
        }
        
        private func extractNumbers(from text: String) -> [Double] {
            let pattern = #"(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})?)"#
            let regex = try? NSRegularExpression(pattern: pattern)
            let matches = regex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
            
            return matches.compactMap { match in
                let range = Range(match.range, in: text)!
                let numberString = String(text[range])
                    .replacingOccurrences(of: ".", with: "")
                    .replacingOccurrences(of: ",", with: "")
                return Double(numberString)
            }
        }
        
        private func extractItems(from lines: [String]) -> [ReceiptItem] {
            var items: [ReceiptItem] = []
            
            for line in lines {
                let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                let numbers = extractNumbers(from: cleanLine)
                
                // If line has a number that could be a price
                if let price = numbers.first, price > 500, price < 1_000_000 {
                    let itemName = cleanLine.replacingOccurrences(of: String(format: "%.0f", price), with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
                    
                    if !itemName.isEmpty && itemName.count > 2 {
                        items.append(ReceiptItem(name: itemName, price: price))
                    }
                }
            }
            
            return items
        }
        
        private func isDateLine(_ text: String) -> Bool {
            return text.contains("/") && (text.contains("2024") || text.contains("2025"))
        }
        
        private func containsOnlyNumbers(_ text: String) -> Bool {
            return text.allSatisfy { $0.isNumber || $0 == "." || $0 == "," || $0 == " " }
        }
    }
}

// MARK: - Receipt Data Models
struct ReceiptData {
    var image: UIImage
    var totalAmount: Double = 0
    var merchantName: String = ""
    var items: [ReceiptItem] = []
    var date: Date = Date()
}

struct ReceiptItem {
    var name: String
    var price: Double
}

// MARK: - Image Picker for Manual Photo Selection
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @Binding var selectedImage: UIImage?
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.isPresented = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}
