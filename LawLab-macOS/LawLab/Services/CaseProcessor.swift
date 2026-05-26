import Foundation
import PDFKit
import Vision
import AppKit

/// CaseProcessor scans a local directory recursively, detects evidence files,
/// extracts their text contents (via direct PDF text extraction, Vision OCR, or Whisper transcription APIs),
/// and aggregates them into the main context of ChatViewModel.
actor CaseProcessor {
    static let shared = CaseProcessor()
    private init() {}
    
    // Allowed extensions for evidence files
    private let allowedExtensions = Set(["pdf", "png", "jpg", "jpeg", "mp3", "wav", "m4a"])
    
    /// Recursively scan folder, upload files to vector store and register them in uploadedEvidence.
    func process(folder: URL, viewModel: ChatViewModel) async {
        let fileManager = FileManager.default
        var scannedFilesCount = 0
        var errorsCount = 0
        var failedFiles: [(filename: String, reason: String)] = []
        
        let keys: [URLResourceKey] = [.isRegularFileKey, .localizedNameKey]
        let enumerator = fileManager.enumerator(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles],
            errorHandler: { (url, error) -> Bool in
                print("⚠️ [CaseProcessor] Error enumerating \(url): \(error)")
                return true
            }
        )
        
        guard let fileEnumerator = enumerator else {
            await MainActor.run {
                viewModel.appendSystemMessage("❌ **Error al acceder a la carpeta.** No se pudo inicializar el escaneo de directorios.")
            }
            return
        }
        
        // 1. Clear previous workspace evidence from ChromaDB to ensure a clean RAG session
        await MainActor.run {
            viewModel.ingestionStatus = "Vaciando evidencias previas en ChromaDB..."
            viewModel.uploadedEvidence.removeAll()
            viewModel.caseContext = ""
        }
        _ = try? await NetworkManager.shared.clearEvidence()
        
        // 2. Scan and upload files
        for case let fileURL as URL in fileEnumerator {
            let ext = fileURL.pathExtension.lowercased()
            guard allowedExtensions.contains(ext) else { continue }
            
            scannedFilesCount += 1
            let filename = fileURL.lastPathComponent
            print("📁 [CaseProcessor] Vectorizing evidence file: \(filename)")
            
            await MainActor.run {
                viewModel.ingestionStatus = "Vectorizando: \(filename)..."
            }
            
            do {
                switch ext {
                case "pdf":
                    let response = try await NetworkManager.shared.uploadPDF(fileURL: fileURL)
                    if response.status == "EMPTY" {
                        errorsCount += 1
                        failedFiles.append((filename: filename, reason: "El PDF es un documento escaneado (imagen) sin texto digital indexable directo. Por favor, realiza una captura del archivo y súbela como imagen (PNG/JPG) para que sea procesada mediante OCR con el motor de visión."))
                    } else {
                        await MainActor.run {
                            let newItem = EvidenceItem(
                                id: UUID(),
                                name: filename,
                                type: .pdf,
                                summary: "Indexados \(response.chunks_indexed) fragmentos vectoriales."
                            )
                            viewModel.uploadedEvidence.append(newItem)
                        }
                    }
                case "png", "jpg", "jpeg":
                    let response = try await NetworkManager.shared.uploadVisionEvidence(fileURL: fileURL, model: "llama3.2-vision")
                    await MainActor.run {
                        let newItem = EvidenceItem(
                            id: UUID(),
                            name: filename,
                            type: .image,
                            summary: "Análisis pericial OCR y visual completado."
                        )
                        viewModel.uploadedEvidence.append(newItem)
                    }
                case "mp3", "wav", "m4a":
                    let response = try await NetworkManager.shared.uploadAudioEvidence(fileURL: fileURL)
                    await MainActor.run {
                        let newItem = EvidenceItem(
                            id: UUID(),
                            name: filename,
                            type: .audio,
                            summary: "Transcripción de Whisper offline completada."
                        )
                        viewModel.uploadedEvidence.append(newItem)
                    }
                default:
                    break
                }
            } catch {
                errorsCount += 1
                let reason = error.localizedDescription
                failedFiles.append((filename: filename, reason: reason))
                print("❌ [CaseProcessor] Error vectorizing \(filename): \(reason)")
            }
        }
        
        let finalScannedCount = scannedFilesCount
        let finalErrorsCount = errorsCount
        let finalFailedFiles = failedFiles
        
        await MainActor.run {
            viewModel.ingestionStatus = nil
            
            if finalScannedCount == 0 {
                viewModel.appendSystemMessage("📁 **Escaneo finalizado.**\nNo se encontraron archivos de evidencia válidos (`.pdf`, `.png`, `.jpg`, `.mp3`, `.wav`, `.m4a`) en la carpeta seleccionada.")
            } else {
                var message = "✅ **Indexación Vectorial de Carpeta Completada.**\nSe procesaron e indexaron **\(finalScannedCount - finalErrorsCount)/\(finalScannedCount)** archivo(s) de evidencia en la base de datos vectorial local (ChromaDB).\n\nEl sistema RAG consultará semánticamente estos archivos en tiempo real para fundamentar el caso en el chat."
                
                if !finalFailedFiles.isEmpty {
                    message += "\n\n⚠️ **Detalle de Archivos no Indexados/Fallidos:**"
                    for failed in finalFailedFiles {
                        message += "\n• **\(failed.filename)**:\n  *Razón:* \(failed.reason)"
                    }
                }
                viewModel.appendSystemMessage(message)
            }
        }
    }
    
    // --- DIRECT LOCAL HELPER: PDF TEXT EXTRACTION (using PDFKit) ---
    private func extractPDFText(from url: URL) -> String? {
        guard let document = PDFDocument(url: url) else { return nil }
        var fullText = ""
        for i in 0..<document.pageCount {
            if let page = document.page(at: i), let text = page.string {
                fullText += text + "\n"
            }
        }
        return fullText.isEmpty ? nil : fullText
    }
    
    // --- DIRECT LOCAL HELPER: APPLE VISION OCR (for lightning‑fast, offline macOS OCR) ---
    private func performOCRVision(on url: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            guard let image = NSImage(contentsOf: url),
                  let tiffData = image.tiffRepresentation,
                  let cgImageSource = CGImageSourceCreateWithData(tiffData as CFData, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(cgImageSource, 0, nil) else {
                continuation.resume(throwing: NSError(domain: "OCRVisionError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No se pudo leer la imagen local o convertirla a CGImage."]))
                return
            }
            
            let request = VNRecognizeTextRequest { (request, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                continuation.resume(returning: recognizedStrings.joined(separator: "\n"))
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // --- BACKEND HELPER: AUDIO TRANSCRIPTION VIA OLLAMA / WHISPER BACKEND ---
    private func transcribeAudioViaBackend(fileURL: URL) async throws -> String {
        let response = try await NetworkManager.shared.uploadAudioEvidence(fileURL: fileURL)
        var result = ""
        if let transcription = response.transcription {
            result += "Transcripción:\n\(transcription)\n\n"
        }
        result += "Análisis de Hechos Laborales:\n\(response.analysis)"
        return result
    }
}
