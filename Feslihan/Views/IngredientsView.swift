import SwiftUI

/// Reusable ingredient list component.
/// Supports both structured `Ingredient` items (with amount) and plain string lists.
struct IngredientsView: View {
    let ingredients: [Ingredient]

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
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 4)

                if index < ingredients.count - 1 {
                    Divider()
                }
            }
        }
    }
}
