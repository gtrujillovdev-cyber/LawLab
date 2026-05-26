import asyncio
import time
import logging
from typing import List, Dict
from langchain_community.chat_models import ChatOllama
from langchain_core.messages import SystemMessage, HumanMessage

from core.config import OLLAMA_BASE_URL, OLLAMA_MODEL

logger = logging.getLogger("LawLabBackend")

AGENT_PROCESAL_PROMPT = """Eres el Agente Analista Procesal.
Tu objetivo es analizar estrictamente los plazos, jurisdicción aplicable y posibles defectos de forma basados en los hechos provistos.
No propongas jurisprudencia ni estrategia. Céntrate exclusivamente en el derecho procesal y caducidades.
Devuelve un informe breve con viñetas."""

AGENT_JURISPRUDENCIA_PROMPT = """Eres el Agente de Jurisprudencia.
Tu objetivo es buscar similitudes entre el caso actual y la base de leyes o jurisprudencia provista en el contexto.
Cita los artículos exactos y explica brevemente por qué aplican.
No calcules plazos procesales."""

AGENT_ESTRATEGIA_PROMPT = """Eres el Agente de Estrategia Legal (Sintetizador).
A continuación recibirás el análisis del Agente Procesal y del Agente de Jurisprudencia, además de los hechos originales.
Tu objetivo es proponer la mejor línea de defensa o ataque basándote en esos hallazgos.
Sintetiza la información y elabora una hoja de ruta clara para el letrado."""

async def _run_agent(role_name: str, system_prompt: str, user_prompt: str, model: str) -> str:
    """Ejecuta un agente de forma asíncrona."""
    try:
        logger.info(f"Iniciando {role_name}...")
        llm = ChatOllama(base_url=OLLAMA_BASE_URL, model=model, temperature=0.1)
        messages = [
            SystemMessage(content=system_prompt),
            HumanMessage(content=user_prompt)
        ]
        # langchain ChatOllama async invoke
        response = await llm.ainvoke(messages)
        logger.info(f"Finalizó {role_name}.")
        return response.content
    except Exception as e:
        logger.error(f"Error en {role_name}: {e}")
        return f"Error en {role_name}: {e}"

async def run_legal_moe(query: str, context_str: str, model: str = OLLAMA_MODEL) -> str:
    """
    Ejecuta el Mixture of Experts legal.
    1. Ejecuta en paralelo el Agente Procesal y el Agente de Jurisprudencia.
    2. Pasa los resultados al Agente de Estrategia para la respuesta final.
    """
    start_time = time.time()
    logger.info("Iniciando Legal Mixture of Experts (MoE)...")
    
    user_prompt = f"Contexto y Evidencias del Caso:\n{context_str}\n\nConsulta del Letrado:\n{query}"
    
    # Run Expert 1 and Expert 2 in parallel
    task1 = asyncio.create_task(_run_agent("Agente Procesal", AGENT_PROCESAL_PROMPT, user_prompt, model))
    task2 = asyncio.create_task(_run_agent("Agente de Jurisprudencia", AGENT_JURISPRUDENCIA_PROMPT, user_prompt, model))
    
    procesal_res, juris_res = await asyncio.gather(task1, task2)
    
    # Run Synthesizer Expert
    synth_prompt = f"""Hechos originales:\n{user_prompt}
    
=== ANÁLISIS PROCESAL ===
{procesal_res}

=== ANÁLISIS DE JURISPRUDENCIA ===
{juris_res}

Por favor, elabora la estrategia final consolidada."""

    final_strategy = await _run_agent("Agente de Estrategia", AGENT_ESTRATEGIA_PROMPT, synth_prompt, model)
    
    elapsed = time.time() - start_time
    logger.info(f"Legal MoE completado en {elapsed:.2f}s")
    
    final_output = f"**🤖 Análisis Multi-Agente (MoE)**\n\n"
    final_output += f"**1. Análisis Procesal:**\n{procesal_res}\n\n"
    final_output += f"**2. Análisis de Jurisprudencia:**\n{juris_res}\n\n"
    final_output += f"**3. Estrategia Consolidada:**\n{final_strategy}"
    
    return final_output
