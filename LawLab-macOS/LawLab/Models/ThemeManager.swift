import SwiftUI

/// Enumera los 4 temas visuales premium de LawLab.
enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case cyberpunk = "Cyberpunk"
    case classicLaw = "Classic Law"
    case modernSpace = "Modern Space"
    case retroAmber = "Retro Amber"
    case macosLight = "macOS Light"
    case macosDark = "macOS Dark"
    
    var id: String { self.rawValue }
    
    /// Nombre visible en la UI.
    var displayName: String {
        switch self {
        case .cyberpunk: return "Cyberpunk Terminal"
        case .classicLaw: return "Classic Law (Sepia)"
        case .modernSpace: return "Modern Space (Gris)"
        case .retroAmber: return "Retro Amber (Fósforo)"
        case .macosLight: return "macOS Light"
        case .macosDark: return "macOS Dark"
        }
    }
    
    /// Colores asociados al tema activo.
    var colors: ThemeColors {
        switch self {
        case .cyberpunk:
            return ThemeColors(
                background: Color(red: 0.05, green: 0.06, blue: 0.09),     // Deep Dark Blue-Black
                surface: Color(red: 0.10, green: 0.12, blue: 0.18),        // Cards & Side Panel
                accent: Color(red: 0.00, green: 1.00, blue: 0.40),         // Neon Green
                accentSecondary: Color(red: 0.00, green: 0.85, blue: 1.00),// Terminal Cyan
                accentRed: Color(red: 1.00, green: 0.20, blue: 0.30),      // Vibrant Red
                textPrimary: .white,
                textSecondary: Color(red: 0.70, green: 0.73, blue: 0.80),  // Cool Gray
                textMuted: Color(red: 0.45, green: 0.47, blue: 0.55),      // Slate Gray
                textCode: Color(red: 0.00, green: 0.85, blue: 1.00)        // Cyan Code
            )
        case .classicLaw:
            return ThemeColors(
                background: Color(red: 0.98, green: 0.96, blue: 0.92),     // Warm Ivory/Sepia
                surface: Color(red: 0.94, green: 0.90, blue: 0.84),        // Warm Parchment Paper
                accent: Color(red: 0.62, green: 0.49, blue: 0.29),         // Antique Gold / Bronze
                accentSecondary: Color(red: 0.45, green: 0.32, blue: 0.18),// Rich Leather Brown
                accentRed: Color(red: 0.70, green: 0.15, blue: 0.15),      // Crimson Red
                textPrimary: Color(red: 0.15, green: 0.11, blue: 0.08),    // Deep Espresso Charcoal
                textSecondary: Color(red: 0.36, green: 0.30, blue: 0.25),  // Roasted Coffee
                textMuted: Color(red: 0.58, green: 0.52, blue: 0.46),      // Muted Clay Gray
                textCode: Color(red: 0.45, green: 0.32, blue: 0.18)        // Leather Brown Code
            )
        case .modernSpace:
            return ThemeColors(
                background: Color(red: 0.07, green: 0.07, blue: 0.09),     // Midnight Grey
                surface: Color(red: 0.14, green: 0.14, blue: 0.18),        // Space Grey
                accent: Color(red: 0.35, green: 0.34, blue: 0.84),         // Electric Indigo
                accentSecondary: Color(red: 0.00, green: 0.48, blue: 1.00),// Electric Blue
                accentRed: Color(red: 1.00, green: 0.23, blue: 0.19),      // Apple Red
                textPrimary: .white,
                textSecondary: Color(red: 0.85, green: 0.85, blue: 0.88),  // Light Gray
                textMuted: Color(red: 0.55, green: 0.55, blue: 0.58),      // Medium Gray
                textCode: Color(red: 0.00, green: 0.48, blue: 1.00)        // Electric Blue Code
            )
        case .retroAmber:
            return ThemeColors(
                background: .black,                                        // Pure Black
                surface: Color(red: 0.08, green: 0.08, blue: 0.08),        // Very Dark Charcoal
                accent: Color(red: 1.00, green: 0.69, blue: 0.00),         // Phosphorus Amber
                accentSecondary: Color(red: 1.00, green: 0.80, blue: 0.00),// Light Amber
                accentRed: Color(red: 0.90, green: 0.20, blue: 0.00),      // Dark Red
                textPrimary: Color(red: 1.00, green: 0.69, blue: 0.00),    // Amber text
                textSecondary: Color(red: 0.85, green: 0.59, blue: 0.00),  // Muted Amber
                textMuted: Color(red: 0.55, green: 0.38, blue: 0.00),      // Dark Amber
                textCode: Color(red: 1.00, green: 0.69, blue: 0.00)        // Amber Code
            )
        case .macosLight:
            return ThemeColors(
                background: Color(red: 0.96, green: 0.96, blue: 0.96),     // macOS Light Gray
                surface: Color(red: 1.00, green: 1.00, blue: 1.00),        // Pure White Card
                accent: Color(red: 0.00, green: 0.48, blue: 1.00),         // Apple Blue
                accentSecondary: Color(red: 0.10, green: 0.60, blue: 0.90),// Light Blue
                accentRed: Color(red: 1.00, green: 0.23, blue: 0.19),      // System Red
                textPrimary: Color(red: 0.10, green: 0.10, blue: 0.10),    // Dark Gray/Black
                textSecondary: Color(red: 0.35, green: 0.35, blue: 0.38),  // Muted Label Gray
                textMuted: Color(red: 0.60, green: 0.60, blue: 0.64),      // Muted Border Gray
                textCode: Color(red: 0.00, green: 0.48, blue: 1.00)        // Apple Blue Code
            )
        case .macosDark:
            return ThemeColors(
                background: Color(red: 0.12, green: 0.12, blue: 0.14),     // macOS Sequoia Dark Window
                surface: Color(red: 0.18, green: 0.18, blue: 0.20),        // Deep Charcoal
                accent: Color(red: 0.00, green: 0.50, blue: 1.00),         // Apple System Blue
                accentSecondary: Color(red: 0.20, green: 0.70, blue: 1.00),// Vibrant Bright Blue
                accentRed: Color(red: 1.00, green: 0.28, blue: 0.24),      // Bright Red
                textPrimary: .white,
                textSecondary: Color(red: 0.75, green: 0.75, blue: 0.78),  // Light Gray
                textMuted: Color(red: 0.50, green: 0.50, blue: 0.54),      // Darker Gray
                textCode: Color(red: 0.20, green: 0.70, blue: 1.00)        // Bright Blue Code
            )
        }
    }
    
    /// Estilo de fuente nativo para los textos principales.
    var fontDesign: Font.Design {
        switch self {
        case .cyberpunk, .retroAmber:
            return .monospaced
        case .classicLaw:
            return .serif
        case .modernSpace, .macosLight, .macosDark:
            return .default
        }
    }
}

/// Contenedor de colores específicos de cada tema.
struct ThemeColors {
    let background: Color
    let surface: Color
    let accent: Color
    let accentSecondary: Color
    let accentRed: Color
    let textPrimary: Color
    let textSecondary: Color
    let textMuted: Color
    let textCode: Color
}
