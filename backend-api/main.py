import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api.v1.routers import chat, documents, system, analysis, drafting, pipeline

# Setup Logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")

app = FastAPI(
    title="LawLab API - Asistente de Derecho Laboral Español",
    description="Backend de IA local especializado en redactar demandas, calcular plazos y analizar viabilidad legal.",
    version="1.0.0"
)

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register API Routers
app.include_router(system.router, prefix="/api/v1", tags=["System"])
app.include_router(chat.router, prefix="/api/v1/chat", tags=["Chat"])
app.include_router(documents.router, prefix="/api/v1", tags=["Documents"])
app.include_router(analysis.router, prefix="/api/v1/analysis", tags=["Analysis"])
app.include_router(drafting.router, prefix="/api/v1/drafting", tags=["Drafting"])
app.include_router(pipeline.router, prefix="/api/v1/pipeline", tags=["Pipeline"])

# Pre-warm critical resources on startup to avoid cold-start latency on first request
@app.on_event("startup")
async def startup_prewarm():
    import asyncio
    from services.rag_service import get_embeddings
    logging.info("Pre-warming embeddings model...")
    await asyncio.to_thread(get_embeddings)
    logging.info("Embeddings model loaded and cached.")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)
