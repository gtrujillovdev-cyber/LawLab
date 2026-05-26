import Foundation

/// Administrador encargado del ciclo de vida de los servicios de fondo (Docker, Ollama y FastAPI).
class ServiceLauncher {
    static let shared = ServiceLauncher()
    
    private var fastapiProcess: Process?
    private let devWorkspacePath = "/Users/gabrieltrujillovallejo/Documents/GtrujilloMacDoc/GitHub/GitGa/Developer/Projects/LawLab"
    
    private init() {}
    
    /// Ejecuta un comando de terminal de forma síncrona y captura su salida de texto.
    @discardableResult
    private func runShell(executable: String, arguments: [String], directory: String? = nil) -> String {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let dir = directory {
            process.currentDirectoryURL = URL(fileURLWithPath: dir)
        }
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            print("⚠️ Error en comando shell: \(error.localizedDescription)")
            return ""
        }
    }
    
    /// Levanta ChromaDB en Docker en segundo plano.
    func startChromaDB() {
        let backendPath = "\(devWorkspacePath)/backend-api"
        let paths = ["/opt/homebrew/bin/docker-compose", "/usr/local/bin/docker-compose", "/usr/bin/docker-compose"]
        var dockerComposePath = "/usr/bin/docker-compose"
        
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                dockerComposePath = path
                break
            }
        }
        
        print("🐳 [Docker] Iniciando contenedor lawlab_chromadb...")
        let output = runShell(executable: dockerComposePath, arguments: ["up", "-d"], directory: backendPath)
        print("🐳 [Docker Output]: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
    
    /// Verifica e inicia el motor de Ollama si no está respondiendo.
    func startOllama() {
        let paths = ["/opt/homebrew/bin/ollama", "/usr/local/bin/ollama", "/usr/bin/ollama"]
        var ollamaPath = "/opt/homebrew/bin/ollama"
        
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                ollamaPath = path
                break
            }
        }
        
        print("🦙 [Ollama] Verificando servicio...")
        // Hacemos una llamada rápida para ver si responde. Si no, lanzamos el serve
        let checkProcess = Process()
        checkProcess.executableURL = URL(fileURLWithPath: ollamaPath)
        checkProcess.arguments = ["list"]
        
        do {
            try checkProcess.run()
            checkProcess.waitUntilExit()
            if checkProcess.terminationStatus == 0 {
                print("🦙 [Ollama] El servicio local ya está activo y respondiendo.")
                return
            }
        } catch {}
        
        print("🦙 [Ollama] Iniciando servidor serve...")
        DispatchQueue.global(qos: .background).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: ollamaPath)
            p.arguments = ["serve"]
            try? p.run()
            p.waitUntilExit()
        }
    }
    
    /// Inicia el servidor backend de FastAPI en segundo plano y monitoriza sus logs.
    func startFastAPI() {
        guard fastapiProcess == nil else {
            print("⚡ [FastAPI] El servidor ya está registrado en ejecución.")
            return
        }
        
        let backendPath = "\(devWorkspacePath)/backend-api"
        let pythonPath = "\(backendPath)/venv/bin/python"
        
        guard FileManager.default.fileExists(atPath: pythonPath) else {
            print("⚠️ [FastAPI Error] No se encontró el binario del entorno virtual venv en: \(pythonPath)")
            return
        }
        
        print("⚡ [FastAPI] Iniciando API local de Uvicorn...")
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = ["main.py"]
        process.currentDirectoryURL = URL(fileURLWithPath: backendPath)
        process.standardOutput = pipe
        process.standardError = pipe
        
        fastapiProcess = process
        
        do {
            try process.run()
            print("⚡ [FastAPI] Servidor iniciado con PID: \(process.processIdentifier)")
            
            // Leemos de forma asíncrona la salida estándar de FastAPI para imprimirla en la consola de Xcode
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                    print("[FastAPI]: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            }
        } catch {
            print("⚠️ [FastAPI Error] No se pudo iniciar el proceso: \(error.localizedDescription)")
        }
    }
    
    /// Termina de forma segura todos los procesos persistentes de fondo al cerrar la app.
    func stopAllServices() {
        print("🛑 Deteniendo todos los subprocesos de LawLab...")
        if let process = fastapiProcess, process.isRunning {
            process.terminate()
            fastapiProcess = nil
            print("⚡ [FastAPI] Servidor finalizado con éxito.")
        }
        
        // Detener contenedores Docker de ChromaDB de forma segura
        let backendPath = "\(devWorkspacePath)/backend-api"
        let paths = ["/opt/homebrew/bin/docker-compose", "/usr/local/bin/docker-compose", "/usr/bin/docker-compose"]
        var dockerComposePath = "/usr/bin/docker-compose"
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                dockerComposePath = path
                break
            }
        }
        print("🐳 [Docker] Deteniendo base de datos ChromaDB...")
        runShell(executable: dockerComposePath, arguments: ["down"], directory: backendPath)
    }
}