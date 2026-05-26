
import SwiftUI
import UniformTypeIdentifiers

struct PipelineView: View {
    @EnvironmentObject var networkManager: NetworkManager
    @State private var isProcessing = false
    @State private var pipelineResult: PipelineResponseDTO?
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Orquestador Lógico de Despidos")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Arrastra o selecciona el PDF de la carta de despido para calcular e iniciar el borrador.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: selectFile) {
                    Label("Cargar PDF", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            if isProcessing {
                VStack(spacing: 20) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Ejecutando Pipeline Atómico...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Extrayendo JSON, consultando ChromaDB y redactando borrador.")
                        .font(.caption)
                        .foregroundColor(.tertiaryLabel)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                    Text("Error en el Pipeline")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Spacer()
                }
            } else if let result = pipelineResult {
                HSplitView {
                    // Left Column: Data & Calculations
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            GroupBox("Resumen Ejecutivo") {
                                Text(result.summary)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            GroupBox("Datos Extraídos (JSON)") {
                                VStack(alignment: .leading, spacing: 8) {
                                    DataRow(label: "Inicio Contrato", value: result.extracted_data.start_date ?? "N/A")
                                    DataRow(label: "Fin Contrato", value: result.extracted_data.end_date ?? "N/A")
                                    DataRow(label: "Salario Mensual", value: result.extracted_data.salary != nil ? "\(result.extracted_data.salary!) €" : "N/A")
                                    DataRow(label: "Causa", value: result.extracted_data.dismissal_reason ?? "N/A")
                                    DataRow(label: "Disciplinario", value: result.extracted_data.is_disciplinary == true ? "Sí" : "No")
                                }
                                .padding(.vertical, 4)
                            }
                            
                            GroupBox("Cálculos Financieros (Take Profit)") {
                                VStack(alignment: .leading, spacing: 8) {
                                    DataRow(label: "Salario Diario", value: String(format: "%.2f €", result.calculations.daily_salary))
                                    DataRow(label: "Antigüedad", value: "\(result.calculations.total_days_worked) días")
                                    Divider()
                                    DataRow(label: "Indemnización Improcedente", value: String(format: "%.2f €", result.calculations.improcedente_final))
                                        .foregroundColor(.red)
                                    DataRow(label: "Indemnización Objetivo", value: String(format: "%.2f €", result.calculations.objetivo_final))
                                        .foregroundColor(.orange)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                    }
                    .frame(minWidth: 300, idealWidth: 350, maxWidth: 450)
                    
                    // Right Column: Draft
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Borrador Final (Generado por RAG)")
                            .font(.headline)
                            .padding()
                        
                        Divider()
                        
                        TextEditor(text: .constant(result.draft))
                            .font(.system(.body, design: .monospaced))
                            .padding()
                    }
                    .frame(minWidth: 400, maxWidth: .infinity)
                }
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 60))
                        .foregroundColor(.quaternaryLabel)
                    Text("Ningún caso activo")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            processFile(url: url)
        }
    }
    
    private func processFile(url: URL) {
        isProcessing = true
        errorMessage = nil
        pipelineResult = nil
        
        Task {
            do {
                let result = try await networkManager.runDespidoPipeline(fileURL: url)
                await MainActor.run {
                    self.pipelineResult = result
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isProcessing = false
                }
            }
        }
    }
}

struct DataRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}
