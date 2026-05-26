import time
import logging
from fastapi import APIRouter, HTTPException, status
from fastapi.responses import StreamingResponse

from langchain_core.messages import SystemMessage, HumanMessage
from langchain_community.chat_models import ChatOllama

from models.schemas import ChatRequest, ChatResponse
from services.llm_service import check_ollama_status
from services.rag_service import get_retrieved_context
from core.config import OLLAMA_BASE_URL, OLLAMA_MODEL, SYSTEM_PROMPT, CHROMA_COLLECTION_LAW, CHROMA_COLLECTION_EVIDENCE

logger = logging.getLogger("LawLabBackend")
router = APIRouter()

@router.post("", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """
    Procesa la petición de chat legal. Realiza una búsqueda semántica de soporte
    en ChromaDB, inyecta el prompt de sistema y solicita la respuesta al motor de Ollama.
    Soporta Streaming (Server-Sent Events) si request.stream es True.
    """
    start_time = time.time()
    
    if not check_ollama_status():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="El motor de Ollama local está desconectado en el puerto 11434."
        )
        
    logger.info(f"Processing query: '{request.message[:60]}...' using model '{request.model}'")
    
    # Run both RAG retrievals in parallel (they are independent I/O-bound operations)
    import asyncio
    evidence_chunks, law_chunks = await asyncio.gather(
        asyncio.to_thread(get_retrieved_context, request.message, CHROMA_COLLECTION_EVIDENCE, 2),
        asyncio.to_thread(get_retrieved_context, request.message, CHROMA_COLLECTION_LAW, 3)
    )
    
    prompt_content = request.message
    context_str = ""
    
    if evidence_chunks:
        evidence_str = "\n\n".join([f"[Evidencia {i+1}][Fuente: {chunk['id']}]: {chunk['text']}" for i, chunk in enumerate(evidence_chunks)])
        context_str += f"HECHOS Y EVIDENCIAS DEL CASO:\n{evidence_str}\n\n"
        
    if law_chunks:
        law_str = "\n\n".join([f"[Ley/Jurisprudencia {i+1}][Fuente: {chunk['id']}]: {chunk['text']}" for i, chunk in enumerate(law_chunks)])
        context_str += f"MARCO LEGAL Y JURISPRUDENCIA:\n{law_str}\n\n"
        
    if context_str:
        prompt_content = (
            "Usa los siguientes fragmentos de la legislación laboral española y las evidencias del caso para fundamentar tu respuesta. "
            "REGLA OBLIGATORIA: Por CADA afirmación, hecho o artículo que uses del contexto, DEBES incluir al final de la frase la etiqueta [doc:NOMBRE_FUENTE], "
            "donde NOMBRE_FUENTE es el valor que aparece en [Fuente: X] del fragmento.\n"
            "Si el contexto no proporciona suficiente información, adviértelo pero responde de todos modos.\n\n"
            f"{context_str}"
            f"Consulta del Usuario: {request.message}"
        )
        logger.info("ChromaDB context (laws and evidence) injected successfully.")
    else:
        logger.info("Proceeding without additional ChromaDB context.")
        
    try:
        llm = ChatOllama(
            base_url=OLLAMA_BASE_URL,
            model=request.model or OLLAMA_MODEL,
            temperature=0.2
        )
        
        messages = [
            SystemMessage(content=SYSTEM_PROMPT),
            HumanMessage(content=prompt_content)
        ]
        
        if getattr(request, 'stream', False):
            import json
            # Streaming Response using SSE
            async def generate_stream():
                for chunk in llm.stream(messages):
                    payload = json.dumps({"content": chunk.content})
                    yield f"data: {payload}\n\n"
                yield "data: [DONE]\n\n"
                
            return StreamingResponse(generate_stream(), media_type="text/event-stream")
            
        else:
            # Synchronous Response
            if getattr(request, 'use_moe', False):
                from services.agents_service import run_legal_moe
                final_text = await run_legal_moe(request.message, context_str, request.model or OLLAMA_MODEL)
            else:
                response = await llm.ainvoke(messages)
                final_text = response.content
            import re
            
            # Find all [doc:UUID] tags
            doc_tags = re.findall(r'\[doc:(.*?)\]', final_text)
            if doc_tags:
                all_context = evidence_chunks + law_chunks
                for tag in set(doc_tags):
                    # Basic check: did this source ID even exist in the retrieved chunks?
                    source_exists = any(tag.lower() in c['id'].lower() for c in all_context)
                    if source_exists:
                        final_text = final_text.replace(f"[doc:{tag}]", f"[VALID_DOC:{tag}]")
                    else:
                        final_text = final_text.replace(f"[doc:{tag}]", f"[INVALID_DOC:{tag}]")
                        
            # Si el modelo no usa el tag exacto pero nombra la fuente, intentamos no romper nada.
            
            combined_chunks = []
            if evidence_chunks: combined_chunks.extend([c["text"] for c in evidence_chunks])
            if law_chunks: combined_chunks.extend([c["text"] for c in law_chunks])

            elapsed_time = time.time() - start_time
            
            return ChatResponse(
                response=final_text,
                context_used=combined_chunks,
                model_used=request.model or OLLAMA_MODEL,
                duration=round(elapsed_time, 2)
            )
            
    except Exception as e:
        logger.error(f"Error communicating with Ollama: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error interno al invocar a Ollama: {str(e)}"
        )
