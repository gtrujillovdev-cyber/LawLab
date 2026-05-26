import pytest
from fastapi.testclient import TestClient
from main import app
from unittest.mock import patch, MagicMock, AsyncMock

client = TestClient(app)

@pytest.fixture
def mock_pypdf_loader():
    with patch("api.v1.routers.pipeline.PyPDFLoader") as mock_loader:
        mock_instance = MagicMock()
        
        # Simulate loading pages
        mock_page = MagicMock()
        mock_page.page_content = "Contrato indefinido. Fecha inicio: 2015-05-15. Despido el 2026-05-20. Salario: 2250 euros."
        mock_instance.load.return_value = [mock_page]
        
        mock_loader.return_value = mock_instance
        yield mock_loader

@pytest.fixture
def mock_ollama():
    with patch("api.v1.routers.pipeline.ChatOllama") as mock_chat:
        mock_instance = MagicMock()
        
        # Mocking the JSON extraction
        mock_extraction = MagicMock()
        mock_extraction.content = '{"start_date": "2015-05-15", "end_date": "2026-05-20", "salary": 2250.0, "dismissal_reason": "Sin justificar", "is_disciplinary": false}'
        
        # Mocking the Draft generation
        mock_draft = MagicMock()
        mock_draft.content = "Borrador de demanda redactado por la IA."
        
        mock_instance.ainvoke = AsyncMock()
        mock_instance.ainvoke.side_effect = [mock_extraction, mock_draft]
        mock_chat.return_value = mock_instance
        yield mock_chat

def test_despido_pipeline(mock_pypdf_loader, mock_ollama):
    # Enviar un archivo simulado. Como interceptamos PyPDFLoader, el contenido real no importa.
    files = {
        'files': ('dummy.pdf', b'%PDF-1.4\n1 0 obj\n<<>>\nendobj\n', 'application/pdf')
    }
    
    response = client.post("/api/v1/pipeline/despido", files=files)
    
    assert response.status_code == 200, f"Error en pipeline: {response.text}"
    data = response.json()
    
    assert "summary" in data
    assert "extracted_data" in data
    assert "calculations" in data
    assert "draft" in data
    
    # Validar extracción
    assert data["extracted_data"]["start_date"] == "2015-05-15"
    assert data["extracted_data"]["salary"] == 2250.0
    
    # Validar matemáticas
    assert data["calculations"]["daily_salary"] > 0
    assert data["calculations"]["total_days_worked"] > 0
    assert data["calculations"]["improcedente_final"] > 0
    assert data["calculations"]["objetivo_final"] > 0
