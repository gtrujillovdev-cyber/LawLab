import os

OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "qwen2.5:7b-instruct")

CHROMA_HOST = os.getenv("CHROMA_HOST", "localhost")
CHROMA_PORT = int(os.getenv("CHROMA_PORT", 8001))
CHROMA_COLLECTION_LAW = os.getenv("CHROMA_COLLECTION_LAW", "derecho_laboral_spain")
CHROMA_COLLECTION_EVIDENCE = os.getenv("CHROMA_COLLECTION_EVIDENCE", "case_evidence")

SYSTEM_PROMPT = (
    "Eres un Abogado Laboralista Senior en España. Tu objetivo es redactar demandas, "
    "calcular plazos procesales y analizar viabilidad legal. Basa tus respuestas en el "
    "Estatuto de los Trabajadores y la legislación laboral española vigente. Sé preciso, "
    "profesional y cita artículos de la ley siempre que sea posible."
)

EMBEDDINGS_MODEL = os.getenv("EMBEDDINGS_MODEL", "sentence-transformers/all-MiniLM-L6-v2")
