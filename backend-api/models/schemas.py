from typing import List, Optional
from pydantic import BaseModel, Field
from core.config import OLLAMA_MODEL

class ChatRequest(BaseModel):
    message: str = Field(..., description="Mensaje o consulta legal del usuario")
    model: Optional[str] = Field(default=OLLAMA_MODEL, description="Modelo de Ollama a utilizar")
    stream: Optional[bool] = Field(default=False, description="Si es True, devuelve una respuesta en streaming (SSE)")
    use_moe: Optional[bool] = Field(default=False, description="Si es True, usa el Análisis Multi-Agente (Mixture of Experts)")

class MessageDetail(BaseModel):
    role: str = Field(..., description="Rol del emisor: 'user' o 'assistant'")
    content: str = Field(..., description="Contenido del mensaje")

class ChatResponse(BaseModel):
    response: str = Field(..., description="Respuesta del asistente legal")
    context_used: List[str] = Field(default=[], description="Fragmentos de ley recuperados por RAG")
    model_used: str = Field(..., description="Modelo de LLM utilizado")
    duration: float = Field(..., description="Tiempo transcurrido en segundos")

class ServiceStatus(BaseModel):
    status: str = Field(..., description="Estado general ('OK' o 'ERROR')")
    backend_online: bool = Field(..., description="Indica si este backend está operativo")
    ollama_online: bool = Field(..., description="Indica si Ollama local está accesible")
    chromadb_online: bool = Field(..., description="Indica si la base de datos ChromaDB está accesible")

class GenerateDocumentRequest(BaseModel):
    template_type: str = Field(..., description="Tipo de plantilla: 'despido', 'conciliacion' o 'cantidad'")
    variables: dict = Field(..., description="Variables para inyectar en la plantilla")
    model: Optional[str] = Field(default=OLLAMA_MODEL, description="Modelo de Ollama a utilizar")

class DocumentResponse(BaseModel):
    document: str = Field(..., description="Documento legal generado")
    template_used: str = Field(..., description="Plantilla utilizada")
    model_used: str = Field(..., description="Modelo de LLM utilizado")
    duration: float = Field(..., description="Tiempo transcurrido en segundos")

class AutonomousDraftRequest(BaseModel):
    model: Optional[str] = Field(default=OLLAMA_MODEL, description="Modelo de Ollama a utilizar")

class AutonomousDraftResponse(BaseModel):
    analysis: str = Field(..., description="Análisis de viabilidad y plazos")
    draft: str = Field(..., description="Escrito procesal formal generado")
    model_used: str = Field(..., description="Modelo de LLM utilizado")
    duration: float = Field(..., description="Tiempo transcurrido en segundos")

class TimelineRequest(BaseModel):
    model: Optional[str] = Field(default=OLLAMA_MODEL, description="Modelo de Ollama a utilizar")

class TimelineEvent(BaseModel):
    date: str = Field(..., description="Fecha o periodo aproximado (ej. '15/03/2023' o 'Marzo 2023')")
    description: str = Field(..., description="Descripción del evento")
    importance: str = Field(..., description="Importancia: 'alta', 'media' o 'baja'")

class TimelineResponse(BaseModel):
    events: List[TimelineEvent] = Field(..., description="Lista de eventos ordenados cronológicamente")
    model_used: str = Field(..., description="Modelo de LLM utilizado")
    duration: float = Field(..., description="Tiempo transcurrido en segundos")
