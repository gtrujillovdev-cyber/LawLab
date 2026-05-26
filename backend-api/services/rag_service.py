import logging
import requests
import math
import calendar
import re
from datetime import date, timedelta
from typing import List, Dict, Any

from langchain_community.embeddings import HuggingFaceEmbeddings
from langchain_community.vectorstores import Chroma

from core.config import CHROMA_HOST, CHROMA_PORT, CHROMA_COLLECTION_LAW, CHROMA_COLLECTION_EVIDENCE, EMBEDDINGS_MODEL

logger = logging.getLogger("LawLabBackend")

_embeddings = None
_chroma_client = None
_chroma_status_cache = {"online": False, "checked_at": 0}

def get_embeddings():
    global _embeddings
    if _embeddings is None:
        logger.info(f"Cargando modelo SentenceTransformer {EMBEDDINGS_MODEL} de forma global en caché...")
        _embeddings = HuggingFaceEmbeddings(model_name=EMBEDDINGS_MODEL)
    return _embeddings

def check_chromadb_status() -> bool:
    """Checks ChromaDB health with a 30-second cache to avoid redundant HTTP calls."""
    import time as _time
    now = _time.time()
    if now - _chroma_status_cache["checked_at"] < 30:
        return _chroma_status_cache["online"]
    try:
        response = requests.get(f"http://{CHROMA_HOST}:{CHROMA_PORT}/api/v2/heartbeat", timeout=2)
        online = response.status_code == 200
    except requests.RequestException:
        online = False
    _chroma_status_cache["online"] = online
    _chroma_status_cache["checked_at"] = now
    return online

def get_chroma_client():
    """Returns a singleton ChromaDB HTTP client, avoiding reconnection on every query."""
    global _chroma_client
    if _chroma_client is None:
        import chromadb
        _chroma_client = chromadb.HttpClient(host=CHROMA_HOST, port=CHROMA_PORT)
    return _chroma_client

def get_retrieved_context(query: str, collection_name: str, k: int = 3) -> List[Dict[str, str]]:
    """
    Attempts to connect to ChromaDB and retrieve the most relevant chunks from the specified collection.
    If ChromaDB is not running or has no matches, returns an empty list.
    """
    if not check_chromadb_status():
        logger.warning("ChromaDB is offline. Skipping RAG retrieval.")
        return []
    
    try:
        embeddings = get_embeddings()
        client = get_chroma_client()
        
        collections = [col.name for col in client.list_collections()]
        if collection_name not in collections:
            logger.info(f"Collection '{collection_name}' not found in ChromaDB. RAG context is empty.")
            return []

        db = Chroma(
            client=client,
            collection_name=collection_name,
            embedding_function=embeddings
        )
        
        docs_and_scores = db.similarity_search_with_score(query, k=k)
        
        filtered_chunks = []
        for doc, score in docs_and_scores:
            logger.info(f"[{collection_name}] Retrieved chunk with distance score: {score:.4f}")
            if score <= 1.2:  # slightly relaxed threshold for better retrieval
                doc_id = doc.metadata.get("source", "Desconocido")
                filtered_chunks.append({"id": doc_id, "text": doc.page_content})
            else:
                logger.info(f"[{collection_name}] Discarding chunk due to poor similarity score: {score:.4f}")
                
        return filtered_chunks
    except Exception as e:
        logger.error(f"Error in RAG context retrieval for {collection_name}: {str(e)}")
        return []

# --- MOTOR DE CÁLCULO DE INDEMNIZACIONES ESPAÑOLAS ---

def calculate_seniority_months(start_date: date, end_date: date) -> int:
    """
    Calcula la antigüedad en meses aplicando la regla de la jurisprudencia española 'de fecha a fecha'.
    Cualquier fracción de mes se computa como un mes completo.
    """
    if start_date > end_date:
        return 0
        
    years = end_date.year - start_date.year
    months = end_date.month - start_date.month
    total_months = years * 12 + months
    
    def get_completion_date(start: date, m: int) -> date:
        """Calcula la fecha en la que se completan m meses desde start, según regla 'de fecha a fecha'."""
        if m == 0:
            return start - timedelta(days=1)
        month = start.month - 1 + m
        year = start.year + month // 12
        month = month % 12 + 1
        
        _, last_day = calendar.monthrange(year, month)
        
        if start.day == 1:
            # Si el contrato empieza el día 1, el mes m se cumple el último día del mes m-ésimo anterior.
            # Ej: inicio 01/01 → 1 mes se cumple el 31/01.
            prev_month = month - 1
            prev_year = year
            if prev_month == 0:
                prev_month = 12
                prev_year -= 1
            _, prev_last_day = calendar.monthrange(prev_year, prev_month)
            return date(prev_year, prev_month, prev_last_day)
        else:
            target_day = start.day - 1
            if target_day > last_day:
                target_day = last_day
            return date(year, month, target_day)
        
    comp_date = get_completion_date(start_date, total_months)
    
    if end_date == comp_date:
        final_months = total_months
    elif end_date > comp_date:
        final_months = total_months + 1
    else:
        final_months = total_months
        
    return max(1, final_months)

