import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers

struct EvidenceItem: Identifiable, Codable {
    let id: UUID
    let name: String
    let type: EvidenceType
    let summary: String
    
    enum EvidenceType: String, Codable {
        case pdf = "pdf"
        case image = "image"
        case audio = "audio"
    }
}

@MainActor
class ChatViewModel: ObservableObject {
    // Chat UI States
    @Published var messages: [Message] = []
    @Published var inputMessage: String = ""
    @Published var selectedModel: String = "qwen2.5:7b-instruct"
    @Published var isGenerating: Bool = false
    @Published var errorMessage: String? = nil
    
    // Services Health Nodes States
    @Published var backendOnline: Bool = false
    @Published var ollamaOnline: Bool = false
    @Published var chromaOnline: Bool = false
    
    // Document Upload / Ingestion States
    @Published var attachedPDFName: String? = nil
    @Published var attachedPDFURL: URL? = nil
    @Published var ingestionStatus: String? = nil
    
    // Multimodal Evidence & Autonomous Ingestion States
    @Published var uploadedEvidence: [EvidenceItem] = []
    @Published var draftedLawsuit: String? = nil
    
    // Customized Connection & Theme & Lawyer Profile Settings
    @Published var backendHost: String = "localhost"
    @Published var backendPort: String = "8000"
    @Published var useMoe: Bool = false
    @Published var activeTheme: AppTheme = .cyberpunk
    @Published var lawyerName: String = ""
    @Published var lawyerId: String = ""
    @Published var lawyerCity: String = ""
    @Published var injectSignature: Bool = false
    @Published var fontScale: CGFloat = 1.0 // Scaling factor for UI font sizes
    @Published var followSystemAppearance: Bool = true // Follow macOS system appearance
    @Published var caseFolderURL: URL? {
        didSet { saveCaseFolder() }
    }
    @Published var caseContext: String = "" // Texto concatenado de todas las evidencias del caso
    
    @Published var connectionTestResult: String? = nil
    @Published var isTestingConnection: Bool = false
    
    // Status polling task
    private var statusTask: Task<Void, Never>? = nil
    
    init() {
        // Load custom settings
        self.backendHost = UserDefaults.standard.string(forKey: "backend_host") ?? "localhost"
        self.backendPort = UserDefaults.standard.string(forKey: "backend_port") ?? "8000"
        self.lawyerName = UserDefaults.standard.string(forKey: "lawyer_name") ?? ""
        self.lawyerId = UserDefaults.standard.string(forKey: "lawyer_id") ?? ""
        self.lawyerCity = UserDefaults.standard.string(forKey: "lawyer_city") ?? ""
        self.injectSignature = UserDefaults.standard.bool(forKey: "inject_signature")
        self.fontScale = CGFloat(UserDefaults.standard.double(forKey: "font_scale") == 0 ? 1.0 : UserDefaults.standard.double(forKey: "font_scale"))
        self.followSystemAppearance = UserDefaults.standard.bool(forKey: "follow_system_appearance")
        if let themeStr = UserDefaults.standard.string(forKey: "app_theme"),
           let theme = AppTheme(rawValue: themeStr) {
            self.activeTheme = theme
        }
        
        loadCaseFolderFromDefaults()
        
        // Initial greetings representing the senior legal persona
        appendSystemGreeting()
        
        // Start polling services health every 4 seconds
        startServiceStatusPolling()
    }
    
    // --- NUEVOS MÉTODOS PARA CARPETA DE CASO ---
    
    private func saveCaseFolder() {
        if let url = caseFolderURL {
            UserDefaults.standard.set(url.path, forKey: "caseFolderPath")
        } else {
            UserDefaults.standard.removeObject(forKey: "caseFolderPath")
        }
    }
    
    private func loadCaseFolderFromDefaults() {
        if let path = UserDefaults.standard.string(forKey: "caseFolderPath") {
            self.caseFolderURL = URL(fileURLWithPath: path)
        }
    }
    
