import Foundation
import WebKit
import UniformTypeIdentifiers

@MainActor
class PDFGenerator: NSObject, WKNavigationDelegate {
    private static var activeGenerator: PDFGenerator? // To prevent deallocation
    
    private let htmlContent: String
    private let destinationURL: URL
    private var webView: WKWebView?
    private let completion: (Bool) -> Void
    
    private init(htmlContent: String, destinationURL: URL, completion: @escaping (Bool) -> Void) {
        self.htmlContent = htmlContent
        self.destinationURL = destinationURL
        self.completion = completion
        super.init()
    }
    
    static func exportToPDF(content: String, completion: @escaping (Bool) -> Void) {
        // 1. Run NSSavePanel
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.pdf].compactMap { $0 }
        savePanel.nameFieldStringValue = "Demanda_Laboral_LawLab.pdf"
        savePanel.title = "Guardar Demanda Oficial (PDF)"
        savePanel.message = "Selecciona la ruta para exportar el escrito judicial en formato PDF oficial de maquetación española."
        
        guard savePanel.runModal() == .OK, let destinationURL = savePanel.url else {
            completion(false)
            return
        }
        
        let htmlContent = convertMarkdownToSpanishLegalHTML(content)
        
        let generator = PDFGenerator(htmlContent: htmlContent, destinationURL: destinationURL, completion: completion)
        activeGenerator = generator
        