def calculate_spanish_severance(start_date: date, end_date: date, monthly_salary: float) -> dict:
    """
    Realiza el cómputo exacto de indemnizaciones por despido en España,
    aplicando de forma estricta las fórmulas de la reforma laboral del 12/02/2012,
    y calculando la antigüedad 'de fecha a fecha' según la doctrina del Tribunal Supremo.
    """
    daily_salary = (monthly_salary * 12.0) / 365.0
    reform_date = date(2012, 2, 12)
    
    days_p1 = 0
    days_p2 = 0
    if end_date < reform_date:
        days_p1 = (end_date - start_date).days + 1
    elif start_date >= reform_date:
        days_p2 = (end_date - start_date).days + 1
    else:
        days_p1 = (reform_date - start_date).days
        days_p2 = (end_date - reform_date).days + 1
        
    if end_date < reform_date:
        months_p1 = calculate_seniority_months(start_date, end_date)
        months_p2 = 0
    elif start_date >= reform_date:
        months_p1 = 0
        months_p2 = calculate_seniority_months(start_date, end_date)
    else:
        months_p1 = calculate_seniority_months(start_date, date(2012, 2, 11))
        months_p2 = calculate_seniority_months(date(2012, 2, 12), end_date)
        
    total_months = calculate_seniority_months(start_date, end_date)
    
    severance_p1 = (months_p1 * (45.0 / 12.0)) * daily_salary
    severance_p2 = (months_p2 * (33.0 / 12.0)) * daily_salary
    total_improcedente_uncapped = severance_p1 + severance_p2
    
    cap_720_days = daily_salary * 720.0
    cap_1260_days = daily_salary * 1260.0
    
    improcedente_cap = cap_720_days
    is_capped = False
    
    if start_date < reform_date:
        if severance_p1 >= cap_720_days:
            improcedente_cap = min(severance_p1, cap_1260_days)
        else:
            improcedente_cap = cap_720_days
            
    total_improcedente = total_improcedente_uncapped
    if total_improcedente > improcedente_cap:
        total_improcedente = improcedente_cap
        is_capped = True
        
    total_objetivo_uncapped = (total_months * (20.0 / 12.0)) * daily_salary
    cap_360_days = daily_salary * 360.0
    
    total_objetivo = total_objetivo_uncapped
    is_objetivo_capped = False
    if total_objetivo > cap_360_days:
        total_objetivo = cap_360_days
        is_objetivo_capped = True
        
    return {
        "daily_salary": daily_salary,
        "total_days_worked": (end_date - start_date).days + 1,
        "days_pre_reform": days_p1,
        "days_post_reform": days_p2,
        "months_pre_reform": months_p1,
        "months_post_reform": months_p2,
        "improcedente": {
            "uncapped": total_improcedente_uncapped,
            "final": total_improcedente,
            "cap_applied": improcedente_cap,
            "is_capped": is_capped
        },
        "objetivo": {
            "uncapped": total_objetivo_uncapped,
            "final": total_objetivo,
            "cap_applied": cap_360_days,
            "is_capped": is_objetivo_capped
        }
    }

def extract_case_parameters(text: str) -> dict:
    """
    Analiza el texto de las evidencias del caso para extraer de forma heurística
    la antigüedad del trabajador, fecha de despido y salario mensual.
    """
    text_lower = text.lower()
    months_es = {
        "enero": 1, "febrero": 2, "marzo": 3, "abril": 4, "mayo": 5, "junio": 6,
        "julio": 7, "agosto": 8, "septiembre": 9, "octubre": 10, "noviembre": 11, "diciembre": 12
    }
    
    dates_found = []
    
    slash_pattern = re.compile(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{4})\b')
    for m in slash_pattern.finditer(text):
        day, month, year = int(m.group(1)), int(m.group(2)), int(m.group(3))
        try:
            dates_found.append(date(year, month, day))
        except ValueError:
            pass
            
    text_pattern = re.compile(
        r'\b(\d{1,2})\s+de\s+(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)\s+de\s+(\d{4})\b',
        re.IGNORECASE
    )
    for m in text_pattern.finditer(text):
        day = int(m.group(1))
        month_str = m.group(2).lower()
        month = months_es[month_str]
        year = int(m.group(3))
        try:
            dates_found.append(date(year, month, day))
        except ValueError:
            pass
            
    dates_found = sorted(list(set(dates_found)))
    
    start_date = None
    end_date = None
    ambiguous = False
    
    if len(dates_found) >= 2:
        start_date = dates_found[0]
        end_date = dates_found[-1]
    elif len(dates_found) == 1:
        today = date.today()
        if (today - dates_found[0]).days > 365:
            start_date = dates_found[0]
        else:
            end_date = dates_found[0]
        ambiguous = True  # Only 1 date found — assignment is heuristic
            
    salary = None
    salary_patterns = [
        r'\b(\d+(?:\.\d{3})*(?:,\d{2})?)\s*(?:€|euros)(?!\w)',
        r'\bsalario\s+(?:mensual\s+)?(?:de\s+)?(\d+(?:\.\d{3})*(?:,\d{2})?)\s*(?:€|euros)?\b',
        r'\bnómina\s+(?:mensual\s+)?(?:de\s+)?(\d+(?:\.\d{3})*(?:,\d{2})?)\s*(?:€|euros)?\b',
        r'\bsalario\s+(?:bruto\s+)?(?:mensual\s+)?(?:de\s+)?(\d+(?:\.\d{3})*(?:,\d{2})?)\b',
        r'\bretribución\s+(?:mensual\s+)?(?:de\s+)?(\d+(?:\.\d{3})*(?:,\d{2})?)\b'
    ]
    
    for pat in salary_patterns:
        match = re.search(pat, text_lower)
        if match:
            val_str = match.group(1).replace(".", "")
            val_str = val_str.replace(",", ".")
            try:
                salary = float(val_str)
                break
            except ValueError:
                pass
                
    return {
        "start_date": start_date,
        "end_date": end_date,
        "salary": salary,
        "ambiguous": ambiguous
    }
