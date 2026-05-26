import time
import os
import tempfile
import shutil
import logging
import base64
from io import BytesIO
from typing import Optional
from fastapi import APIRouter, HTTPException, status, UploadFile, File

from langchain_core.messages import SystemMessage, HumanMessage
from langchain_community.chat_models import ChatOllama
from langchain_core.documents import Document
from langchain_community.vectorstores import Chroma

from models.schemas import (
    GenerateDocumentRequest, DocumentResponse, 
    AutonomousDraftRequest, AutonomousDraftResponse
)
from services.llm_service import check_ollama_status
from services.rag_service import (
    get_embeddings, check_chromadb_status, get_chroma_client,
    extract_case_parameters, calculate_spanish_severance
)
from core.config import (
    OLLAMA_BASE_URL, OLLAMA_MODEL, 
    CHROMA_HOST, CHROMA_PORT, CHROMA_COLLECTION_LAW, CHROMA_COLLECTION_EVIDENCE
)
from templates import (
    DESPIDO_IMPROCEDENTE_TEMPLATE, 
    PAPELETA_CONCILIACION_TEMPLATE, 
    RECLAMACION_CANTIDAD_TEMPLATE
)

logger = logging.getLogger("LawLabBackend")
router = APIRouter()

# Whisper model singleton — avoids reloading ~150MB model on each audio transcription
_whisper_model_cache = None
def _get_whisper_model():
    global _whisper_model_cache
    if _whisper_model_cache is None:
        import whisper
        _whisper_model_cache = whisper.load_model("base")
    return _whisper_model_cache

@router.post("/generate", response_model=DocumentResponse)
async def generate_document(request: GenerateDocumentRequest) -> DocumentResponse:
    start_time = time.time()
    
    if not check_ollama_status():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="El motor de Ollama local está desconectado."
        )
        
    t_type = request.template_type.lower()
    if t_type == "despido":
        base_template = DESPIDO_IMPROCEDENTE_TEMPLATE
    elif t_type == "conciliacion":
        base_template = PAPELETA_CONCILIACION_TEMPLATE
    elif t_type == "cantidad":
        base_template = RECLAMACION_CANTIDAD_TEMPLATE
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Tipo de plantilla desconocido: {request.template_type}."
        )
        
    formatted_template = base_template
    try:
        class SafeDict(dict):
            def __missing__(self, key):
                return f"[{key.upper()}]"
        safe_vars = SafeDict(request.variables)
        formatted_template = base_template.format_map(safe_vars)
    except Exception as e:
        logger.warning(f"Error parcial al formatear variables: {str(e)}")
        
    FORENSIC_SYSTEM_PROMPT = (
        "Eres un Abogado Laboralista Senior en España experto en redacción de escritos forenses y procesales.\n"
        "Tu tarea es pulir, formalizar y perfeccionar el borrador de documento legal provisto, asegurando "
        "una redacción jurídica impecable, citas precisas a la Ley Reguladora de la Jurisdicción Social (LRJS) "
        "y al Estatuto de los Trabajadores (ET).\n"
        "Reglas estrictas:\n"
        "- Mantén la estructura procesal tradicional (AL JUZGADO DE LO SOCIAL..., HECHOS, FUNDAMENTOS DE DERECHO, SUPLICO).\n"
        "- Sé extremadamente formal, pulcro y técnico.\n"
        "- Conserva los datos específicos proporcionados (nombres, salarios, fechas) pero dales formato formal.\n"
        "- El documento final debe estar en formato Markdown impecable."
    )
    
    prompt_content = (
        "Por favor, redacta de forma definitiva y perfecciona el siguiente escrito procesal utilizando "
        "los datos y hechos especificados en el borrador:\n\n"
        f"--- BORRADOR DE PLANTILLA ---\n{formatted_template}\n\n"
        "Asegúrate de que la redacción sea fluida, solemne y profesional según el estilo jurídico de España."
    )
    
    try:
        llm = ChatOllama(
            base_url=OLLAMA_BASE_URL,
            model=request.model or OLLAMA_MODEL,
            temperature=0.15
        )
        messages = [
            SystemMessage(content=FORENSIC_SYSTEM_PROMPT),
            HumanMessage(content=prompt_content)
        ]
        response = await llm.ainvoke(messages)
        elapsed_time = time.time() - start_time
        
        return DocumentResponse(
            document=response.content,
            template_used=t_type,
            model_used=request.model or OLLAMA_MODEL,
            duration=round(elapsed_time, 2)
        )
    except Exception as e:
        logger.error(f"Error al redactar documento: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error al generar el escrito forense: {str(e)}")

