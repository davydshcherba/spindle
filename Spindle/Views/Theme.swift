import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    init(_ rgb: RGBColor) {
        self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1)
    }
}

/// Spindle's palette. Dark theme only.
enum Theme {
    /// Window background.
    static let background = Color(hex: 0x222831)
    /// Bars, cards and panels.
    static let surface = Color(hex: 0x37353E)
    static let surfaceHover = Color(hex: 0x433F4B)
    /// Recessed fields on top of a surface (search box, tab track).
    static let inset = Color.black.opacity(0.22)
    /// Play button, progress, selected tab.
    static let accent = Color(hex: 0x637545)
    static let accentHover = Color(hex: 0x70834F)
    /// For accent-coloured text and icons on dark backgrounds (current track, liked heart).
    static let accentLight = Color(hex: 0xB7C98F)
    static let text = Color(hex: 0xEEEEEE)
    static let muted = Color(hex: 0xA0A4AB)
    static let hairline = Color.white.opacity(0.08)

    static let pageInset: CGFloat = 36
}

// MARK: - Button styles

struct AccentButtonStyle: ButtonStyle {
    var height: CGFloat = 36
    var cornerRadius: CGFloat = 10

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: height)
            .background(
                configuration.isPressed ? Theme.accent.opacity(0.8) : Theme.accent,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }
}

struct OutlineButtonStyle: ButtonStyle {
    var height: CGFloat = 36

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 16)
            .frame(height: height)
            .background(configuration.isPressed ? Color.white.opacity(0.08) : .clear, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
    }
}

/// A row in a menu-like list: highlights on hover.
struct RowButtonStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                (hovering || configuration.isPressed) ? Color.white.opacity(0.08) : .clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
    }
}
