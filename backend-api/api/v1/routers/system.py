import os
import shutil
import tempfile
import logging
import re
from fastapi import APIRouter, HTTPException, status, UploadFile, File

from langchain_community.document_loaders import PyPDFLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_community.vectorstores import Chroma

from models.schemas import ServiceStatus
from services.llm_service import check_ollama_status
from services.rag_service import check_chromadb_status, get_embeddings, get_chroma_client
from core.config import CHROMA_HOST, CHROMA_PORT, CHROMA_COLLECTION_LAW

logger = logging.getLogger("LawLabBackend")
router = APIRouter()

@router.get("/status", response_model=ServiceStatus)
async def get_status() -> ServiceStatus:
    ollama_ok = check_ollama_status()
    chroma_ok = check_chromadb_status()
    
    overall_status = "OK" if ollama_ok else "DEGRADED"
    
    return ServiceStatus(
        status=overall_status,
        backend_online=True,
        ollama_online=ollama_ok,
        chromadb_online=chroma_ok
    )

@router.post("/ingest")
async def ingest_file(file: UploadFile = File(...)):
    """
    Ingesta en caliente con Fragmentación Jerárquica para leyes.
    """
    if not file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Solo PDF.")
    if not check_chromadb_status():
        raise HTTPException(status_code=503, detail="ChromaDB desconectado.")
        
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp_file:
            shutil.copyfileobj(file.file, tmp_file)
            tmp_path = tmp_file.name
            
        loader = PyPDFLoader(tmp_path)
        pages = loader.load()
        os.remove(tmp_path)
        
        # Fragmentación Jerárquica: Intentar separar por Artículos usando Regex
        # Si no hay matches claros, fallback a chunking estándar
        text_content = "\n".join([p.page_content for p in pages])
        
        # Regex básico para "Artículo X." o "Art. X."
        art_pattern = re.compile(r'\n(?=Art[íi]culo\s+\d+[\.\:])', re.IGNORECASE)
        art_splits = art_pattern.split(text_content)
        
        from langchain_core.documents import Document
        docs_to_index = []
        
        if len(art_splits) > 5: # Es probablemente un texto legal estructurado
            for chunk in art_splits:
                if len(chunk.strip()) > 50:
                    docs_to_index.append(Document(page_content=chunk.strip(), metadata={"source": file.filename, "type": "law"}))
        else:
            # Fallback a chunking normal
            splitter = RecursiveCharacterTextSplitter(chunk_size=1200, chunk_overlap=200)
            docs_to_index = splitter.split_documents(pages)
            for d in docs_to_index:
                d.metadata["type"] = "law"
                
        if not docs_to_index:
            return {"status": "EMPTY"}
            
        embeddings = get_embeddings()
        client = get_chroma_client()
        
        db = Chroma.from_documents(
            documents=docs_to_index,
            embedding=embeddings,
            client=client,
            collection_name=CHROMA_COLLECTION_LAW
        )
        
        return {"filename": file.filename, "status": "SUCCESS", "chunks_indexed": len(docs_to_index)}
    except Exception as e:
        logger.error(f"Error ingest: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