@router.post("/autonomous-draft", response_model=AutonomousDraftResponse)
async def generate_autonomous_draft(request: AutonomousDraftRequest) -> AutonomousDraftResponse:
    start_time = time.time()
    
    if not check_ollama_status() or not check_chromadb_status():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Servicios desconectados (Ollama o ChromaDB)."
        )
        
    try:
        import chromadb
        client = get_chroma_client()
        collections = [col.name for col in client.list_collections()]
        if CHROMA_COLLECTION_EVIDENCE not in collections:
            raise HTTPException(status_code=400, detail="Colección de evidencias no inicializada.")
            
        collection_ev = client.get_collection(CHROMA_COLLECTION_EVIDENCE)
        evidence_data = collection_ev.get()
        evidence_docs = evidence_data.get("documents", [])
        evidence_metas = evidence_data.get("metadatas", [])
        
        if not evidence_docs:
            raise HTTPException(status_code=400, detail="No se encontraron evidencias.")
            
        evidence_texts = []
        for doc, meta in zip(evidence_docs, evidence_metas):
            src = meta.get("source", "Evidencia")
            e_type = meta.get("evidence_type", "prueba")
            evidence_texts.append(f"--- PRUEBA ({src}, tipo: {e_type}) ---\n{doc}")
            
        evidence_context = "\n\n".join(evidence_texts)
        extracted = extract_case_parameters(evidence_context)
        calc_breakdown = ""
        
        if extracted["start_date"] and extracted["end_date"] and extracted["salary"]:
            try:
                calc = calculate_spanish_severance(
                    extracted["start_date"], extracted["end_date"], extracted["salary"]
                )
                calc_breakdown = (
                    "=== CÁLCULO DE INDEMNIZACIONES ===\n"
                    f"- Antigüedad: {extracted['start_date']} a {extracted['end_date']}\n"
                    f"- Salario: {extracted['salary']} €\n"
                    f"- Improcedente Total: {calc['improcedente']['final']:.2f} €\n"
                    f"- Objetivo Total: {calc['objetivo']['final']:.2f} €\n"
                )
            except Exception:
                pass
                
        embeddings = get_embeddings()
        
        law_chunks = []
        try:
            db_law = Chroma(client=client, collection_name=CHROMA_COLLECTION_LAW, embedding_function=embeddings)
            docs_and_scores = db_law.similarity_search_with_score(evidence_context[:1000], k=6)
            law_chunks = [d.page_content for d, s in docs_and_scores]
        except Exception:
            pass
            
        if not law_chunks:
            try:
                db_law = Chroma(client=client, collection_name=CHROMA_COLLECTION_LAW, embedding_function=embeddings)
                fallback_docs = db_law.similarity_search("despido improcedente plazo", k=3)
                law_chunks = [d.page_content for d in fallback_docs]
            except Exception:
                pass
            
        law_context = "\n\n".join([f"[Artículo]: {chunk}" for chunk in law_chunks])
        
        AUTONOMOUS_LAW_PROMPT = (
            "Actúas como un Abogado Laboralista Senior en España. Tu objetivo es redactar un escrito procesal definitivo "
            "(DEMANDA o PAPELETA) analizando evidencias y ley aplicable.\n"
            "FORMATO DE SALIDA:\n"
            "### 📈 ANÁLISIS DE ESTRATEGIA Y VIABILIDAD\n"
            "---\n"
            "### ⚖️ PROPUESTA DE ESCRITO JURÍDICO"
        )
        
        prompt_content = f"EVIDENCIAS:\n{evidence_context}\n\n{calc_breakdown}\nLEYES:\n{law_context}"
        
        llm = ChatOllama(base_url=OLLAMA_BASE_URL, model=request.model or OLLAMA_MODEL, temperature=0.15)
        messages = [SystemMessage(content=AUTONOMOUS_LAW_PROMPT), HumanMessage(content=prompt_content)]
        response = await llm.ainvoke(messages)
        elapsed_time = time.time() - start_time
        
        full_response = response.content
        if "---" in full_response:
            parts = full_response.split("---", 1)
            analysis = parts[0].strip()
            draft = parts[1].strip()
        else:
            analysis = "Análisis integrado en la respuesta."
            draft = full_response
            
        return AutonomousDraftResponse(
            analysis=analysis, draft=draft, model_used=request.model or OLLAMA_MODEL, duration=round(elapsed_time, 2)
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error autónomo: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/evidence/pdf")
async def analyze_pdf_evidence(file: UploadFile = File(...)):
    if not file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Solo PDF.")
    if not check_chromadb_status():
        raise HTTPException(status_code=503, detail="ChromaDB desconectado.")
        
    try:
        from langchain_community.document_loaders import PyPDFLoader
        import tempfile
        import os
        import shutil
        import time
        from langchain_text_splitters import RecursiveCharacterTextSplitter
        
        with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp_file:
            shutil.copyfileobj(file.file, tmp_file)
            tmp_path = tmp_file.name
            
        loader = PyPDFLoader(tmp_path)
        pages = loader.load()
        os.remove(tmp_path)
        
        splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200)
        docs_to_index = splitter.split_documents(pages)
        
        for d in docs_to_index:
            d.metadata["type"] = "evidence"
            d.metadata["evidence_type"] = "pdf"
            d.metadata["source"] = file.filename
            d.metadata["timestamp"] = time.time()
            
        if not docs_to_index:
            return {"status": "EMPTY"}
            
        embeddings = get_embeddings()
        import chromadb
        client = get_chroma_client()
        
        db = Chroma.from_documents(
            documents=docs_to_index,
            embedding=embeddings,
            client=client,
            collection_name=CHROMA_COLLECTION_EVIDENCE
        )
        
        return {"filename": file.filename, "status": "SUCCESS", "chunks_indexed": len(docs_to_index)}
    except Exception as e:
        logger.error(f"Error evidencia PDF: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/evidence/vision")
