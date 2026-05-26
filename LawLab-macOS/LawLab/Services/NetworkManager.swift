import Foundation

/// Enumeración de errores de red personalizados para un diagnóstico preciso.
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case serverUnreachable
    case decodingError
    case httpError(statusCode: Int)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "La URL de conexión no es válida."
        case .serverUnreachable:
            return "No se pudo conectar con el servidor. ¿Está el backend iniciado en http://localhost:8000?"
        case .decodingError:
            return "Error al decodificar la respuesta del servidor legal."
        case .httpError(let code):
            return "El servidor devolvió un error HTTP con código \(code)."
        case .unknown(let error):
            return "Ocurrió un error inesperado: \(error.localizedDescription)"
        }
    }
}

/// Cliente de red para consumir la API de LawLab de forma concurrente.
class NetworkManager {
    static let shared = NetworkManager()
    
    private var baseURL: String {
        let host = UserDefaults.standard.string(forKey: "backend_host") ?? "localhost"
        let port = UserDefaults.standard.string(forKey: "backend_port") ?? "8000"
        return "http://\(host):\(port)/api/v1"
    }
    private let session: URLSession
    private let chatSession: URLSession
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10.0
        configuration.timeoutIntervalForResource = 10.0
        self.session = URLSession(configuration: configuration)
        
