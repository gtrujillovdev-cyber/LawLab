import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @State private var hoverSend = false
    @State private var hoverAttach = false
    @State private var showSettings = false
    @State private var showTimeline = false
    @State private var showDrafting = false
    @State private var showPipeline = false
    
    /// Colores dinámicos derivados del tema activo
    private var colors: ThemeColors {
        viewModel.activeTheme.colors
    }
    
    /// Tipografía dinámica derivada del tema activo
    private var fontDesign: Font.Design {
        viewModel.activeTheme.fontDesign
    }
    
    var body: some View {
        NavigationSplitView {
            ZStack(alignment: .topLeading) {
                colors.surface.ignoresSafeArea()
                
                // SIDEBAR: Terminal Control Center & Node Health Indicators
                VStack(alignment: .leading, spacing: 20) {
                // Application Title
                HStack {
                    Image(systemName: "scale.3d")
                        .font(.title2)
                        .foregroundColor(colors.accent)
                    Text("LawLab Node")
                        .font(.system(size: 16 * viewModel.fontScale, weight: .bold, design: fontDesign))
                        .foregroundColor(colors.textPrimary)
                }
                .padding(.bottom, 10)
                
                Divider()
                    .background(colors.textMuted)
                
                // --- SECTION: SERVICE NODES STATUS (Green/Red LED) ---
                VStack(alignment: .leading, spacing: 14) {
                    Text("ESTADO DEL NODO")
                        .font(.system(size: 10 * viewModel.fontScale, weight: .semibold, design: fontDesign))
                        .foregroundColor(colors.textSecondary)
                        .tracking(1.5)
                        .padding(.bottom, 4)
                    
                    StatusRow(title: "Backend API (\(viewModel.backendHost):\(viewModel.backendPort))", isOnline: viewModel.backendOnline, theme: viewModel.activeTheme)
                    StatusRow(title: "LLM Engine (Ollama)", isOnline: viewModel.ollamaOnline, theme: viewModel.activeTheme)
                    StatusRow(title: "Vector Store (ChromaDB)", isOnline: viewModel.chromaOnline, theme: viewModel.activeTheme)
                }
                
                

                // --- SECTION: ORQUESTADOR LÓGICO ---
                VStack(alignment: .leading, spacing: 8) {
                    Text("AUTOMATIZACIÓN")
                        .font(.system(size: 10 * viewModel.fontScale, weight: .semibold, design: fontDesign))
                        .foregroundColor(colors.textSecondary)
                        .tracking(1.5)
                    
                    Button(action: {
                        showPipeline = true
                    }) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Orquestador (Pipeline)")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(colors.accent)
                    .foregroundColor(.white)
                    .font(.system(size: 11 * viewModel.fontScale, weight: .bold, design: fontDesign))
                }
                
                Divider()
                    .background(colors.textMuted)
                // --- SECTION: RAG CONTEXT MANAGER (PDF) ---
                VStack(alignment: .leading, spacing: 8) {
                    Text("INYECCIÓN DE LEYES")
                        .font(.system(size: 10 * viewModel.fontScale, weight: .semibold, design: fontDesign))
                        .foregroundColor(colors.textSecondary)
                        .tracking(1.5)
                    
                    Button(action: {
                        viewModel.attachFile(type: .pdf)
                    }) {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                            Text("Adjuntar PDF de Ley")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(colors.surface)
                    .foregroundColor(colors.accent)
                    .font(.system(size: 11 * viewModel.fontScale, weight: .bold, design: fontDesign))
                }
                
                Divider()
                    .background(colors.textMuted)
                
                // --- SECTION: CARPETA DE CASO ---
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("CARPETA DE CASO")
                            .font(.system(size: 10 * viewModel.fontScale, weight: .semibold, design: fontDesign))
                            .foregroundColor(colors.textSecondary)
                            .tracking(1.5)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.pickCaseFolder()
                        }) {
                            Image(systemName: "folder.badge.plus")
                                .font(.caption)
                                .foregroundColor(colors.accent)
                        }
                        .buttonStyle(.plain)
                        .help("Cambiar carpeta del caso")
                    }
                    
                    if let folder = viewModel.caseFolderURL {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(colors.accent)
                                Text(folder.lastPathComponent)
                                    .font(.system(size: 10 * viewModel.fontScale, weight: .semibold, design: fontDesign))
                                    .foregroundColor(colors.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.15))
                            .cornerRadius(6)
                            
                            HStack(spacing: 8) {
                                Button(action: {
                                    viewModel.processCaseFolder()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Re-procesar")
                                    }
                                    .font(.system(size: 9 * viewModel.fontScale, weight: .bold, design: fontDesign))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(colors.accent.opacity(0.15))
                                    .foregroundColor(colors.accent)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    viewModel.caseFolderURL = nil
                                    viewModel.caseContext = ""
                                    viewModel.appendSystemMessage("🗑️ **Carpeta de caso desvinculada.**")
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "folder.fill.badge.minus")
                                        Text("Desvincular")
                                    }
                                    .font(.system(size: 9 * viewModel.fontScale, weight: .bold, design: fontDesign))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(colors.accentRed.opacity(0.15))
                                    .foregroundColor(colors.accentRed)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        Text("Ninguna carpeta seleccionada.")
                            .font(.system(size: 10 * viewModel.fontScale, design: fontDesign))
                            .foregroundColor(colors.textMuted)
                    }
                }
                
                Divider()
                    .background(colors.textMuted)
                
                // --- SECTION: EVIDENCIAS MULTIMEDIA CARGADAS ---
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("EVIDENCIAS DE CASO")
                            .font(.system(size: 10 * viewModel.fontScale, weight: .semibold, design: fontDesign))
                            .foregroundColor(colors.textSecondary)
                            .tracking(1.5)
                        
                        Spacer()
                        
                        if !viewModel.uploadedEvidence.isEmpty {
                            Button(action: {
                                viewModel.clearEvidence()
                            }) {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(colors.accentRed)
                            }
                            .buttonStyle(.plain)
                            .help("Vaciar todas las evidencias")
                        }
                    }
                    
                    if viewModel.uploadedEvidence.isEmpty {
                        Text("Ninguna prueba cargada. Adjunta capturas o notas de voz abajo para analizar el caso.")
                            .font(.system(size: 10 * viewModel.fontScale, design: fontDesign))
                            .foregroundColor(colors.textMuted)
                            .padding(.vertical, 4)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(viewModel.uploadedEvidence) { item in
                                HStack(spacing: 8) {
                                    Image(systemName: item.type == .audio ? "waveform.and.mic" : (item.type == .image ? "photo" : "doc.text"))
                                        .foregroundColor(colors.accent)
                                        .frame(width: 16)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.system(size: 10 * viewModel.fontScale, weight: .semibold, design: fontDesign))
                                            .foregroundColor(colors.textPrimary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Text(item.summary)
                                            .font(.system(size: 8 * viewModel.fontScale, design: fontDesign))
                                            .foregroundColor(colors.textSecondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(6)
                                .background(Color.black.opacity(0.15))
                                .cornerRadius(6)
                            }
                        }
                        .frame(maxHeight: 180)
                        
                        // Botón para Redacción Autónoma
                        Button(action: {
                            viewModel.generateAutonomousDraft()
                        }) {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text("Redactar Demanda Autónoma")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(colors.accent)
                        .foregroundColor(viewModel.activeTheme == .classicLaw ? colors.background : .black)
                        .font(.system(size: 11 * viewModel.fontScale, weight: .bold, design: fontDesign))
                        .disabled(viewModel.isGenerating)
                        
                        // Botones de exportación si ya se redactó la demanda
                        if let draft = viewModel.draftedLawsuit {
                            VStack(spacing: 6) {
                                Button(action: {
                                    exportDraft(draft)
                                }) {
                                    HStack {
                                        Image(systemName: "doc.text")
                                        Text("Guardar Demanda (.md)")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(colors.surface)
                                .foregroundColor(colors.textCode)
                                .font(.system(size: 11 * viewModel.fontScale, design: fontDesign))
                                
                                Button(action: {
                                    PDFGenerator.exportToPDF(content: draft) { success in
                                        if success {
                                            print("PDF export succeeded")
                                        } else {
                                            print("PDF export failed")
                                        }
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "doc.richtext")
                                        Text("Exportar PDF Oficial")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(colors.accent.opacity(0.15))
                                .foregroundColor(colors.accent)
                                .font(.system(size: 11 * viewModel.fontScale, weight: .bold, design: fontDesign))
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Footer
                VStack(alignment: .leading, spacing: 4) {
                    if viewModel.injectSignature && !viewModel.lawyerName.isEmpty {
                        Text("Letrado: \(viewModel.lawyerName)")
                            .font(.system(size: 9 * viewModel.fontScale, design: fontDesign))
                            .foregroundColor(colors.textSecondary)
                    }
                    Text("LawLab v2.1 (Offline Node)")
                        .font(.system(size: 8 * viewModel.fontScale, design: .monospaced))
                        .foregroundColor(colors.textMuted)
                }
            }
            .padding()
            }
            .frame(minWidth: 220, maxWidth: 280, maxHeight: .infinity, alignment: .topLeading)
        } detail: {
            // MAIN CHAT INTERFACE
            VStack(spacing: 0) {
                // Top Header Info
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CENTRO DE CONTROL LEGAL")
                            .font(.system(size: 11 * viewModel.fontScale, weight: .bold, design: fontDesign))
                            .foregroundColor(colors.accent)
                        Text("Modelo: \(viewModel.selectedModel) | Nodo: \(viewModel.backendHost):\(viewModel.backendPort) | Tema: \(viewModel.activeTheme.rawValue)")
                            .font(.system(size: 9 * viewModel.fontScale, design: fontDesign))
                            .foregroundColor(colors.textSecondary)
                    }
                    Spacer()
                    
                    // Connection Refresh Indicator Button
                    Button(action: {
                        UserDefaults.standard.set(viewModel.backendHost, forKey: "backend_host")
                        UserDefaults.standard.set(viewModel.backendPort, forKey: "backend_port")
                        UserDefaults.standard.set(viewModel.lawyerName, forKey: "lawyer_name")
                        UserDefaults.standard.set(viewModel.lawyerId, forKey: "lawyer_id")
                        UserDefaults.standard.set(viewModel.lawyerCity, forKey: "lawyer_city")
                        UserDefaults.standard.set(viewModel.injectSignature, forKey: "inject_signature")
                        UserDefaults.standard.set(viewModel.activeTheme.rawValue, forKey: "app_theme")
                        UserDefaults.standard.set(viewModel.followSystemAppearance, forKey: "follow_system_appearance")
                        // Trigger status check immediately to reflect settings change
                        Task {
                            await viewModel.checkServicesStatus()
                        }
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .focusable(false) // Quita el anillo azul de foco de macOS permanentemente
                    .padding(6)
                    .help("Refrescar estado de servicios")
                    
                    // Clear Chat / New Conversation Button
                    Button(action: {
                        viewModel.clearChat()
                    }) {
                        Image(systemName: "plus.bubble.fill")
                            .foregroundColor(colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .focusable(false) // Quita el anillo azul de foco de macOS permanentemente
                    .padding(6)
                    .help("Iniciar nueva conversación / Limpiar chat")
                    
                    // Settings Sheet Trigger Button
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .focusable(false) // Quita el anillo azul de foco de macOS permanentemente
                    .padding(6)
                    .help("Configuración de Ajustes y Temas")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.15))
                
                Divider()
                    .background(colors.textMuted.opacity(0.3))
                
                // CHAT MESSAGE HISTORY
                ScrollViewReader { scrollViewProxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.messages) { message in
                                ChatMessageBubble(message: message, theme: viewModel.activeTheme)
                                    .id(message.id)
                            }
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 16)
                    }
                    .background(colors.background)
                    .onChange(of: viewModel.messages.count) { _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                scrollViewProxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Progress View during inference
                if viewModel.isGenerating {
                    HStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.small)
                            .colorScheme(viewModel.activeTheme == .classicLaw ? .light : .dark)
                        Text(viewModel.ingestionStatus ?? "Consultando nodo de LLM e indexando referencias legales...")
                            .font(.system(size: 10 * viewModel.fontScale, design: fontDesign))
                            .foregroundColor(colors.accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(colors.surface.opacity(0.5))
                }
                
                Divider()
                    .background(colors.textMuted.opacity(0.3))
                
                // BOTTOM INPUT BAR
                VStack(spacing: 8) {
                    HStack {
                        Toggle(isOn: Binding(get: { viewModel.useMoe }, set: { viewModel.useMoe = $0 })) {
                            Text("🤖 Activar Análisis Multi-Agente (Mixture of Experts)")
                                .font(.system(size: 11 * viewModel.fontScale, design: fontDesign))
                                .foregroundColor(viewModel.useMoe ? colors.accent : colors.textSecondary)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: colors.accent))
                        Spacer()
                    }
                    .padding(.horizontal, 4)

                HStack(spacing: 12) {
                    // Chat Input text field
                    TextField("Escribe una instrucción legal (ej. calcula el plazo para reclamar despido)...", text: $viewModel.inputMessage, onCommit: {
                        Task {
                            await viewModel.sendMessage()
                        }
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 12 * viewModel.fontScale, design: fontDesign))
                    .padding(10)
                    .background(colors.surface)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(viewModel.inputMessage.isEmpty ? Color.clear : colors.accent.opacity(0.6), lineWidth: 1)
                    )
                    .foregroundColor(colors.textPrimary)
                    .disabled(viewModel.isGenerating)
                    
                    // Attach evidence menu
                    Menu {
                        Button(action: {
                            viewModel.attachFile(type: .pdf)
                        }) {
                            Label("Legislación Laboral (PDF)", systemImage: "doc.text.fill")
                        }
                        
                        Button(action: {
                            viewModel.attachFile(type: .image)
                        }) {
                            Label("Imagen de Evidencia (Prueba)", systemImage: "photo.fill")
                        }
                        
                        Button(action: {
                            viewModel.attachFile(type: .audio)
                        }) {
                            Label("Grabación / Audio de Evidencia", systemImage: "waveform.and.mic")
                        }
                    } label: {
                        Image(systemName: "paperclip")
                            .font(.title3)
                            .foregroundColor(!viewModel.uploadedEvidence.isEmpty ? colors.accent : colors.textSecondary)
                            .padding(8)
                            .background(colors.surface)
                            .cornerRadius(8)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .help("Adjuntar archivos de legislación o evidencias multimedia")
                    
                    // Send Button
                    Button(action: {
                        Task {
                            await viewModel.sendMessage()
                        }
                    }) {
                        HStack {
                            Text("RUN")
                                .font(.system(size: 11 * viewModel.fontScale, weight: .bold, design: fontDesign))
                            Image(systemName: "play.fill")
                                .font(.system(size: 9 * viewModel.fontScale))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(viewModel.inputMessage.isEmpty || viewModel.isGenerating ? colors.surface : colors.accent)
                        .foregroundColor(viewModel.inputMessage.isEmpty || viewModel.isGenerating ? colors.textMuted : (viewModel.activeTheme == .classicLaw ? colors.background : Color.black))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.inputMessage.isEmpty || viewModel.isGenerating)
                }
                }
                .padding(14)
                .background(Color.black.opacity(0.15))
            }
            .frame(minWidth: 450)
            .background(colors.background)
        }
        .frame(minWidth: 700, minHeight: 480)
        .sheet(isPresented: $showPipeline) {
            PipelineView()
                .environmentObject(viewModel.networkManager)
                .frame(minWidth: 800, minHeight: 600)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        // MODAL DE BIENVENIDA (Invocado al iniciar si no hay carpeta activa, estilo Antigravity)
        .sheet(isPresented: .init(
            get: { viewModel.caseFolderURL == nil },
            set: { _ in }
        )) {
            WelcomeFolderSelectorView()
        }
        .preferredColorScheme(viewModel.followSystemAppearance ? nil : (viewModel.activeTheme == .classicLaw ? .light : .dark))
    }
    
    /// Exporta el borrador Markdown redactado de la demanda a un archivo local.
    private func exportDraft(_ content: String) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.utf8PlainText, UTType(filenameExtension: "md")].compactMap { $0 }
        savePanel.nameFieldStringValue = "Demanda_Laboral_LawLab.md"
        savePanel.title = "Guardar Borrador de Demanda"
        savePanel.message = "Selecciona el directorio para exportar el escrito procesal generado en Markdown."
        
        if savePanel.runModal() == .OK {
            if let url = savePanel.url {
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Error writing draft: \(error)")
                }
            }
        }
    }
}

// --- HELPER COMPONENT: Status Row LED ---
struct StatusRow: View {
    let title: String
    let isOnline: Bool
    let theme: AppTheme
    @EnvironmentObject var viewModel: ChatViewModel
    
    // Semaforo con colores claros estándar (Verde Vibrante / Rojo Intenso) para todos los temas
    private var ledColor: Color {
        isOnline ? Color(red: 0.00, green: 0.90, blue: 0.35) : Color(red: 1.00, green: 0.15, blue: 0.25)
    }
    
    private var colors: ThemeColors {
        theme.colors
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(ledColor)
                .frame(width: 8 * viewModel.fontScale, height: 8 * viewModel.fontScale)
                .shadow(color: ledColor, radius: 4)
            
            Text(title)
                .font(.system(size: 11 * viewModel.fontScale, design: theme.fontDesign))
                .foregroundColor(colors.textPrimary)
            
            Spacer()
        }
    }
}

// --- HELPER COMPONENT: Chat Message Bubble ---
struct ChatMessageBubble: View {
    let message: Message
    let theme: AppTheme
    @EnvironmentObject var viewModel: ChatViewModel
    @State private var showReferences = false
    
    private var colors: ThemeColors {
        theme.colors
    }
    
    private var fontDesign: Font.Design {
        theme.fontDesign
    }
    
    var body: some View {
        HStack(alignment: .top) {
            if message.role == .user {
                Spacer(minLength: 40)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .font(.system(size: 12 * viewModel.fontScale, design: fontDesign))
                        .padding(12)
                        .background(colors.surface)
                        .foregroundColor(colors.textPrimary)
                        .cornerRadius(12, bottomRight: false)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(colors.textMuted.opacity(0.3), lineWidth: 1)
                        )
                    
                    Text("USUARIO • \(formattedTime(message.timestamp))")
                        .font(.system(size: 8 * viewModel.fontScale, design: .monospaced))
                        .foregroundColor(colors.textMuted)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    // Assistant Main Text Bubble
                    VStack(alignment: .leading, spacing: 8) {
                        Text(.init(message.content.formatFactCheckingTags())) // Renders markdown natively!
                            .font(.system(size: 12 * viewModel.fontScale, design: fontDesign))
                            .lineSpacing(4)
                            .foregroundColor(colors.textSecondary)
                        
                        // Metadata (Model & time elapsed)
                        if let duration = message.duration {
                            Divider()
                                .background(colors.textMuted.opacity(0.3))
                                .padding(.top, 4)
                            
                            HStack {
                                Text("PROCESSED BY LLM IN \(String(format: "%.2f", duration))s")
                                    .font(.system(size: 8 * viewModel.fontScale, design: .monospaced))
                                    .foregroundColor(colors.accent.opacity(0.7))
                                Spacer()
                            }
                        }
                    }
                    .padding(12)
                    .background(colors.surface.opacity(0.4))
                    .cornerRadius(12, bottomLeft: false)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(colors.accent.opacity(0.2), lineWidth: 1)
                    )
                    
                    // RAG References Accordion (Collapsible drawer)
                    if let contextList = message.contextUsed {
                        VStack(alignment: .leading, spacing: 6) {
                            Button(action: {
                                withAnimation {
                                    showReferences.toggle()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: showReferences ? "chevron.down.square.fill" : "chevron.right.square.fill")
                                        .foregroundColor(colors.textCode)
                                    Text("REFERENCIAS DE BASE VECTORIAL (\(contextList.count) Citas)")
                                        .font(.system(size: 9 * viewModel.fontScale, weight: .bold, design: .monospaced))
                                        .foregroundColor(colors.textCode)
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 2)
                            
                            if showReferences {
                                ForEach(0..<contextList.count, id: \.self) { idx in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Ley/Estatuto - Cita \(idx + 1)")
                                            .font(.system(size: 8 * viewModel.fontScale, weight: .bold, design: .monospaced))
                                            .foregroundColor(colors.textPrimary)
                                        Text(contextList[idx])
                                            .font(.system(size: 10 * viewModel.fontScale, design: theme.fontDesign))
                                            .foregroundColor(colors.textSecondary)
                                            .padding(8)
                                            .background(colors.surface)
                                            .cornerRadius(6)
                                    }
                                    .padding(.leading, 12)
                                }
                            }
                        }
                    }
                    
                    Text("NODO LEGAL • \(formattedTime(message.timestamp))")
                        .font(.system(size: 8 * viewModel.fontScale, design: .monospaced))
                        .foregroundColor(colors.textMuted)
                        .padding(.top, 2)
                }
                
                Spacer(minLength: 40)
            }
        }
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// --- HELPER COMPONENT: SettingsView Modal Sheet ---
struct SettingsView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var localHost: String = ""
    @State private var localPort: String = ""
    @State private var localTheme: AppTheme = .cyberpunk
    @State private var localName: String = ""
    @State private var localId: String = ""
    @State private var localCity: String = ""
    @State private var localInject: Bool = false
    @State private var localFollowSystem: Bool = true
    
    private var colors: ThemeColors {
        localTheme.colors
    }
    
    private var fontDesign: Font.Design {
        localTheme.fontDesign
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
                    .foregroundColor(colors.accent)
                Text("Ajustes del Sistema y Perfil")
                    .font(.system(size: 16 * viewModel.fontScale, weight: .bold, design: fontDesign))
                    .foregroundColor(colors.textPrimary)
                Spacer()
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(colors.textMuted)
                    .onTapGesture {
                        viewModel.connectionTestResult = nil
                        dismiss() 
                    }
                    .padding(4)
            }
            .padding()
            .background(colors.surface)
            
            Divider()
                .background(colors.textMuted.opacity(0.3))
            
            ScrollView {
                VStack(spacing: 20) {
                    // SECTION 1: THEME SELECTION
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SELECCIÓN DE TEMA VISUAL")
                            .font(.system(size: 10 * viewModel.fontScale, weight: .bold, design: fontDesign))
                            .foregroundColor(colors.textSecondary)
                            .tracking(1.5)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(AppTheme.allCases) { theme in
                                Button(action: {
                                    withAnimation {
                                        localTheme = theme
                                    }
                                }) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Circle()
                                                .fill(theme.colors.accent)
                                                .frame(width: 10 * viewModel.fontScale, height: 10 * viewModel.fontScale)
                                            Circle()
                                                .fill(theme.colors.accentSecondary)
                                                .frame(width: 10 * viewModel.fontScale, height: 10 * viewModel.fontScale)
                                            Spacer()
                                            if localTheme == theme {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(theme.colors.accent)
                                            }
                                        }
                                        
                                        Text(theme.displayName)
                                            .font(.system(size: 11 * viewModel.fontScale, weight: .bold, design: theme.fontDesign))
                                            .foregroundColor(theme.colors.textPrimary)
                                        
                                        Text(theme == .classicLaw ? "Tipografía Serif y tonos sepia." : "Monospaced / Sans moderno.")
                                            .font(.system(size: 8 * viewModel.fontScale, design: theme.fontDesign))
                                            .foregroundColor(theme.colors.textSecondary)
                                    }
                                    .padding(10)
                                    .background(theme.colors.background)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(localTheme == theme ? theme.colors.accent : Color.clear, lineWidth: 2)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                    .background(colors.surface)
                    .cornerRadius(10)
                    
                    // SECTION 2: CONNECTION ADJUSTMENTS
                    VStack(alignment: .leading, spacing: 12) {
                        Text("CONEXIÓN DE NODO RED (FASTAPI)")
                            .font(.system(size: 10 * viewModel.fontScale, weight: .bold, design: fontDesign))
                            .foregroundColor(colors.textSecondary)
                            .tracking(1.5)
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("HOST")
                                    .font(.system(size: 8 * viewModel.fontScale, weight: .bold, design: fontDesign))
                                    .foregroundColor(colors.textMuted)
                                TextField("localhost", text: $localHost)
                                    .textFieldStyle(.plain)
                                    .padding(8)
                                    .background(colors.background)
                                    .cornerRadius(6)
                                    .foregroundColor(colors.textPrimary)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("PUERTO")
                                    .font(.system(size: 8 * viewModel.fontScale, weight: .bold, design: fontDesign))
                                    .foregroundColor(colors.textMuted)
                                TextField("8000", text: $localPort)
                                    .textFieldStyle(.plain)
                                    .padding(8)
                                    .background(colors.background)
                                    .cornerRadius(6)
                                    .foregroundColor(colors.textPrimary)
                            }
                        }
                        
                        // Active ping test
                        HStack {
                            Button(action: {
                                viewModel.testCustomConnection(host: localHost, port: localPort)
                            }) {
                                HStack(spacing: 6) {
                                    if viewModel.isTestingConnection {
                                        ProgressView()
                                            .controlSize(.small)
                                            .colorScheme(localTheme == .classicLaw ? .light : .dark)
                                    } else {
                                        Image(systemName: "wifi")
                                    }
                                    Text("Probar Conexión")
                                }
                                .font(.system(size: 10 * viewModel.fontScale, weight: .bold, design: fontDesign))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(colors.accent.opacity(0.15))
                                .foregroundColor(colors.accent)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isTestingConnection)
                            
                            Spacer()
                            
                            if let result = viewModel.connectionTestResult {
                                Text(result)
                                    .font(.system(size: 9 * viewModel.fontScale, weight: .bold, design: fontDesign))
                                    .foregroundColor(result.contains("❌") ? colors.accentRed : colors.accent)
                            }
                        }
                    }
                    .padding()
                    .background(colors.surface)
                    .cornerRadius(10)
                    
                    // SECTION 3: LAWYER PROFILE SIGNATURE
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("PERFIL DE FIRMA DE ABOGADO")
                                .font(.system(size: 10 * viewModel.fontScale, weight: .bold, design: fontDesign))
                                .foregroundColor(colors.textSecondary)
                                .tracking(1.5)
                            
                            Spacer()
                            
                            Toggle("", isOn: $localInject)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                        
                        if localInject {
                            VStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("NOMBRE COMPLETO DEL LETRADO")
                                        .font(.system(size: 8 * viewModel.fontScale, weight: .bold, design: fontDesign))
                                        .foregroundColor(colors.textMuted)
                                    TextField("Ej: Gabriel Trujillo Vallejo", text: $localName)
                                        .textFieldStyle(.plain)
                                        .padding(8)
                                        .background(colors.background)
                                        .cornerRadius(6)
                                        .foregroundColor(colors.textPrimary)
                                }
                                
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Nº DE COLEGIADO")
                                            .font(.system(size: 8 * viewModel.fontScale, weight: .bold, design: fontDesign))
                                            .foregroundColor(colors.textMuted)
                                        TextField("Ej: 45892", text: $localId)
                                            .textFieldStyle(.plain)
                                            .padding(8)
                                            .background(colors.background)
                                            .cornerRadius(6)
                                            .foregroundColor(colors.textPrimary)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("CIUDAD / COLEGIO")
                                            .font(.system(size: 8 * viewModel.fontScale, weight: .bold, design: fontDesign))
                                            .foregroundColor(colors.textMuted)
                                        TextField("Ej: Madrid", text: $localCity)
                                            .textFieldStyle(.plain)
                                            .padding(8)
                                            .background(colors.background)
                                            .cornerRadius(6)
                                            .foregroundColor(colors.textPrimary)
                                    }
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding()
                    .background(colors.surface)
                    .cornerRadius(10)
                    
                    // Fin de la configuración del sistema
                }
                .padding()
            }
            .background(colors.background)
            
            Divider()
                .background(colors.textMuted.opacity(0.3))
            
            // Footer buttons
            HStack(spacing: 16) {
                Spacer()
                Button("Cancelar") {
                    viewModel.connectionTestResult = nil
                    dismiss()
                }
                .buttonStyle(.bordered)
                .foregroundColor(colors.textSecondary)
                
                Button("Guardar Ajustes") {
                    viewModel.backendHost = localHost
                    viewModel.backendPort = localPort
                    viewModel.activeTheme = localTheme
                    viewModel.lawyerName = localName
                    viewModel.lawyerId = localId
                    viewModel.lawyerCity = localCity
                    viewModel.injectSignature = localInject
                    viewModel.followSystemAppearance = localFollowSystem
                    viewModel.saveSettings()
                    
                    viewModel.connectionTestResult = nil
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(colors.accent)
                .foregroundColor(localTheme == .classicLaw ? colors.background : .black)
                .font(.system(size: 12 * viewModel.fontScale, weight: .bold, design: fontDesign))
            }
            .padding()
            .background(colors.surface)
        }
        .frame(width: 480, height: 500)
        .onAppear {
            localHost = viewModel.backendHost
            localPort = viewModel.backendPort
            localTheme = viewModel.activeTheme
            localName = viewModel.lawyerName
            localId = viewModel.lawyerId
            localCity = viewModel.lawyerCity
            localInject = viewModel.injectSignature
            localFollowSystem = viewModel.followSystemAppearance
        }
    }
}

