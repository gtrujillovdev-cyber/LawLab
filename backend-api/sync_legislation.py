import os
import logging
import requests
import xml.etree.ElementTree as ET
from typing import List, Dict, Any

# LangChain Imports
from langchain_core.documents import Document
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_community.embeddings import HuggingFaceEmbeddings
from langchain_community.vectorstores import Chroma
import chromadb

# Setup Logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger("LawLabLegislationSync")

# Configuration
CHROMA_HOST = "localhost"
CHROMA_PORT = 8001
CHROMA_COLLECTION = "derecho_laboral_spain"
EMBEDDINGS_MODEL = "sentence-transformers/all-MiniLM-L6-v2"

# BOE XML Sources
LEGISLATION_SOURCES = [
    {
        "name": "Estatuto de los Trabajadores",
        "id": "BOE-A-2015-11430",
        "url": "https://www.boe.es/buscar/xml.php?id=BOE-A-2015-11430"
    },
    {
        "name": "Ley Reguladora de la Jurisdicción Social",
        "id": "BOE-A-2011-15936",
        "url": "https://www.boe.es/buscar/xml.php?id=BOE-A-2011-15936"
    }
]

def check_chromadb_online() -> bool:
    """Checks if the ChromaDB Docker service is up and reachable."""
    try:
        response = requests.get(f"http://{CHROMA_HOST}:{CHROMA_PORT}/api/v2/heartbeat", timeout=3)
        return response.status_code == 200
    except requests.RequestException:
        return False

def parse_boe_xml(xml_content: bytes, source_name: str) -> List[Document]:
    """
    Parses consolidated BOE XML using a strict 'class=articulo' state machine.
    This bypasses Table of Contents (which doesn't use class=articulo) and
    correctly associates all paragraphs with their respective articles/dispositions.
    """
    root = ET.fromstring(xml_content)
    texto_elem = root.find("texto")
    if texto_elem is None:
        logger.warning(f"No <texto> tag found in XML for {source_name}")
        return []
        
    p_tags = texto_elem.findall("p")
    logger.info(f"Total <p> tags found in {source_name}: {len(p_tags)}")
    
    parsed_articles = []
    current_title = None
    current_body = []
    
    for p in p_tags:
        p_class = p.attrib.get('class', '')
        text = "".join(p.itertext()).strip()
        
        # If it's a section header of class 'articulo', it starts a new article or disposition
        if p_class == 'articulo':
            if current_title:
                # Save previous article
                parsed_articles.append({
                    "title": current_title,
                    "body": "\n".join(current_body)
                })
            current_title = text
            current_body = []
        elif current_title is not None:
            # Append body text if we are inside an article
            if text:
                current_body.append(text)
                
    # Save the last article
    if current_title:
        parsed_articles.append({
            "title": current_title,
            "body": "\n".join(current_body)
        })
        
    logger.info(f"Parsed {len(parsed_articles)} articles/dispositions from {source_name}.")
    
    # Convert to LangChain Documents with metadata
    documents = []
    for art in parsed_articles:
        title = art["title"]
        body = art["body"]
        
        # Clean article tag for index metadata (e.g. "Artículo 55" or "Disposición adicional primera")
        # Usually format is "Artículo X. Title text..." or "Disposición X. Title text..."
        article_key = title
        if ". " in title:
            article_key = title.split(". ")[0].strip()
        elif "." in title:
            article_key = title.split(".")[0].strip()
            
        doc = Document(
            page_content=f"{title}\n\n{body}",
            metadata={
                "source": source_name,
                "articulo": article_key,
                "titulo": title,
                "type": "law"
            }
        )
        documents.append(doc)
        
    return documents

def sync_legislation():
    # 1. Check ChromaDB
    if not check_chromadb_online():
        logger.error(
            f"No se pudo conectar con ChromaDB en http://{CHROMA_HOST}:{CHROMA_PORT}.\n"
            "Por favor, asegúrate de iniciar el contenedor de ChromaDB con:\n"
            "docker-compose up -d"
        )
        return
        
    logger.info("Conectado con éxito a ChromaDB.")
    
    # 2. Load Embeddings Model
    logger.info(f"Cargando modelo de embeddings: {EMBEDDINGS_MODEL}...")
    embeddings = HuggingFaceEmbeddings(model_name=EMBEDDINGS_MODEL)
    
    # 3. Connect to ChromaDB
    client = chromadb.HttpClient(host=CHROMA_HOST, port=CHROMA_PORT)
    
    all_documents = []
    
    # 4. Fetch and Parse XMLs
    for source in LEGISLATION_SOURCES:
        logger.info(f"Descargando {source['name']} desde {source['url']}...")
        try:
            response = requests.get(source["url"], timeout=30)
            if response.status_code == 200:
                logger.info(f"Descarga completa de {source['name']} ({len(response.content)} bytes).")
                docs = parse_boe_xml(response.content, source["name"])
                all_documents.extend(docs)
            else:
                logger.error(f"Error al descargar {source['name']}. Código de estado: {response.status_code}")
        except Exception as e:
            logger.error(f"Error durante el procesamiento de {source['name']}: {str(e)}", exc_info=True)
            
    if not all_documents:
        logger.warning("No se pudo parsear ninguna ley. Abortando sincronización.")
        return
        
    # 5. Split documents into chunks for vector indexing
    logger.info(f"Segmentando {len(all_documents)} leyes en fragmentos vectoriales...")
    splitter = RecursiveCharacterTextSplitter(
        chunk_size=1000,
        chunk_overlap=200,
        length_function=len
    )
    chunks = splitter.split_documents(all_documents)
    logger.info(f"Generados {len(chunks)} fragmentos vectoriales.")
    
    # 6. Index into ChromaDB
    logger.info(f"Indexando {len(chunks)} fragmentos en la colección vectorial '{CHROMA_COLLECTION}'...")
    try:
        db = Chroma.from_documents(
            documents=chunks,
            embedding=embeddings,
            client=client,
            collection_name=CHROMA_COLLECTION
        )
        logger.info(f"🎉 ¡Sincronización finalizada con éxito! Total de fragmentos indexados: {len(chunks)}")
    except Exception as e:
        logger.error(f"Error al indexar fragmentos en ChromaDB: {str(e)}", exc_info=True)

if __name__ == "__main__":
    sync_legislation()
