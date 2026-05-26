from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import date

# ---------------------------------------------------------
# Fase 2: Extracción JSON (Ollama Structured Output)
# ---------------------------------------------------------
class ExtractedCaseData(BaseModel):
    """
    Modelo estricto que forzamos a Ollama a devolver en formato JSON 
    durante la fase de lectura de la carta de despido / nómina.
    """
    start_date: Optional[date] = Field(None, description="Fecha de inicio del contrato en formato YYYY-MM-DD")
    end_date: Optional[date] = Field(None, description="Fecha de finalización del contrato (despido) en formato YYYY-MM-DD")
    salary: Optional[float] = Field(None, description="Salario bruto mensual en euros")
    dismissal_reason: Optional[str] = Field(None, description="Causa del despido alegada por la empresa")
    is_disciplinary: Optional[bool] = Field(None, description="¿Es un despido disciplinario?")

# ---------------------------------------------------------
# Fase 4: Salida del Pipeline (Ejecución final)
# ---------------------------------------------------------
class CalculationsSummary(BaseModel):
    daily_salary: float
    total_days_worked: int
    improcedente_final: float
    objetivo_final: float

class PipelineResponse(BaseModel):
    """
    Estructura JSON final que el backend devuelve a la App de Swift (macOS).
    """
    summary: str = Field(..., description="Resumen ejecutivo del caso")
    extracted_data: ExtractedCaseData = Field(..., description="Datos duros extraídos de los PDFs")
    calculations: CalculationsSummary = Field(..., description="Cálculos matemáticos puros (Take Profit)")
    draft: str = Field(..., description="Borrador de la demanda o papeleta generado por IA")
