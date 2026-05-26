# LawLab: Asistente Jurídico Autónomo ⚖️

LawLab es un sistema integral de Inteligencia Artificial diseñado específicamente para profesionales del Derecho Laboral en España. Funciona de manera 100% local (Off-grid) garantizando la **privacidad absoluta** de los datos confidenciales de los clientes.

## 🚀 Características Principales

1. **Privacidad Total (Off-Grid)**: Todo el procesamiento de IA se ejecuta en local utilizando [Ollama](https://ollama.com/), sin enviar datos sensibles a servidores de terceros (como OpenAI o Anthropic).
2. **Orquestador Lógico de Despidos**: Un *pipeline* atómico que ingesta cartas de despido en PDF, extrae los datos clave estructurados (JSON), calcula determinísticamente las indemnizaciones según el Estatuto de los Trabajadores y redacta autónomamente el borrador de demanda o papeleta de conciliación.
3. **Auditoría RAG (Retrieval-Augmented Generation)**: Conectado a [ChromaDB](https://www.trychroma.com/), el sistema recupera fundamentos de derecho (sustantivo y procesal) en tiempo real para inyectarlos en la mente del LLM antes de redactar.
4. **Análisis Multimodal**: Soporte para ingesta de documentos PDF, imágenes periciales (Visión) y notas de voz/audio (transcripción vía Whisper).

## 🏗 Arquitectura del Sistema

LawLab está compuesto por dos piezas fundamentales:

- **Backend (Python / FastAPI)**: El "motor" del sistema. Expone una API RESTFul rápida y asíncrona. Gestiona el enrutamiento lógico, las matemáticas puras de los cálculos de indemnizaciones y la conexión con la base de datos vectorial ChromaDB y Ollama.
- **Frontend (macOS / Swift)**: El "chasis". Una aplicación nativa para Mac, ultrarrápida y con un diseño premium. Actúa como el centro de mando del abogado, permitiendo gestionar el caso, chatear con el LLM e interactuar visualmente con el *Pipeline* de Despido mediante *Drag & Drop*.

## 🛠 Instalación y Configuración

### Prerrequisitos
- macOS (Optimizado para Apple Silicon)
- [Docker](https://www.docker.com/) y Docker Compose
- [Ollama](https://ollama.com/) instalado y corriendo localmente (modelos recomendados: `llama3`, `qwen2.5:7b-instruct`)
- Python 3.10+ (opcional si se corre todo en Docker)

### Levantando el Motor (Backend)
El proyecto incluye un script automatizado que orquesta la limpieza y despliegue del backend y la base de datos ChromaDB vía Docker.

```bash
# Otorgar permisos de ejecución
chmod +x run_lawlab.sh

# Desplegar el entorno
./run_lawlab.sh
```
El servidor FastAPI estará disponible en `http://localhost:8000`. Puedes probar los endpoints interactivos en `http://localhost:8000/docs`.

### Compilando el Cliente (Frontend)
1. Abre el proyecto `.xcodeproj` ubicado en la carpeta `LawLab-macOS` con Xcode.
2. Selecciona tu Mac como destino de compilación.
3. Pulsa `Cmd + R` para compilar y ejecutar el asistente jurídico.

## 📄 Estructura del Orquestador (Pipeline)

El endpoint estrella `/api/v1/pipeline/despido` funciona en 4 fases atómicas:
1. **Ingesta**: Lee el PDF y lo transforma a texto estructurado en memoria.
2. **Extracción (Parser)**: Obliga a Ollama a retornar un esquema JSON estricto (`ExtractedCaseData`).
3. **Auditoría**: Búsqueda vectorial doble (sustantiva y procesal) en ChromaDB sobre la base jurídica española.
4. **Ejecución**: Computa los días cotizados y el "Take Profit" indemnizatorio, volcando todo en un borrador final redactado en Markdown.

---
*Desarrollado con ❤️ para transformar la práctica legal mediante la Inteligencia Artificial.*
