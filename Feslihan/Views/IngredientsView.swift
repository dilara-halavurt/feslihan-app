import SwiftUI

/// Reusable ingredient list component.
/// Supports both structured `Ingredient` items (with amount) and plain string lists.
struct IngredientsView: View {
    let ingredients: [Ingredient]
    @State private var priceTiers: [String: String] = [:]
    @State private var availabilityIcons: [String: String] = [:]

    init(ingredients: [Ingredient]) {
        self.ingredients = ingredients
    }

    /// Convenience init for plain string lists (e.g. shopping list / meal prep).
    init(items: [String]) {
        self.ingredients = items.map { Ingredient(name: $0, amount: "") }
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(ingredients.enumerated()), id: \.element.id) { index, ingredient in
                HStack(spacing: 12) {
                    if !ingredient.amount.isEmpty {
                        Text(ingredient.amount)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DS.smoke)
                            .frame(width: 80, alignment: .leading)
                    }

                    Text(ingredient.name)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(DS.ink)

                    Spacer()

                    if let icon = availabilityIcons[ingredient.name.lowercased()] {
                        Image(systemName: icon)
                            .font(.system(size: 13))
                            .foregroundStyle(availabilityColor(icon))
                    }

                    if let tier = priceTiers[ingredient.name.lowercased()] {
                        Text(tier)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(priceTierColor(tier))
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 4)

                if index < ingredients.count - 1 {
                    Divider()
                }
            }
        }
        .task {
            let allIngredients = await APIService.fetchIngredients()
            var tiers: [String: String] = [:]
            var icons: [String: String] = [:]
            for dto in allIngredients {
                if let emoji = dto.priceTierEmoji {
                    tiers[dto.name.lowercased()] = emoji
                }
                if let icon = dto.availabilityIcon {
                    icons[dto.name.lowercased()] = icon
                }
            }
            priceTiers = tiers
            availabilityIcons = icons
        }
    }

    private func priceTierColor(_ tier: String) -> Color {
        switch tier {
        case "₺": return Color(hex: 0x2D6A4F)
        case "₺₺": return DS.smoke
        case "₺₺₺": return Color(hex: 0xC0392B)
        default: return DS.smoke
        }
    }

    private func availabilityColor(_ icon: String) -> Color {
        switch icon {
        case "checkmark.circle": return Color(hex: 0x2D6A4F)
        case "minus.circle": return DS.smoke
        case "exclamationmark.circle": return Color(hex: 0xE67E22)
        default: return DS.smoke
        }
    }
}
