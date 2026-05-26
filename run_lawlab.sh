#!/bin/bash

# ==============================================================================
# LawLab - Script de Inicialización y Arranque Completo y Unificado
# ==============================================================================
# Este script inicia todos los servicios requeridos (ChromaDB en Docker, Ollama)
# y arranca tanto el backend de FastAPI como la aplicación frontend de macOS
# sincronizada con el código fuente del proyecto.
# ==============================================================================

# Colores estéticos para terminal
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0;3m' # No Color
RESET='\033[0m'

echo -e "${CYAN}"
echo "======================================================================"
echo "      ⚖️  LAWLAB NODE - INICIALIZACIÓN DE SERVICIOS LEGALES LOCALES ⚖️"
echo "======================================================================"
echo -e "${RESET}"

# Directorio base
BASE_DIR="/Users/gabrieltrujillovallejo/Documents/GtrujilloMacDoc/GitHub/GitGa/Developer/Projects/LawLab"
BACKEND_DIR="$BASE_DIR/backend-api"

# 1️⃣ Comprobar y Arrancar Docker + ChromaDB + FastAPI
echo -e "${YELLOW}[1/3] Comprobando Docker y levantando ChromaDB y FastAPI...${RESET}"
if ! docker info >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Docker no parece estar ejecutándose. Intentando abrir Docker Desktop...${RESET}"
    open -a "Docker" || open -a "Docker Desktop" 2>/dev/null
    
    echo -e "${YELLOW}Esperando a que el motor de Docker inicie (puede tardar unos segundos)...${RESET}"
    for i in {1..30}; do
        if docker info >/dev/null 2>&1; then
            echo -e "${GREEN}🐳 Docker iniciado correctamente.${RESET}"
            break
        fi
        sleep 2
    done
    
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}❌ No se pudo iniciar Docker automáticamente. Por favor ábrelo de forma manual.${RESET}"
    fi
fi

if docker info >/dev/null 2>&1; then
    # Buscar docker-compose en rutas estándar
    DOCKER_COMPOSE_PATH="docker-compose"
    for path in "/opt/homebrew/bin/docker-compose" "/usr/local/bin/docker-compose" "/usr/bin/docker-compose"; do
        if [ -f "$path" ]; then
            DOCKER_COMPOSE_PATH="$path"
            break
        fi
    done
    
    echo -e "${GREEN}🐳 Levantando contenedores en $BACKEND_DIR usando $DOCKER_COMPOSE_PATH...${RESET}"
    cd "$BACKEND_DIR" && "$DOCKER_COMPOSE_PATH" up -d
fi

# 2️⃣ Comprobar y Arrancar Ollama
echo -e "\n${YELLOW}[2/3] Comprobando motor Ollama...${RESET}"
OLLAMA_BIN="ollama"
for path in "/opt/homebrew/bin/ollama" "/usr/local/bin/ollama" "/usr/bin/ollama"; do
    if [ -f "$path" ]; then
        OLLAMA_BIN="$path"
        break
    fi
done

if "$OLLAMA_BIN" list >/dev/null 2>&1; then
    echo -e "${GREEN}🦙 El servicio de Ollama ya se encuentra activo.${RESET}"
else
    echo -e "${YELLOW}🦙 Ollama no responde. Iniciando servicio local 'ollama serve' en segundo plano...${RESET}"
    "$OLLAMA_BIN" serve > /dev/null 2>&1 &
    
    # Espera activa hasta que Ollama responda
    echo -e "${YELLOW}Esperando a que Ollama inicie...${RESET}"
    for i in {1..15}; do
        if curl -s http://localhost:11434/api/tags >/dev/null; then
            echo -e "${GREEN}🦙 Ollama iniciado correctamente.${RESET}"
            break
        fi
        sleep 1
    done
fi

# 3️⃣ Construir y Abrir la aplicación Frontend de macOS
echo -e "\n${YELLOW}[3/3] Compilando y ejecutando la app LawLab en macOS...${RESET}"
cd "$BASE_DIR"

# Compilar y obtener la ruta del binario .app
echo -e "${CYAN}🛠️  Ejecutando xcodebuild...${RESET}"
python3 -c "import subprocess; subprocess.run(['xcodebuild', '-project', 'LawLab-macOS/LawLab\x13\x01.xcodeproj', '-scheme', 'LawLab\x13\x01', '-configuration', 'Debug', '-destination', 'platform=macOS'])"

# Buscar el binario compilado de forma robusta resolviendo los caracteres invisibles en DerivedData
DERIVED_DATA_DIR="$HOME/Library/Developer/Xcode/DerivedData"
APP_PATH=$(python3 -c "
import os
derived = '$DERIVED_DATA_DIR'
for item in os.listdir(derived):
    if item.startswith('LawLab'):
        build_products = os.path.join(derived, item, 'Build/Products/Debug')
        if os.path.exists(build_products):
            for file in os.listdir(build_products):
                if file.endswith('.app'):
                    print(os.path.join(build_products, file))
                    exit(0)
")

if [ -n "$APP_PATH" ] && [ -d "$APP_PATH" ]; then
    echo -e "${GREEN}🚀 Abriendo aplicación macOS desde DerivedData: $APP_PATH${RESET}"
    open "$APP_PATH"
else
    echo -e "${RED}⚠️  No se pudo localizar el binario .app de forma automática. Intentando abrir mediante comando open genérico...${RESET}"
    open -a "LawLab" 2>/dev/null || echo -e "${RED}❌ Por favor, ejecuta la app manualmente desde Xcode o localízala en DerivedData.${RESET}"
fi

echo -e "\n${GREEN}======================================================================${RESET}"
echo -e "${GREEN}         🎉  ¡ENTORNO DE LAWLAB INICIADO Y COMPLETO CON ÉXITO!  🎉${RESET}"
echo -e "${GREEN}======================================================================${RESET}"
echo -e "Puedes presionar Ctrl+C en esta terminal para apagar el script."
echo -e "El backend FastAPI terminará de forma segura cuando cierres el script."
echo -e "======================================================================"

# Mantener activo para monitorizar logs y cerrar todo al salir
cleanup() {
    echo -e "\n${RED}🛑 Apagando servicios locales iniciados por el script...${RESET}"
    echo -e "${RED}🐳 Apagando contenedores (ChromaDB y FastAPI)...${RESET}"
    cd "$BACKEND_DIR" && docker-compose down > /dev/null 2>&1
    echo -e "${RED}🐳 Docker finalizado.${RESET}"
    
    echo -e "${GREEN}✅ Todos los servicios apagados correctamente. ¡Hasta pronto!${RESET}"
    exit 0
}

trap cleanup INT TERM

# Esperar unos segundos para que la app se abra
sleep 5

# Monitorizar la aplicación macOS
echo -e "${YELLOW}👀 Monitorizando la aplicación LawLab. Cierra la app para detener los servicios...${RESET}"
while true; do
    if ! pgrep -f "Contents/MacOS/LawLab" > /dev/null; then
        echo -e "\n${YELLOW}⚠️  Se ha cerrado la aplicación LawLab.${RESET}"
        cleanup
    fi
    sleep 3
done