        let chatConfig = URLSessionConfiguration.ephemeral
        chatConfig.timeoutIntervalForRequest = 600.0
        chatConfig.timeoutIntervalForResource = 600.0
        chatConfig.httpShouldUsePipelining = false
        self.chatSession = URLSession(configuration: chatConfig)
    }

    
    /// Prueba la salud de un host y puerto personalizados en caliente.
    func testConnection(host: String, port: String) async -> Bool {
        let testURL = "http://\(host):\(port)/api/v1/status"
        guard let url = URL(string: testURL) else { return false }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 600.0
        request.httpMethod = "GET"
        request.timeoutInterval = 2.0 // Short timeout for active pings
        
        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return true
            }
            return false
        } catch {
            return false
        }
    }
    
    /// Envía un mensaje de chat al backend de FastAPI y recupera la respuesta de IA fundamentada.
    func sendChatMessage(message: String, model: String = "llama3", useMoe: Bool = false) async throws -> ChatResponseDTO {
        guard let url = URL(string: "\(baseURL)/chat") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 600.0
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let dto = ChatRequestDTO(message: message, model: model, use_moe: useMoe)
        do {
            request.httpBody = try JSONEncoder().encode(dto)
        } catch {
            throw NetworkError.unknown(error)
        }
        
        do {
            let (data, response) = try await chatSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.serverUnreachable
            }
            
            guard httpResponse.statusCode == 200 else {
                throw NetworkError.httpError(statusCode: httpResponse.statusCode)
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(ChatResponseDTO.self, from: data)
            
        } catch let error as URLError {
            print("URLError: \(error)")
            throw NetworkError.serverUnreachable
        } catch let error as DecodingError {
            print("DecodingError: \(error)")
            throw NetworkError.decodingError
        } catch {
            throw NetworkError.unknown(error)
        }
    }
    
    /// Comprueba el estado de salud de todos los servicios locales.
    func checkServicesStatus() async -> ServiceStatusDTO {
        guard let url = URL(string: "\(baseURL)/status") else {
            return ServiceStatusDTO(status: "ERROR", backend_online: false, ollama_online: false, chromadb_online: false)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 600.0
        request.httpMethod = "GET"
        request.timeoutInterval = 3.0 // Quick ping timeout
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return ServiceStatusDTO(status: "ERROR", backend_online: false, ollama_online: false, chromadb_online: false)
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(ServiceStatusDTO.self, from: data)
        } catch {
            return ServiceStatusDTO(status: "ERROR", backend_online: false, ollama_online: false, chromadb_online: false)
        }
    }
    
    // MARK: - Local Ingestion & Multimodal Evidence endpoints
    
    /// Realiza una petición Multipart Form-Data POST para subir archivos al backend local.
    private func uploadMultipartFile(url: URL, toEndpoint endpoint: String, fileFieldName: String = "file", extraParams: [String: String] = [:]) async throws -> Data {
        guard let requestURL = URL(string: "\(baseURL)\(endpoint)") else {
            throw NetworkError.invalidURL
        }
        
        // Start accessing scoped resource for macOS security
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        let fileData: Data
        do {
            fileData = try Data(contentsOf: url)
        } catch {
            throw NetworkError.unknown(error)
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add extra text parameters
        for (key, value) in extraParams {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add file field
        let filename = url.lastPathComponent
        let mimeType = mimeType(for: url)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.serverUnreachable
            }
            
            guard httpResponse.statusCode == 200 else {
                throw NetworkError.httpError(statusCode: httpResponse.statusCode)
            }
            
            return data
        } catch let error as URLError {
            print("URLError during file upload: \(error)")
            throw NetworkError.serverUnreachable
        } catch {
            throw NetworkError.unknown(error)
        }
    }
    
    /// Helper to identify basic mime types for uploaded evidence
    private func mimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf": return "application/pdf"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "wav": return "audio/wav"
        case "mp3": return "audio/mpeg"
        case "m4a": return "audio/mp4"
        default: return "application/octet-stream"
        }
    }
    
    /// Sube un PDF legislativo para ingesta directa en caliente.
    func uploadPDF(fileURL: URL) async throws -> IngestResponseDTO {
        let data = try await uploadMultipartFile(url: fileURL, toEndpoint: "/evidence/pdf")
        return try JSONDecoder().decode(IngestResponseDTO.self, from: data)
    }
    
    /// Sube una captura/imagen de evidencia para análisis de visión y OCR pericial.
    func uploadVisionEvidence(fileURL: URL, model: String = "llama3.2-vision") async throws -> EvidenceResponseDTO {
        let data = try await uploadMultipartFile(url: fileURL, toEndpoint: "/evidence/vision", extraParams: ["model": model])
        return try JSONDecoder().decode(EvidenceResponseDTO.self, from: data)
    }
    
    /// Sube un archivo de audio de prueba para transcripción por Whisper e indexación pericial.
    func uploadAudioEvidence(fileURL: URL) async throws -> EvidenceResponseDTO {
        let data = try await uploadMultipartFile(url: fileURL, toEndpoint: "/evidence/audio")
        return try JSONDecoder().decode(EvidenceResponseDTO.self, from: data)
    }
    
    /// Elimina todas las evidencias vectoriales registradas del caso.
    func clearEvidence() async throws -> ClearEvidenceResponseDTO {
        guard let url = URL(string: "\(baseURL)/evidence/clear") else {
            throw NetworkError.invalidURL
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 600.0
        request.httpMethod = "POST"
        
        let (data, response) = try await chatSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.serverUnreachable
        }
        
        return try JSONDecoder().decode(ClearEvidenceResponseDTO.self, from: data)
    }
    
    /// Genera la estrategia legal y borrador de demanda de forma autónoma.
    func generateAutonomousDraft(model: String = "qwen2.5:7b-instruct") async throws -> AutonomousDraftResponseDTO {
        guard let url = URL(string: "\(baseURL)/autonomous-draft") else {
            throw NetworkError.invalidURL
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 600.0
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let dto = AutonomousDraftRequestDTO(model: model)
        request.httpBody = try JSONEncoder().encode(dto)
        
        let (data, response) = try await chatSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.serverUnreachable
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(AutonomousDraftResponseDTO.self, from: data)
    }

    func generateTimeline() async throws -> TimelineResponseDTO {
        guard let url = URL(string: baseURL + "/analysis/timeline") else {
            throw NSError(domain: "Invalid URL", code: 400, userInfo: nil)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 600.0
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // El body puede ir vacío o solo con el modelo
        let body = ["model": "llama3.2"] // Por defecto
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await self.chatSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "No HTTP Response", code: 500, userInfo: nil)
        }
        
        if httpResponse.statusCode != 200 {
            throw NSError(domain: "Server Error", code: httpResponse.statusCode, userInfo: nil)
        }
        
        return try JSONDecoder().decode(TimelineResponseDTO.self, from: data)
    }
    
    /// Envía un mensaje y recibe una respuesta en streaming (SSE).
    func sendChatStream(prompt: String, model: String = "llama3", useMoe: Bool = false) async throws -> AsyncThrowingStream<String, Error> {
        guard let url = URL(string: "\(baseURL)/chat") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 600.0 // Allow long connection
        
        var bodyData: [String: Any] = [
            "message": prompt,
            "model": model,
            "stream": true,
            "use_moe": useMoe
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: bodyData)
        
        let (result, response) = try await chatSession.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.serverUnreachable
        }
        
        if httpResponse.statusCode != 200 {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in result.lines {
                        if line.hasPrefix("data: ") {
                            let content = String(line.dropFirst(6))
                            if content == "[DONE]" {
                                continuation.finish()
                                return
                            }
                            if let data = content.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let chunkText = json["content"] as? String {
                                continuation.yield(chunkText)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func generateDraft(request: GenerateDocumentRequest) async throws -> DocumentResponseDTO {
        guard let url = URL(string: baseURL + "/drafting/draft") else {
            throw NSError(domain: "Invalid URL", code: 400, userInfo: nil)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.timeoutInterval = 600.0
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await self.chatSession.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "No HTTP Response", code: 500, userInfo: nil)
        }
        
        if httpResponse.statusCode != 200 {
            throw NSError(domain: "Server Error", code: httpResponse.statusCode, userInfo: nil)
        }
        
        return try JSONDecoder().decode(DocumentResponseDTO.self, from: data)
    }

    func runDespidoPipeline(fileURL: URL) async throws -> PipelineResponseDTO {
        let data = try await uploadMultipartFile(url: fileURL, toEndpoint: "/pipeline/despido")
        return try JSONDecoder().decode(PipelineResponseDTO.self, from: data)
    }
}