    func pickCaseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Selecciona la carpeta del caso"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            self.caseFolderURL = url
            self.processCaseFolder()
        }
    }
    
    func processCaseFolder() {
        guard let folder = caseFolderURL else { return }
        self.appendSystemMessage("📁 **Escaneando carpeta del caso...**\n`\(folder.lastPathComponent)`")
        
        Task {
            await CaseProcessor.shared.process(folder: folder, viewModel: self)
        }
    }
    
    func appendSystemMessage(_ text: String) {
        let msg = Message(role: .assistant, content: text)
        withAnimation {
            messages.append(msg)
        }
    }
    
    deinit {
        statusTask?.cancel()
    }
    
    /// Guarda los ajustes modificados de forma persistente en UserDefaults.
    func saveSettings() {
        UserDefaults.standard.set(backendHost, forKey: "backend_host")
        UserDefaults.standard.set(backendPort, forKey: "backend_port")
        UserDefaults.standard.set(lawyerName, forKey: "lawyer_name")
        UserDefaults.standard.set(lawyerId, forKey: "lawyer_id")
        UserDefaults.standard.set(lawyerCity, forKey: "lawyer_city")
        UserDefaults.standard.set(injectSignature, forKey: "inject_signature")
        UserDefaults.standard.set(activeTheme.rawValue, forKey: "app_theme")
        UserDefaults.standard.set(Double(fontScale), forKey: "font_scale")
        UserDefaults.standard.set(followSystemAppearance, forKey: "follow_system_appearance")
        
        // Trigger status check immediately to reflect settings change
        Task {
            await checkServicesStatus()
        }
    }
    
    /// Prueba la conexión en caliente con un host y puerto dados de forma asíncrona.
    func testCustomConnection(host: String, port: String) {
        isTestingConnection = true
        connectionTestResult = "Realizando ping al nodo..."
        
        Task {
            let success = await NetworkManager.shared.testConnection(host: host, port: port)
            if success {
                self.connectionTestResult = "✅ Conexión con éxito."
            } else {
                self.connectionTestResult = "❌ Error: Nodo inalcanzable."
            }
            self.isTestingConnection = false
        }
    }
    
    private func appendSystemGreeting() {
        let greeting = Message(
            role: .assistant,
            content: "⚖️ **LawLab Iniciado**\n\nSaludos. Soy tu Abogado Laboralista Senior en España. " +
                     "Estoy capacitado para redactar demandas, calcular plazos procesales " +
                     "y analizar la viabilidad legal de despidos o reclamaciones de cantidad.\n\n" +
                     "¿En qué asunto legal puedo asistirte hoy?"
        )
        messages.append(greeting)
    }
    
    /// Limpia el historial de chat pero conserva la carpeta del caso activa.
    func clearChat() {
        withAnimation {
            messages.removeAll()
            appendSystemGreeting()
        }
    }
    
    /// Comprueba la salud del backend y de Ollama, actualizando el estado de los nodos visuales.
    func checkServicesStatus() async {
        let status = await NetworkManager.shared.checkServicesStatus()
        self.backendOnline = status.backend_online
        self.ollamaOnline = status.ollama_online
        self.chromaOnline = status.chromadb_online
    }
    
    /// Inicia un bucle periódico en segundo plano para actualizar el estado del Nodo.
    private func startServiceStatusPolling() {
        statusTask = Task {
            while !Task.isCancelled {
                await checkServicesStatus()
                try? await Task.sleep(nanoseconds: 4_000_000_000) // Sleep 4 seconds
            }
        }
    }
    
    /// Envía la instrucción actual del usuario al backend de FastAPI.
    func sendMessage() async {
        let query = inputMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        // Clean input field
        self.inputMessage = ""
        self.errorMessage = nil
        
        // Append user message
        let userMessage = Message(role: .user, content: query)
        messages.append(userMessage)
        
        // Trigger loading state
        isGenerating = true
        
        // Contextually inject all folder evidence if available
        var finalQuery = query
        if !caseContext.isEmpty {
            finalQuery = """
[EVIDENCIAS DEL CASO INTEGRADAS]
A continuación se detalla el contenido extraído de la carpeta del caso seleccionada por el usuario. Utilízala como base principal de hechos y pruebas:

\(caseContext)

[CONSULTA DEL USUARIO]
\(query)
"""
        }
        
        do {
            let streamId = UUID()
            messages.append(Message(id: streamId, role: .assistant, content: ""))
            
            for try await chunk in try await NetworkManager.shared.sendChatStream(
                prompt: finalQuery,
                model: selectedModel,
                useMoe: useMoe
            ) {
                if let index = messages.firstIndex(where: { $0.id == streamId }) {
                    messages[index].content += chunk
                }
            }
        } catch {
            self.errorMessage = "Error de red: \(error.localizedDescription)"
        }
        
        isGenerating = false
    }
    
    /// Abre un panel nativo de macOS para seleccionar y subir un archivo (PDF, Imagen o Audio).
    func attachFile(type: EvidenceItem.EvidenceType) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        switch type {
        case .pdf:
            panel.allowedContentTypes = [.pdf]
            panel.title = "Seleccionar Legislación (PDF)"
            panel.message = "Selecciona un documento PDF de ley laboral para indexar en la base de datos local."
        case .image:
            panel.allowedContentTypes = [.png, .jpeg]
            panel.title = "Seleccionar Imagen (Prueba)"
            panel.message = "Selecciona una captura de pantalla o foto para procesar como prueba."
        case .audio:
            panel.allowedContentTypes = [.mp3, .wav, UTType(filenameExtension: "m4a")!].compactMap { $0 }
            panel.title = "Seleccionar Grabación (Audio)"
            panel.message = "Selecciona un archivo de audio para transcribir y analizar."
        }
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                uploadEvidenceFile(url: url, type: type)
            }
        }
    }
    
    /// Sube el archivo seleccionado de forma asíncrona y gestiona los estados de la interfaz.
    private func uploadEvidenceFile(url: URL, type: EvidenceItem.EvidenceType) {
        isGenerating = true
        errorMessage = nil
        ingestionStatus = "Subiendo y procesando archivo \(url.lastPathComponent)..."
        
        Task {
            do {
                switch type {
                case .pdf:
                    let response = try await NetworkManager.shared.uploadPDF(fileURL: url)
                    ingestionStatus = "Ley indexada con éxito: \(response.chunks_indexed) fragmentos."
                    let newItem = EvidenceItem(id: UUID(), name: url.lastPathComponent, type: .pdf, summary: "Indexados \(response.chunks_indexed) fragmentos.")
                    uploadedEvidence.append(newItem)
                    
                    let systemMsg = Message(
                        role: .assistant,
                        content: "📁 **Ingesta Legislativa Completada**\n\nEl documento `\(response.filename)` ha sido fragmentado e indexado en **ChromaDB**.\n* **Fragmentos generados**: \(response.chunks_indexed) bloques vectoriales.\n\nAhora la IA tiene este marco legal en su contexto RAG para responder consultas."
                    )
                    withAnimation {
                        messages.append(systemMsg)
                    }
                    
                case .image:
                    let response = try await NetworkManager.shared.uploadVisionEvidence(fileURL: url, model: "llama3.2-vision")
                    ingestionStatus = "Evidencia visual analizada con éxito."
                    let newItem = EvidenceItem(id: UUID(), name: url.lastPathComponent, type: .image, summary: "OCR y análisis pericial visual.")
                    uploadedEvidence.append(newItem)
                    
                    let systemMsg = Message(
                        role: .assistant,
                        content: "📸 **Análisis de Evidencia Visual Completado**\n\nSe ha procesado `\(response.filename)` con el modelo local `\(response.model_used ?? "llama3.2-vision")`:\n\n\(response.analysis)"
                    )
                    withAnimation {
                        messages.append(systemMsg)
                    }
                    
                case .audio:
                    let response = try await NetworkManager.shared.uploadAudioEvidence(fileURL: url)
                    ingestionStatus = "Audio transcrito con éxito."
                    let newItem = EvidenceItem(id: UUID(), name: url.lastPathComponent, type: .audio, summary: "Transcripción de Whisper offline.")
                    uploadedEvidence.append(newItem)
                    
                    let systemMsg = Message(
                        role: .assistant,
                        content: "🎙️ **Evidencia de Grabación Procesada**\n\nEl audio `\(response.filename)` ha sido transcrito localmente usando **Whisper offline**.\n\n" +
                                 "**--- TRANSCRIPCIÓN DETECTADA ---**\n*\"\(response.transcription ?? "")\"*\n\n" +
                                 "**--- ANÁLISIS DE HECHOS LABORALES ---**\n\(response.analysis)"
                    )
                    withAnimation {
                        messages.append(systemMsg)
                    }
                }
            } catch {
                self.errorMessage = error.localizedDescription
                self.ingestionStatus = "Error al procesar archivo."
                
                let errorAlert = Message(
                    role: .assistant,
                    content: "⚠️ **FALLO DE PROCESAMIENTO LOCAL**\nNo se pudo cargar o analizar la evidencia local.\n\n*Detalles del error:* \(error.localizedDescription)\n\n*(Si es audio, asegúrate de tener FFmpeg instalado. Si es imagen, asegúrate de haber ejecutado 'ollama pull llama3.2-vision' en tu terminal)*"
                )
                withAnimation {
                    messages.append(errorAlert)
                }
            }
            isGenerating = false
        }
    }
    
    /// Elimina todas las evidencias vectoriales registradas, limpiando el caso.
    func clearEvidence() {
        isGenerating = true
        errorMessage = nil
        ingestionStatus = "Vaciando evidencias..."
        
        Task {
            do {
                let response = try await NetworkManager.shared.clearEvidence()
                ingestionStatus = response.message
                uploadedEvidence.removeAll()
                draftedLawsuit = nil
                
                let systemMsg = Message(
                    role: .assistant,
                    content: "🗑️ **Expediente de Caso Limpiado**\n\nSe han eliminado de forma definitiva **\(response.deleted_count)** fragmentos de evidencias de la base de datos de ChromaDB.\n\nEl nodo está listo para recibir un caso laboral nuevo desde cero."
                )
                withAnimation {
                    messages.append(systemMsg)
                }
            } catch {
                self.errorMessage = error.localizedDescription
                self.ingestionStatus = "Error al vaciar evidencias."
            }
            isGenerating = false
        }
    }
    
    /// Ejecuta el Asistente Jurídico Autónomo para redactar la demanda basándose en las pruebas indexadas.
    func generateAutonomousDraft() {
        guard !uploadedEvidence.isEmpty else {
            errorMessage = "No hay evidencias en el caso. Carga primero alguna prueba para poder redactar la demanda."
            return
        }
        
        isGenerating = true
        errorMessage = nil
        ingestionStatus = "Analizando plazos y redactando demanda de forma autónoma..."
        
        Task {
            do {
                let response = try await NetworkManager.shared.generateAutonomousDraft(model: selectedModel)
                
                var finalDraft = response.draft
                if self.injectSignature && !self.lawyerName.isEmpty {
                    let signatureBlock = "\n\n---\n\n**Firma del Letrado:**\n\nEn su virtud, **AL JUZGADO DE LO SOCIAL** que por turno corresponda, formulo la presente demanda.\n\nFdo: *\(self.lawyerName)*  \nColegiado Nº *\(self.lawyerId)*  \nIlustre Colegio de Abogados de *\(self.lawyerCity)*"
                    finalDraft += signatureBlock
                }
                
                self.draftedLawsuit = finalDraft
                ingestionStatus = "Demanda redactada autónomamente."
                
                let strategyMsg = Message(
                    role: .assistant,
                    content: "\(response.analysis)\n\n---\n\n\(finalDraft)",
                    duration: response.duration
                )
                withAnimation {
                    messages.append(strategyMsg)
                }
            } catch {
                self.errorMessage = error.localizedDescription
                self.ingestionStatus = "Error al redactar demanda."
                
                let errorAlert = Message(
                    role: .assistant,
                    content: "⚠️ **ERROR EN REDACCIÓN AUTÓNOMA**\nEl motor no pudo compilar las pruebas. Verifica que tengas evidencias subidas correctamente.\n\n*Detalle del error:* \(error.localizedDescription)"
                )
                withAnimation {
                    messages.append(errorAlert)
                }
            }
            isGenerating = false
        }
    }
}
