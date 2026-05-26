import time
import json
from fastapi import APIRouter, HTTPException
from pydantic import ValidationError
import logging
logger = logging.getLogger(__name__)

from models.schemas import TimelineRequest, TimelineResponse, TimelineEvent
from services.rag_service import get_retrieved_context
from langchain_core.messages import SystemMessage, HumanMessage
from langchain_community.chat_models import ChatOllama
from core.config import OLLAMA_BASE_URL
from core.config import OLLAMA_MODEL

router = APIRouter()

@router.post("/timeline", response_model=TimelineResponse)
async def generate_timeline(request: TimelineRequest):
    """
    Analiza la carpeta del caso (colección case_evidence) y extrae de forma automática
    una cronología de eventos clave (fechas de contratos, notificaciones, despidos, etc.).
    """
    start_time = time.time()
    logger.info("Iniciando generación de cronología...")
    
    # 1. Recuperar toda la evidencia del caso (sin filtrar por query específica)
    # Para la cronología, queremos leer los documentos del caso. Como no tenemos un endpoint 
    # para listar todo, podemos hacer un query genérico buscando fechas o eventos.
    case_context = get_retrieved_context("fechas hitos eventos contrato despido notificación", k=15, collection_name="case_evidence")
    
    if not case_context:
        # Si no hay evidencia, devolvemos un timeline vacío
        return TimelineResponse(
            events=[],
            model_used=request.model or OLLAMA_MODEL,
            duration=round(time.time() - start_time, 2)
        )
        
    case_context_str = "\n".join([f"- {item.get('text', '')}" for item in case_context])
    # 2. Prompt estricto para extraer fechas en JSON
    system_prompt = """Eres un analista legal experto. Tu única tarea es extraer eventos cronológicos del contexto proporcionado.
Debes devolver ÚNICAMENTE un array JSON válido con los eventos ordenados por fecha, del más antiguo al más reciente.
Cada evento debe tener esta estructura exacta:
{
  "date": "Fecha o periodo",
  "description": "Descripción clara del evento legal",
  "importance": "alta", "media" o "baja"
}
Si no encuentras fechas claras, deduce el orden lógico. 
NO escribas NADA MÁS que el JSON (ni bloques de código, ni explicaciones)."""
    
    user_prompt = f"Contexto del caso:\n{case_context_str}\n\nExtrae la cronología en JSON:"
    
    # 3. Llamada al LLM
    try:
        llm = ChatOllama(model=request.model or OLLAMA_MODEL, base_url=OLLAMA_BASE_URL, temperature=0.1)
        messages = [
            SystemMessage(content=system_prompt),
            HumanMessage(content=user_prompt)
        ]
        llm_response = await llm.ainvoke(messages)
        
        # 4. Parsear el JSON
        json_str = llm_response.content
        # Limpiar posibles bloques de markdown
        json_str = json_str.replace("```json", "").replace("```", "").strip()
        
        try:
            events_data = json.loads(json_str)
            # Validar y parsear a TimelineEvent
            events = []
            for item in events_data:
                events.append(TimelineEvent(**item))
                
        except (json.JSONDecodeError, ValidationError) as e:
            logger.error(f"Error parseando JSON de cronología: {e}")
            logger.error(f"Salida cruda del LLM: {json_str}")
            # Fallback a un evento de error para que la UI no se rompa
            events = [
                TimelineEvent(
                    date="Desconocido",
                    description="No se pudo procesar la cronología correctamente debido a un error de formato del modelo.",
                    importance="baja"
                )
            ]
            
    except Exception as e:
        logger.error(f"Error en el LLM para cronología: {e}")
        raise HTTPException(status_code=500, detail="Error generando cronología")
        
    return TimelineResponse(
        events=events,
        model_used=request.model or OLLAMA_MODEL,
        duration=round(time.time() - start_time, 2)
    )
