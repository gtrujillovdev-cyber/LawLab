import time
import os
import tempfile
import shutil
import logging
import json
from typing import List
from fastapi import APIRouter, HTTPException, status, UploadFile, File

from langchain_core.messages import SystemMessage, HumanMessage
from langchain_community.chat_models import ChatOllama
from langchain_community.document_loaders import PyPDFLoader

from models.pipeline import PipelineResponse, ExtractedCaseData, CalculationsSummary
from services.llm_service import check_ollama_status
from services.rag_service import get_retrieved_context, check_chromadb_status
from services.calculator import calculate_spanish_severance
from core.config import OLLAMA_BASE_URL, OLLAMA_MODEL, CHROMA_COLLECTION_LAW
from templates import DESPIDO_IMPROCEDENTE_TEMPLATE, PAPELETA_CONCILIACION_TEMPLATE

logger = logging.getLogger("LawLabBackend")
router = APIRouter()

@router.post("/despido", response_model=PipelineResponse)
async def run_despido_pipeline(files: List[UploadFile] = File(...)):
    """
    Orquestador Lógico: Pipeline Atómico para Despidos
    Fase 1: Ingesta (PDF)
    Fase 2: Extracción JSON (Ollama)
    Fase 3: Auditoría RAG (ChromaDB)
    Fase 4: Ejecución (Cálculos matemáticos puros y Redacción)
    """
    start_time = time.time()

    if not check_ollama_status():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="El motor de Ollama local está desconectado."
        )

    # ---------------------------------------------------------
    # Fase 1: Ingesta (El Mempool)
    # ---------------------------------------------------------
    raw_text = ""
    for file in files:
        if not file.filename.lower().endswith(".pdf"):
            continue
            
        with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp_file:
            shutil.copyfileobj(file.file, tmp_file)
            tmp_path = tmp_file.name
            
        try:
            loader = PyPDFLoader(tmp_path)
            pages = loader.load()
            raw_text += f"\n--- Archivo: {file.filename} ---\n"
            for page in pages:
                raw_text += page.page_content + "\n"
        except Exception as e:
            logger.warning(f"Error procesando PDF {file.filename}: {e}")
        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

    if not raw_text.strip():
        raise HTTPException(status_code=400, detail="No se pudo extraer texto de los PDFs.")

    # ---------------------------------------------------------
    # Fase 2: Extracción JSON (El Parser de Ollama)
    # ---------------------------------------------------------
    extraction_prompt = (
        "Analiza el siguiente texto de documentos laborales y extrae EXCLUSIVAMENTE un JSON con la siguiente estructura:\n"
        "{\n"
        '  "start_date": "YYYY-MM-DD",\n'
        '  "end_date": "YYYY-MM-DD",\n'
        '  "salary": 0.0,\n'
        '  "dismissal_reason": "causa literal del despido",\n'
        '  "is_disciplinary": true/false\n'
        "}\n"
        "Si no encuentras algún dato, ponlo como null. NO añadas texto explicativo, solo el JSON.\n\n"
        f"TEXTO: {raw_text[:4000]}" # Limitar por si es muy largo
    )
    
    llm = ChatOllama(
        base_url=OLLAMA_BASE_URL,
        model=OLLAMA_MODEL,
        temperature=0.0,
        format="json" # Forzar salida en JSON
    )
    
    try:
        response_json = await llm.ainvoke([HumanMessage(content=extraction_prompt)])
        parsed_data = json.loads(response_json.content)
        extracted = ExtractedCaseData(**parsed_data)
    except Exception as e:
        logger.error(f"Error en Extracción JSON: {e}")
        extracted = ExtractedCaseData()

    # ---------------------------------------------------------
    # Fase 3: Auditoría (El Backtesting con RAG)
    # ---------------------------------------------------------
    law_context = ""
    if check_chromadb_status():
        try:
            import asyncio
            query_sustantivo = f"Despido {extracted.dismissal_reason or 'laboral'}"
            query_procesal = "Requisitos formales y procesales demanda despido y papeleta de conciliación LRJS"
            
            chunks_sustantivos = await asyncio.to_thread(get_retrieved_context, query_sustantivo, CHROMA_COLLECTION_LAW, 3)
            chunks_procesales = await asyncio.to_thread(get_retrieved_context, query_procesal, CHROMA_COLLECTION_LAW, 2)
            
            law_chunks = []
            if chunks_sustantivos:
                law_chunks.extend(chunks_sustantivos)
            if chunks_procesales:
                law_chunks.extend(chunks_procesales)
                
            if law_chunks:
                law_context = "\n".join([c["text"] for c in law_chunks])
        except Exception as e:
            logger.warning(f"Error en RAG: {e}")

    # ---------------------------------------------------------
    # Fase 4: Ejecución (Matemáticas + Redacción)
    # ---------------------------------------------------------
    calc_summary = CalculationsSummary(
        daily_salary=0.0, total_days_worked=0, improcedente_final=0.0, objetivo_final=0.0
    )
    
    calc_breakdown = ""
    if extracted.start_date and extracted.end_date and extracted.salary:
        try:
            calc = calculate_spanish_severance(extracted.start_date, extracted.end_date, extracted.salary)
            calc_summary = CalculationsSummary(
                daily_salary=calc["daily_salary"],
                total_days_worked=calc["total_days_worked"],
                improcedente_final=calc["improcedente"]["final"],
                objetivo_final=calc["objetivo"]["final"]
            )
            calc_breakdown = (
                "CÁLCULOS DETERMINISTAS APLICABLES:\n"
                f"- Salario diario: {calc_summary.daily_salary} €\n"
                f"- Antigüedad: {calc_summary.total_days_worked} días\n"
                f"- Indemnización Improcedente: {calc_summary.improcedente_final} €\n"
                f"- Indemnización Objetivo: {calc_summary.objetivo_final} €\n"
            )
        except Exception as e:
            logger.error(f"Error matemático: {e}")

    # Redacción del borrador
    draft_prompt = (
        "Redacta un borrador formal de papeleta de conciliación o demanda de despido basado en los siguientes datos.\n"
        "Debes seguir estrictamente la estructura procesal tradicional española.\n\n"
        "--- MODELOS DE REFERENCIA (USA ESTA ESTRUCTURA COMO GUÍA) ---\n"
        f"MODELO PAPELETA SMAC:\n{PAPELETA_CONCILIACION_TEMPLATE}\n\n"
        f"MODELO DEMANDA:\n{DESPIDO_IMPROCEDENTE_TEMPLATE}\n\n"
        "--- DATOS DEL CASO ---\n"
        f"Fecha inicio: {extracted.start_date}\n"
        f"Fecha fin: {extracted.end_date}\n"
        f"Motivo empresa: {extracted.dismissal_reason}\n\n"
        f"{calc_breakdown}\n\n"
        "--- MARCO LEGAL (Sustantivo y Procesal) ---\n"
        f"{law_context}\n\n"
        "Escribe únicamente el texto formal del borrador, rellenando el modelo adecuado con los datos y aplicando los fundamentos de derecho recuperados."
    )
    
    try:
        llm_draft = ChatOllama(base_url=OLLAMA_BASE_URL, model=OLLAMA_MODEL, temperature=0.15)
        sys_msg = SystemMessage(content="Eres un Abogado Laboralista Senior en España experto en litigios. Tu objetivo es redactar demandas y papeletas impecables, aplicando rigurosamente la Ley Reguladora de la Jurisdicción Social (LRJS) y el Estatuto de los Trabajadores (ET), respetando siempre los modelos formales provistos.")
        draft_response = await llm_draft.ainvoke([sys_msg, HumanMessage(content=draft_prompt)])
        draft_text = draft_response.content
    except Exception as e:
        draft_text = f"Error generando borrador: {e}"

    elapsed = round(time.time() - start_time, 2)
    summary_text = f"Pipeline ejecutado con éxito en {elapsed}s. Se extrajeron los datos y se calculó la indemnización."

    return PipelineResponse(
        summary=summary_text,
        extracted_data=extracted,
        calculations=calc_summary,
        draft=draft_text
    )
