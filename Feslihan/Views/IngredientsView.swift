import SwiftUI
import ClerkKit

/// Reusable ingredient list component.
/// Shows pantry status (green dot = have, red dot = need) and add-to-shopping-list button.
struct IngredientsView: View {
    let ingredients: [Ingredient]
    @State private var pantryNames: Set<String> = []
    @State private var shoppingListNames: Set<String> = []
    @State private var isLoaded = false

    init(ingredients: [Ingredient]) {
        self.ingredients = ingredients
    }

    /// Convenience init for plain string lists (e.g. shopping list / meal prep).
    init(items: [String]) {
        self.ingredients = items.map { Ingredient(name: $0, amount: "") }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Legend
            if isLoaded {
                HStack(spacing: 16) {
                    HStack(spacing: 5) {
                        Circle().fill(DS.ember).frame(width: 8, height: 8)
                        Text("Var").font(.captionText()).foregroundStyle(DS.smoke)
                    }
                    HStack(spacing: 5) {
                        Circle().fill(DS.tomato).frame(width: 8, height: 8)
                        Text("Eksik").font(.captionText()).foregroundStyle(DS.smoke)
                    }
                    Spacer()
                }
                .padding(.bottom, 10)
            }

            ForEach(Array(ingredients.enumerated()), id: \.element.id) { index, ingredient in
                let raw = ingredient.baseName ?? ingredient.name
            let key = raw.replacingOccurrences(of: "\\s*\\(.*?\\)\\s*", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces).lowercased()
                let inPantry = pantryNames.contains(key)
                let inCart = shoppingListNames.contains(key)

                HStack(spacing: 10) {
                    // Pantry status dot
                    if isLoaded {
                        Circle()
                            .fill(inPantry ? DS.ember : DS.tomato)
                            .frame(width: 9, height: 9)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(ingredient.name)
                            .font(.system(size: 15))
                            .foregroundStyle(DS.ink)
                        if !ingredient.amount.isEmpty {
                            Text(ingredient.amount)
                                .font(.system(size: 13))
                                .foregroundStyle(DS.smoke)
                        }
                    }

                    Spacer()

                    // Shopping list status
                    if isLoaded && !inPantry {
                        if inCart {
                            Image(systemName: "cart.badge.checkmark")
                                .font(.system(size: 15))
                                .foregroundStyle(DS.ember)
                        } else {
                            Button {
                                Task { await addToShoppingList(ingredient.baseName ?? ingredient.name) }
                            } label: {
                                Image(systemName: "cart.badge.plus")
                                    .font(.system(size: 15))
                                    .foregroundStyle(DS.ember)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 4)

                if index < ingredients.count - 1 {
                    Divider().padding(.leading, isLoaded ? 23 : 0)
                }
            }
        }
        .task {
            await loadPantry()
        }
    }

    private func loadPantry() async {
        guard let userId = Clerk.shared.user?.id else { return }
        async let pantryTask = APIService.fetchPantry(userId: userId)
        async let shoppingTask = APIService.fetchShoppingList(userId: userId)
        let pantryItems = await pantryTask
        let shoppingItems = await shoppingTask
        pantryNames = Set(pantryItems.map { $0.ingredient_name.lowercased() })
        shoppingListNames = Set(shoppingItems.map { $0.ingredient_name.lowercased() })
        isLoaded = true
    }

    private func addToShoppingList(_ name: String) async {
        guard let userId = Clerk.shared.user?.id else { return }
        let success = await APIService.addToShoppingList(userId: userId, ingredientNames: [name])
        if success {
            shoppingListNames.insert(name.lowercased())
        }
    }
}