async def analyze_vision_evidence(file: UploadFile = File(...), model: Optional[str] = "llama3.2-vision"):
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="No es una imagen válida.")
    if not check_ollama_status():
        raise HTTPException(status_code=503, detail="Ollama desconectado.")

    try:
        from PIL import Image
        import requests
        
        image_bytes = await file.read()
        image = Image.open(BytesIO(image_bytes))
        if image.mode in ("RGBA", "P"): image = image.convert("RGB")
        buffered = BytesIO()
        image.save(buffered, format="JPEG")
        img_str = base64.b64encode(buffered.getvalue()).decode("utf-8")
        
        prompt = "Actúas como Perito Judicial. Transcribe el texto de la imagen y analiza los hechos laborales demostrados."
        payload = {
            "model": model or "llama3.2-vision",
            "messages": [
                {"role": "system", "content": prompt},
                {"role": "user", "content": "Analiza esto.", "images": [img_str]}
            ],
            "stream": False
        }
        
        res = requests.post(f"{OLLAMA_BASE_URL}/api/chat", json=payload, timeout=120)
        if res.status_code != 200:
            raise HTTPException(status_code=500, detail="Error de Ollama Vision")
            
        analysis_text = res.json()["message"]["content"]
        
        if check_chromadb_status():
            embeddings = get_embeddings()
            import chromadb
            client = get_chroma_client()
            doc = Document(
                page_content=f"EVIDENCIA VISUAL ({file.filename}):\n\n{analysis_text}",
                metadata={"source": file.filename, "type": "evidence", "evidence_type": "vision", "timestamp": time.time()}
            )
            db = Chroma(client=client, collection_name=CHROMA_COLLECTION_EVIDENCE, embedding_function=embeddings)
            db.add_documents([doc])
            
        return {"status": "SUCCESS", "filename": file.filename, "analysis": analysis_text, "indexed_in_chroma": check_chromadb_status()}
    except Exception as e:
        logger.error(f"Error visión: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/evidence/audio")
async def analyze_audio_evidence(file: UploadFile = File(...)):
    if shutil.which("ffmpeg") is None:
        raise HTTPException(status_code=500, detail="Se requiere ffmpeg.")
        
    try:
        suffix = os.path.splitext(file.filename)[1] if file.filename else ".wav"
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp_file:
            shutil.copyfileobj(file.file, tmp_file)
            tmp_path = tmp_file.name
            
        whisper_model = _get_whisper_model()
        result = whisper_model.transcribe(tmp_path, language="es")
        transcription_text = result.get("text", "").strip()
        os.remove(tmp_path)
        
        if not transcription_text:
            return {"status": "EMPTY", "transcription": "Sin voz."}
            
        analysis_prompt = f"Resume y extrae hechos laborales de esta transcripción:\n{transcription_text}"
        analysis_text = ""
        
        if check_ollama_status():
            llm = ChatOllama(base_url=OLLAMA_BASE_URL, model=OLLAMA_MODEL, temperature=0.1)
            analysis_text = (await llm.ainvoke([HumanMessage(content=analysis_prompt)])).content
        else:
            analysis_text = f"Transcripción:\n{transcription_text}"
            
        if check_chromadb_status():
            embeddings = get_embeddings()
            import chromadb
            client = get_chroma_client()
            doc = Document(
                page_content=f"EVIDENCIA AUDIO ({file.filename}):\n{transcription_text}\nANÁLISIS:\n{analysis_text}",
                metadata={"source": file.filename, "type": "evidence", "evidence_type": "audio", "timestamp": time.time()}
            )
            db = Chroma(client=client, collection_name=CHROMA_COLLECTION_EVIDENCE, embedding_function=embeddings)
            db.add_documents([doc])
            
        return {"status": "SUCCESS", "filename": file.filename, "transcription": transcription_text, "analysis": analysis_text}
    except Exception as e:
        logger.error(f"Error audio: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/evidence/clear")
async def clear_evidence():
    if not check_chromadb_status():
        raise HTTPException(status_code=503, detail="ChromaDB offline")
    try:
        import chromadb
        client = get_chroma_client()
        if CHROMA_COLLECTION_EVIDENCE not in [c.name for c in client.list_collections()]:
            return {"status": "SUCCESS", "deleted_count": 0}
            
        collection = client.get_collection(CHROMA_COLLECTION_EVIDENCE)
        current_ev = collection.get()
        count = len(current_ev.get("ids", []))
        if count > 0:
            client.delete_collection(CHROMA_COLLECTION_EVIDENCE)
        return {"status": "SUCCESS", "deleted_count": count}
    except Exception as e:
        logger.error(f"Error clear: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
