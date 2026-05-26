import os
import glob
import logging
import re
from typing import List

from langchain_community.document_loaders import PyPDFLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_community.embeddings import HuggingFaceEmbeddings
from langchain_community.vectorstores import Chroma
from langchain_core.documents import Document
import chromadb

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger("LawLabIngestion")

DOCS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "docs")
CHROMA_HOST = "localhost"
CHROMA_PORT = 8001
CHROMA_COLLECTION = "derecho_laboral_spain"
EMBEDDINGS_MODEL = "sentence-transformers/all-MiniLM-L6-v2"

def ensure_docs_directory():
    if not os.path.exists(DOCS_DIR):
        os.makedirs(DOCS_DIR)
        logger.info(f"Creado directorio de documentos en: {DOCS_DIR}")
        readme_path = os.path.join(DOCS_DIR, "INSTRUCCIONES.txt")
        with open(readme_path, "w", encoding="utf-8") as f:
            f.write("Coloca aquí los archivos PDF de legislación.\n")

def check_chromadb_online() -> bool:
    import requests
    try:
        response = requests.get(f"http://{CHROMA_HOST}:{CHROMA_PORT}/api/v2/heartbeat", timeout=3)
        return response.status_code == 200
    except requests.RequestException:
        return False

def ingest_documents():
    ensure_docs_directory()
    if not check_chromadb_online():
        logger.error("ChromaDB offline.")
        return

    pdf_files = glob.glob(os.path.join(DOCS_DIR, "*.pdf"))
    if not pdf_files:
        logger.warning("No se encontraron PDFs.")
        return

    embeddings = HuggingFaceEmbeddings(model_name=EMBEDDINGS_MODEL)
    client = chromadb.HttpClient(host=CHROMA_HOST, port=CHROMA_PORT)
    total_chunks = 0
    
    for pdf_path in pdf_files:
        filename = os.path.basename(pdf_path)
        logger.info(f"Procesando: {filename}...")
        try:
            loader = PyPDFLoader(pdf_path)
            pages = loader.load()
            text_content = "\n".join([p.page_content for p in pages])
            
            # Hierarchical split
            art_pattern = re.compile(r'\n(?=Art[íi]culo\s+\d+[\.\:])', re.IGNORECASE)
            art_splits = art_pattern.split(text_content)
            
            docs_to_index = []
            if len(art_splits) > 5:
                for chunk in art_splits:
                    if len(chunk.strip()) > 50:
                        docs_to_index.append(Document(page_content=chunk.strip(), metadata={"source": filename, "type": "law"}))
            else:
                splitter = RecursiveCharacterTextSplitter(chunk_size=1200, chunk_overlap=200)
                docs_to_index = splitter.split_documents(pages)
                for d in docs_to_index:
                    d.metadata["type"] = "law"
                    
            if not docs_to_index:
                continue
                
            Chroma.from_documents(documents=docs_to_index, embedding=embeddings, client=client, collection_name=CHROMA_COLLECTION)
            total_chunks += len(docs_to_index)
            logger.info(f"Indexados {len(docs_to_index)} fragmentos de {filename}.")
        except Exception as e:
            logger.error(f"Error procesando {filename}: {e}")

    logger.info(f"Ingesta finalizada. Total fragmentos: {total_chunks}")

if __name__ == "__main__":
    ingest_documents()
