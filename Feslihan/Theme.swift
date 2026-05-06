import SwiftUI

// MARK: - Colors

enum DS {
    // Core
    static let cream = Color(hex: 0xFFFFFF)
    static let sand = Color(hex: 0xF5F5F5)
    static let stone = Color(hex: 0xE0E0E0)

    // Text
    static let ink = Color(hex: 0x1A1A1A)
    static let smoke = Color(hex: 0x8E8E93)
    static let dust = Color(hex: 0xC7C7CC)

    // Accent
    static let ember = Color(hex: 0x2D2D2D)
    static let emberLight = Color(hex: 0xF2F2F7)
    static let emberDark = Color(hex: 0x1A1A1A)

    // Supporting
    static let pine = Color(hex: 0x34C759)
    static let honey = Color(hex: 0xFF9500)
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
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.85))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        }
    }
}

// MARK: - Typography

extension Font {
    static func displayLarge() -> Font { .system(size: 32, weight: .semibold, design: .rounded) }
    static func displayTitle() -> Font { .system(size: 22, weight: .semibold, design: .rounded) }
    static func sectionHeader() -> Font { .system(size: 17, weight: .medium, design: .rounded) }
    static func bodyText() -> Font { .system(size: 16, weight: .regular) }
    static func label() -> Font { .system(size: 14, weight: .medium) }
    static func captionText() -> Font { .system(size: 12, weight: .regular) }
    static func buttonFont() -> Font { .system(size: 16, weight: .medium) }
}