// --- HELPER COMPONENT: WelcomeFolderSelectorView (Estilo Antigravity) ---
struct WelcomeFolderSelectorView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    
    private var colors: ThemeColors {
        viewModel.activeTheme.colors
    }
    
    private var fontDesign: Font.Design {
        viewModel.activeTheme.fontDesign
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icono premium flotante
            ZStack {
                Circle()
                    .fill(colors.accent.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 36))
                    .foregroundColor(colors.accent)
            }
            .padding(.bottom, 10)
            
            VStack(spacing: 8) {
                Text("Bienvenido a LawLab Node")
                    .font(.system(size: 20 * viewModel.fontScale, weight: .bold, design: fontDesign))
                    .foregroundColor(colors.textPrimary)
                
                Text("Asistente Jurídico Autónomo y Multimodal")
                    .font(.system(size: 11 * viewModel.fontScale, weight: .semibold, design: fontDesign))
                    .foregroundColor(colors.accentSecondary)
                    .tracking(1.5)
            }
            
            Text("Para comenzar a trabajar y dar a la IA contexto local completo de tu caso, selecciona el directorio o carpeta raíz que contenga todas las evidencias del expediente (archivos PDFs de leyes, imágenes periciales, grabaciones de voz).")
                .font(.system(size: 11 * viewModel.fontScale, design: fontDesign))
                .foregroundColor(colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 24)
            
            Spacer()
            
            Divider()
                .background(colors.textMuted.opacity(0.3))
            
            VStack(spacing: 12) {
                Button(action: {
                    viewModel.pickCaseFolder()
                }) {
                    HStack {
                        Image(systemName: "folder.fill.badge.plus")
                            .font(.headline)
                        Text("Vincular Carpeta del Caso")
                            .font(.system(size: 12 * viewModel.fontScale, weight: .bold, design: fontDesign))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(colors.accent)
                    .foregroundColor(viewModel.activeTheme == .classicLaw ? colors.background : Color.black)
                    .cornerRadius(8)
                    .shadow(color: colors.accent.opacity(0.3), radius: 6)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                
                Button(action: {
                    // Cargar una carpeta temporal / por defecto en sandbox si el usuario prefiere omitir
                    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("LawLab_EmptyCase")
                    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                    viewModel.caseFolderURL = tempDir
                    viewModel.caseContext = ""
                    viewModel.appendSystemMessage("⚖️ **Iniciado en modo de chat general.**")
                }) {
                    Text("Omitir y usar chat sin carpeta")
                        .font(.system(size: 10 * viewModel.fontScale, design: fontDesign))
                        .foregroundColor(colors.textMuted)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 16)
            }
            .background(colors.surface)
        }
        .frame(width: 460, height: 480)
        .background(colors.background)
    }
}

