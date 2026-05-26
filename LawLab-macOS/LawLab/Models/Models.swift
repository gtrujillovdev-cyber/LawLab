import Foundation

/// Representa un mensaje individual dentro de la sesión de chat legal.
struct Message: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    let contextUsed: [String]?
    let duration: Double?
    
    enum MessageRole: String, Codable {
        case user = "user"
        case assistant = "assistant"
    }
    
    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date(), contextUsed: [String]? = nil, duration: Double? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.contextUsed = contextUsed
        self.duration = duration
    }
}

/// Estructura de petición HTTP para el endpoint /api/v1/chat.
struct ChatRequestDTO: Codable {
    let message: String
    let model: String
    var use_moe: Bool? = false
}

/// Estructura de respuesta HTTP para el endpoint /api/v1/chat.
struct ChatResponseDTO: Codable {
    let response: String
    let context_used: [String]
    let model_used: String
    let duration: Double
}

/// Estructura de respuesta HTTP para el endpoint /api/v1/status.
struct ServiceStatusDTO: Codable {
    let status: String
    let backend_online: Bool
    let ollama_online: Bool
    let chromadb_online: Bool
}

/// DTO para la respuesta de ingesta de PDF
struct IngestResponseDTO: Codable {
    let filename: String
    let status: String
    let chunks_indexed: Int
    let message: String?
}

/// DTO para la respuesta del procesamiento de evidencias (Audio y Imagen/Visión)
struct EvidenceResponseDTO: Codable {
    let status: String
    let filename: String
    let model_used: String?
    let transcription: String?
    let analysis: String
    let indexed_in_chroma: Bool
}

/// DTO para vaciar las evidencias cargadas
struct ClearEvidenceResponseDTO: Codable {
    let status: String
    let deleted_count: Int
    let message: String
}

/// Petición para redactar una demanda autónoma fundamentada en pruebas
struct AutonomousDraftRequestDTO: Codable {
    let model: String
}

/// DTO para la respuesta de redacción autónoma de demandas
struct AutonomousDraftResponseDTO: Codable {
    let analysis: String
    let draft: String
    let model_used: String
    let duration: Double
}


struct TimelineEventDTO: Codable, Identifiable {
    var id: UUID = UUID()
    let date: String
    let description: String
    let importance: String // "alta", "media", "baja"
    
    enum CodingKeys: String, CodingKey {
        case date
        case description
        case importance
    }
}

struct TimelineResponseDTO: Codable {
    let events: [TimelineEventDTO]
    let modelUsed: String
    let duration: Double
    
    enum CodingKeys: String, CodingKey {
        case events
        case modelUsed = "model_used"
        case duration
    }
}

struct GenerateDocumentRequest: Codable {
    let templateType: String
    let variables: [String: String]
    let model: String
    
    enum CodingKeys: String, CodingKey {
        case templateType = "template_type"
        case variables
        case model
    }
}

struct DocumentResponseDTO: Codable {
    let document: String
    let templateUsed: String
    let modelUsed: String
    let duration: Double
    
    enum CodingKeys: String, CodingKey {
        case document
        case templateUsed = "template_used"
        case modelUsed = "model_used"
        case duration
    }
}

// MARK: - Pipeline DTOs
struct ExtractedCaseDataDTO: Codable {
    let start_date: String?
    let end_date: String?
    let salary: Double?
    let dismissal_reason: String?
    let is_disciplinary: Bool?
}

struct CalculationsSummaryDTO: Codable {
    let daily_salary: Double
    let total_days_worked: Int
    let improcedente_final: Double
    let objetivo_final: Double
}

struct PipelineResponseDTO: Codable {
    let summary: String
    let extracted_data: ExtractedCaseDataDTO
    let calculations: CalculationsSummaryDTO
    let draft: String
}
