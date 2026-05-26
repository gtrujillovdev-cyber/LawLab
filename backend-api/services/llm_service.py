import logging
import requests
from core.config import OLLAMA_BASE_URL

logger = logging.getLogger("LawLabBackend")

def check_ollama_status() -> bool:
    """Verifies if the local Ollama instance is running and reachable."""
    try:
        response = requests.get(f"{OLLAMA_BASE_URL}/api/tags", timeout=2)
        return response.status_code == 200
    except requests.RequestException:
        return False
