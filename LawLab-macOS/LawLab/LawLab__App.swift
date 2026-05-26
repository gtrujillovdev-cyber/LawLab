import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 [App Startup] Iniciando servicios de fondo...")
        ServiceLauncher.shared.startChromaDB()
        ServiceLauncher.shared.startOllama()
        ServiceLauncher.shared.startFastAPI()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("🛑 [App Shutdown] Finalizando servicios de fondo de LawLab...")
        ServiceLauncher.shared.stopAllServices()
    }
}

@main
struct LawLab__App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = ChatViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 750, minHeight: 500)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandMenu("Fuente") {
                Button("Aumentar fuente") {
                    viewModel.fontScale = min(viewModel.fontScale + 0.1, 2.0)
                    viewModel.saveSettings()
                }
                .keyboardShortcut("+", modifiers: [.command])
                
                Button("Aumentar fuente (Teclado estándar)") {
                    viewModel.fontScale = min(viewModel.fontScale + 0.1, 2.0)
                    viewModel.saveSettings()
                }
                .keyboardShortcut("=", modifiers: [.command])
                
                Button("Disminuir fuente") {
                    viewModel.fontScale = max(viewModel.fontScale - 0.1, 0.6)
                    viewModel.saveSettings()
                }
                .keyboardShortcut("-", modifiers: [.command])
            }
        }
    }
}
