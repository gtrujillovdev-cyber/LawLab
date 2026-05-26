import time
from fastapi import APIRouter, HTTPException
import logging
logger = logging.getLogger(__name__)

from models.schemas import GenerateDocumentRequest, DocumentResponse
from services.rag_service import get_retrieved_context
from langchain_core.messages import SystemMessage, HumanMessage
from langchain_community.chat_models import ChatOllama
from core.config import OLLAMA_BASE_URL
from core.config import OLLAMA_MODEL

router = APIRouter()

TEMPLATES = {
    "despido": """Estructura de Demanda por Despido:
1. ENCABEZAMIENTO: Al Juzgado de lo Social, datos del demandante {demandante} y demandado {demandado}.
2. HECHOS: 
   - Antigüedad, categoría y salario.
   - Fecha y forma del despido.
   - Motivos alegados por la empresa y por qué son falsos o improcedentes según la evidencia.
3. FUNDAMENTOS DE DERECHO: Estatuto de los Trabajadores (Arts. 54-56).
4. SUPLICO: Que se declare la improcedencia o nulidad del despido con las consecuencias legales (readmisión o indemnización).
""",
    "conciliacion": """Estructura de Papeleta de Conciliación:
1. AL SERVICIO DE MEDIACIÓN, ARBITRAJE Y CONCILIACIÓN.
2. DATOS: Demandante {demandante} y empresa {demandado}.
3. HECHOS RESUMIDOS: Relación laboral y acto empresarial que se impugna.
4. PETICIÓN: Que se cite a la empresa para intentar avenencia.
"""
}

@router.post("/draft", response_model=DocumentResponse)
async def generate_draft(request: GenerateDocumentRequest):
    """
    Genera un escrito procesal (demanda, papeleta, etc.) combinando una plantilla estricta
    con el contexto extraído de la evidencia y leyes.
    """
    start_time = time.time()
    logger.info(f"Generando escrito tipo '{request.template_type}'...")
    
    # 1. Recuperar contexto del caso
    case_context = get_retrieved_context("hechos relevantes despido motivos", k=10, collection_name="case_evidence")
    if not case_context:
        case_context_str = "No se encontró evidencia adicional."
    else:
        case_context_str = "\n".join([f"- {item.get('text', '')}" for item in case_context])
    
    # 2. Seleccionar plantilla base
    template_structure = TEMPLATES.get(request.template_type.lower())
    if not template_structure:
        # Fallback genérico
        template_structure = f"Estructura genérica para escrito de tipo: {request.template_type}\nIncluye encabezado, hechos, fundamentos y suplico."
        
    # Reemplazar variables básicas en la plantilla si existen
    for key, value in request.variables.items():
        placeholder = "{" + key + "}"
        if placeholder in template_structure:
            template_structure = template_structure.replace(placeholder, str(value))
    
    # 3. Prompt para el LLM
    system_prompt = f"""Eres un abogado laboralista experto redactando escritos procesales.
Tu tarea es redactar un documento formal, profesional y listo para presentar, siguiendo EXACTAMENTE esta estructura:
{template_structure}

Reglas estrictas:
- Usa lenguaje jurídico formal español.
- NO inventes datos que no estén en la evidencia. Si falta información crucial (ej. el CIF de la empresa), pon [COMPLETAR].
- Basa los hechos en esta evidencia del caso:
{case_context_str}

Devuelve ÚNICAMENTE el texto del escrito. Nada de saludos, introducciones ni comentarios."""

    user_prompt = "Redacta el escrito ahora."
    
    try:
        llm = ChatOllama(model=request.model or OLLAMA_MODEL, base_url=OLLAMA_BASE_URL, temperature=0.3)
        messages = [
            SystemMessage(content=system_prompt),
            HumanMessage(content=user_prompt)
        ]
        llm_response = await llm.ainvoke(messages)
        
        document_text = llm_response.content
        
    except Exception as e:
        logger.error(f"Error generando documento: {e}")
        raise HTTPException(status_code=500, detail="Error generando documento")
        
    return DocumentResponse(
        document=document_text,
        template_used=request.template_type,
        model_used=request.model or OLLAMA_MODEL,
        duration=round(time.time() - start_time, 2)
    )