// SwiftUI custom corners helper
extension View {
    func cornerRadius(_ radius: CGFloat, topLeft: Bool = true, topRight: Bool = true, bottomLeft: Bool = true, bottomRight: Bool = true) -> some View {
        clipShape(RoundedCorner(radius: radius, topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var topLeft: Bool = true
    var topRight: Bool = true
    var bottomLeft: Bool = true
    var bottomRight: Bool = true

    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Make sure radius is within bounds
        let tr = topRight ? min(min(self.radius, height/2), width/2) : 0
        let tl = topLeft ? min(min(self.radius, height/2), width/2) : 0
        let bl = bottomLeft ? min(min(self.radius, height/2), width/2) : 0
        let br = bottomRight ? min(min(self.radius, height/2), width/2) : 0
        
        path.move(to: CGPoint(x: width / 2, y: 0))
        
        // Top right corner
        if topRight {
            path.addLine(to: CGPoint(x: width - tr, y: 0))
            path.addArc(center: CGPoint(x: width - tr, y: tr), radius: tr,
                        startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)
        } else {
            path.addLine(to: CGPoint(x: width, y: 0))
        }
        
        // Bottom right corner
        if bottomRight {
            path.addLine(to: CGPoint(x: width, y: height - br))
            path.addArc(center: CGPoint(x: width - br, y: height - br), radius: br,
                        startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
        } else {
            path.addLine(to: CGPoint(x: width, y: height))
        }
        
        // Bottom left corner
        if bottomLeft {
            path.addLine(to: CGPoint(x: bl, y: height))
            path.addArc(center: CGPoint(x: bl, y: height - bl), radius: bl,
                        startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
        } else {
            path.addLine(to: CGPoint(x: 0, y: height))
        }
        
        // Top left corner
        if topLeft {
            path.addLine(to: CGPoint(x: 0, y: tl))
            path.addArc(center: CGPoint(x: tl, y: tl), radius: tl,
                        startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)
        } else {
            path.addLine(to: CGPoint(x: 0, y: 0))
        }
        
        path.closeSubpath()
        return path
    }
}


extension String {
    /// Replaces backend fact-checking tags with native markdown badges for SwiftUI rendering.
    func formatFactCheckingTags() -> String {
        return self
            .replacingOccurrences(of: #"\[VALID_DOC:(.*?)\]"#, with: " **✅ [Fuente: ]**", options: .regularExpression)
            .replacingOccurrences(of: #"\[INVALID_DOC:(.*?)\]"#, with: " **❌ [Alucinación: ]**", options: .regularExpression)
    }
}