        generator.start()
    }
    
    private func start() {
        let webViewConfiguration = WKWebViewConfiguration()
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 595, height: 842), configuration: webViewConfiguration)
        self.webView = web
        web.navigationDelegate = self
        web.loadHTMLString(htmlContent, baseURL: nil)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Give it a tiny delay to fully render styling and fonts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let pdfConfig = WKPDFConfiguration()
            webView.createPDF(configuration: pdfConfig) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let data):
                    do {
                        try data.write(to: self.destinationURL)
                        print("PDF successfully saved to: \(self.destinationURL)")
                        self.completion(true)
                    } catch {
                        print("Failed to write PDF: \(error)")
                        self.completion(false)
                    }
                case .failure(let error):
                    print("Failed to generate PDF: \(error)")
                    self.completion(false)
                }
                PDFGenerator.activeGenerator = nil // Cleanup
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("Webview failed navigation: \(error)")
        self.completion(false)
        PDFGenerator.activeGenerator = nil
    }
    
    private static func convertMarkdownToSpanishLegalHTML(_ markdown: String) -> String {
        // Simple and robust parser for Spanish Legal styling
        var bodyHTML = ""
        
        // Split by paragraph blocks
        let blocks = markdown.components(separatedBy: "\n\n")
        var inList = false
        
        for block in blocks {
            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            // Check headers
            if trimmed.hasPrefix("###") {
                if inList { bodyHTML += "</ul>\n"; inList = false }
                let text = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
                let cleanedText = cleanEmojis(text)
                bodyHTML += "<h3>\(cleanedText)</h3>\n"
            } else if trimmed.hasPrefix("##") {
                if inList { bodyHTML += "</ul>\n"; inList = false }
                let text = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
                let cleanedText = cleanEmojis(text)
                bodyHTML += "<h2>\(cleanedText)</h2>\n"
            } else if trimmed.hasPrefix("#") {
                if inList { bodyHTML += "</ul>\n"; inList = false }
                let text = trimmed.dropFirst(1).trimmingCharacters(in: .whitespaces)
                let cleanedText = cleanEmojis(text)
                bodyHTML += "<h1>\(cleanedText)</h1>\n"
            }
            // Check list items
            else if trimmed.hasPrefix("-") || trimmed.hasPrefix("*") {
                if !inList { bodyHTML += "<ul>\n"; inList = true }
                let itemText = trimmed.dropFirst(1).trimmingCharacters(in: .whitespaces)
                let parsedItem = parseInlines(itemText)
                bodyHTML += "<li>\(parsedItem)</li>\n"
            }
            // Check dividers
            else if trimmed == "---" {
                if inList { bodyHTML += "</ul>\n"; inList = false }
                bodyHTML += "<hr />\n"
            }
            // Check traditional spanish court headers
            else if trimmed.uppercased().hasPrefix("AL JUZGADO") || trimmed.uppercased().hasPrefix("AL SERVICIO") || trimmed.uppercased().hasPrefix("A LA DELEGACIÓN") {
                if inList { bodyHTML += "</ul>\n"; inList = false }
                bodyHTML += "<div class=\"court-header\">\(trimmed.uppercased())</div>\n"
            }
            // Default paragraph
            else {
                if inList { bodyHTML += "</ul>\n"; inList = false }
                let parsedText = parseInlines(trimmed)
                bodyHTML += "<p>\(parsedText)</p>\n"
            }
        }
        
        if inList { bodyHTML += "</ul>\n" }
        
        // Add signature blocks if we have "SUPLICO" or at the end
        let signatureHTML = """
        <table class="signature-table">
            <tr>
                <td class="signature-cell">
                    <div class="signature-line"></div>
                    <strong>Fdo.: El/La Letrado/a o Representante</strong><br/>
                    Defensa Técnica del Trabajador
                </td>
                <td class="signature-cell">
                    <div class="signature-line"></div>
                    <strong>Fdo.: El/La Demandante</strong><br/>
                    D./Dña. [Nombre del Trabajador]
                </td>
            </tr>
        </table>
        """
        bodyHTML += signatureHTML
        
        // Return full document template with legal CSS stylesheet
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        @page {
            size: A4;
            margin: 3cm 2.5cm 3cm 3cm; /* Margins: Top 3cm, Right 2.5cm, Bottom 3cm, Left 3cm */
        }
        body {
            font-family: "Georgia", "Times New Roman", Times, serif;
            font-size: 12pt;
            line-height: 1.6;
            color: #000;
            background-color: #fff;
            margin: 0;
            padding: 0;
            text-align: justify;
        }
        h1, h2, h3 {
            font-family: "Georgia", "Times New Roman", Times, serif;
            color: #000;
            text-align: center;
            text-transform: uppercase;
            font-weight: bold;
            margin-top: 1.5em;
            margin-bottom: 0.8em;
            letter-spacing: 0.05em;
        }
        h1 {
            font-size: 14pt;
        }
        h2 {
            font-size: 13pt;
        }
        h3 {
            font-size: 12pt;
            text-align: left;
            text-decoration: underline;
            text-transform: none;
            margin-top: 1.2em;
        }
        p {
            margin-top: 0;
            margin-bottom: 1.2em;
            text-indent: 1.5cm; /* Sangría española tradicional */
        }
        ul, ol {
            margin-top: 0;
            margin-bottom: 1.2em;
            padding-left: 2cm;
        }
        li {
            margin-bottom: 0.5em;
            text-indent: 0;
        }
        hr {
            border: none;
            border-top: 1px solid #000;
            margin: 2em 0;
        }
        .court-header {
            font-weight: bold;
            text-align: left;
            margin-top: 1em;
            margin-bottom: 2em;
            text-indent: 0;
            text-transform: uppercase;
            border-bottom: 2px solid #000;
            padding-bottom: 0.5em;
            font-size: 12pt;
            letter-spacing: 0.03em;
        }
        .placeholder {
            border-bottom: 1px solid #000;
            font-weight: bold;
            background-color: rgba(0, 0, 0, 0.05);
            padding: 0 4px;
        }
        .signature-table {
            width: 100%;
            margin-top: 4em;
            border-collapse: collapse;
            page-break-inside: avoid;
        }
        .signature-cell {
            width: 50%;
            text-align: center;
            font-size: 11pt;
            vertical-align: top;
            border: none;
        }
        .signature-line {
            width: 70%;
            margin: 4em auto 1em auto;
            border-top: 1px dashed #000;
        }
        </style>
        </head>
        <body>
        <div class="content">
            \(bodyHTML)
        </div>
        </body>
        </html>
        """
    }
    
    private static func parseInlines(_ text: String) -> String {
        var parsed = text
        // Replace bold **text**
        let boldPattern = "\\*\\*(.*?)\\*\\*"
        if let regex = try? NSRegularExpression(pattern: boldPattern, options: []) {
            let range = NSRange(parsed.startIndex..<parsed.endIndex, in: parsed)
            parsed = regex.stringByReplacingMatches(in: parsed, options: [], range: range, withTemplate: "<strong>$1</strong>")
        }
        // Replace placeholders [TEXT] with elegant span highlight
        let placeholderPattern = "\\[([^\\]]+)\\]"
        if let regex = try? NSRegularExpression(pattern: placeholderPattern, options: []) {
            let range = NSRange(parsed.startIndex..<parsed.endIndex, in: parsed)
            parsed = regex.stringByReplacingMatches(in: parsed, options: [], range: range, withTemplate: "<span class=\"placeholder\">$0</span>")
        }
        return parsed
    }
    
    private static func cleanEmojis(_ text: String) -> String {
        var cleaned = ""
        for scalar in text.unicodeScalars {
            if scalar.properties.isEmoji && scalar.value > 0x2000 {
                continue
            }
            cleaned.append(String(scalar))
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
