import SwiftUI

// MARK: - Colors

enum DS {
    // Backgrounds (warm paper tones)
    static let cream = Color(hex: 0xFFF8F0)       // Aged Paper
    static let sand = Color(hex: 0xF5EDE3)         // Linen
    static let stone = Color(hex: 0xEDE0D0)        // Parchment

    // Text (warm espresso tones)
    static let ink = Color(hex: 0x2C1810)          // Espresso
    static let smoke = Color(hex: 0x6B5244)        // Walnut
    static let dust = Color(hex: 0xA89585)         // Oat

    // Accent (basil green)
    static let ember = Color(hex: 0x4A7C59)        // Fresh Basil
    static let emberLight = Color(hex: 0xE8F0E4)   // Basil Tint
    static let emberDark = Color(hex: 0x2E4F38)    // Deep Herb

    // Supporting
    static let terracotta = Color(hex: 0xC67B5C)
    static let honey = Color(hex: 0xE8A838)
    static let tomato = Color(hex: 0xD94F3B)
    static let flour = Color.white

    // Shadows (warm cast-iron, never cold black)
    static let shadowCard = Color(hex: 0x2C1810, opacity: 0.06)
    static let shadowFloat = Color(hex: 0x2C1810, opacity: 0.10)
    static let shadowButton = Color(hex: 0x4A7C59, opacity: 0.22)
}

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Back Button

struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DS.ink)
                .frame(width: 38, height: 38)
                .background(DS.sand)
                .clipShape(Circle())
                .shadow(color: DS.shadowCard, radius: 4, y: 2)
        }
    }
}

// MARK: - Typography

extension Font {
    /// Page titles — warm serif, 28pt, semibold
    static func displayLarge() -> Font { .system(size: 28, weight: .semibold, design: .serif) }
    /// Section titles — serif, 22pt
    static func displayTitle() -> Font { .system(size: 22, weight: .semibold, design: .serif) }
    /// Section headers — rounded sans, 18pt, medium
    static func sectionHeader() -> Font { .system(size: 18, weight: .medium, design: .rounded) }
    /// Card titles — rounded sans, 16pt, semibold
    static func cardTitle() -> Font { .system(size: 16, weight: .semibold, design: .rounded) }
    /// Body — system sans, 15pt, regular
    static func bodyText() -> Font { .system(size: 15, weight: .regular) }
    /// Labels — rounded sans, 13pt, semibold
    static func label() -> Font { .system(size: 13, weight: .semibold, design: .rounded) }
    /// Captions — rounded sans, 11pt
    static func captionText() -> Font { .system(size: 11, weight: .medium, design: .rounded) }
    /// Button text — rounded sans, 16pt, bold
    static func buttonFont() -> Font { .system(size: 16, weight: .bold, design: .rounded) }
    /// Handwritten / decorative — serif italic, 14pt
    static func handwritten() -> Font { .system(size: 14, weight: .regular, design: .serif).italic() }
}
