import SwiftUI

struct MealEditSheet: View {
    let meal: MealPlanMeal
    let userRecipes: [RecipeDTO]
    let recipeById: [String: RecipeDTO]
    let onSave: (MealPlanMeal) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var mainRecipeId: String?
    @State private var sideRecipeIds: [String]
    @State private var mealType: String
    @State private var showRecipePicker = false
    @State private var pickingFor: PickTarget = .main

    enum PickTarget {
        case main
        case side(Int)
        case newSide
    }

    private let mealTypes: [(icon: String, label: String)] = [
        ("sunrise.fill", "Kahvaltı"),
        ("sun.max.fill", "Öğle"),
        ("moon.fill", "Akşam"),
        ("fork.knife", "Atıştırmalık"),
    ]

    private var isNewMeal: Bool { meal.recipeIds.isEmpty }

    init(meal: MealPlanMeal, userRecipes: [RecipeDTO], recipeById: [String: RecipeDTO] = [:], onSave: @escaping (MealPlanMeal) -> Void) {
        self.meal = meal
        self.userRecipes = userRecipes
        self.recipeById = recipeById
        self.onSave = onSave
        _mainRecipeId = State(initialValue: meal.recipeIds.first)
        _sideRecipeIds = State(initialValue: Array(meal.recipeIds.dropFirst()))
        _mealType = State(initialValue: meal.mealType)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.cream.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text(isNewMeal ? "Öğün Ekle" : "Öğün Düzenle")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(DS.ink)
                            if !isNewMeal {
                                let currentName = meal.recipeIds.compactMap { recipeById[$0]?.title }.joined(separator: " + ")
                                Text(currentName)
                                    .font(.system(size: 14))
                                    .foregroundStyle(DS.smoke)
                            }
                        }

                        // Main recipe
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ana Tarif")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(DS.ink)

                            Button {
                                pickingFor = .main
                                showRecipePicker = true
                            } label: {
                                HStack {
                                    if let id = mainRecipeId, let recipe = recipeById[id] {
                                        Text(recipe.title)
                                            .font(.system(size: 15))
                                            .foregroundStyle(DS.ink)
                                    } else {
                                        Text("Tarif seç…")
                                            .font(.system(size: 15))
                                            .foregroundStyle(DS.dust)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(DS.dust)
                                }
                                .padding(14)
                                .background(DS.sand)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }

                        // Side recipes
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Ek Tarifler")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(DS.ink)
                                Spacer()
                                Button {
                                    pickingFor = .newSide
                                    showRecipePicker = true
                                } label: {
                                    Text("+ Ekle")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(DS.ember)
                                }
                            }

                            if sideRecipeIds.isEmpty {
                                Text("Henüz ek tarif eklenmedi")
                                    .font(.system(size: 13))
                                    .foregroundStyle(DS.dust)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(Array(sideRecipeIds.enumerated()), id: \.offset) { index, id in
                                    HStack {
                                        Text(recipeById[id]?.title ?? id)
                                            .font(.system(size: 15))
                                            .foregroundStyle(DS.ink)
                                        Spacer()
                                        Button {
                                            sideRecipeIds.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 16))
                                                .foregroundStyle(DS.dust)
                                        }
                                    }
                                    .padding(14)
                                    .background(DS.sand)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }

                        // Meal type
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Öğün Türü")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(DS.ink)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(mealTypes, id: \.label) { type in
                                    Button {
                                        mealType = type.label
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: type.icon)
                                                .font(.system(size: 14))
                                            Text(type.label)
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .foregroundStyle(mealType == type.label ? .white : DS.ink)
                                        .background(mealType == type.label ? DS.ink : DS.sand)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            }
                        }

                        // Save button
                        Button(action: save) {
                            Text(isNewMeal ? "Öğün Ekle" : "Tamam")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundStyle(.white)
                                .background(canSave ? DS.ember : DS.stone)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(!canSave)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showRecipePicker) {
                RecipePickerSheet(recipes: userRecipes) { selected in
                    guard let id = selected.id else { return }
                    switch pickingFor {
                    case .main:
                        mainRecipeId = id
                    case .side(let idx):
                        if idx < sideRecipeIds.count {
                            sideRecipeIds[idx] = id
                        }
                    case .newSide:
                        sideRecipeIds.append(id)
                    }
                    showRecipePicker = false
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var canSave: Bool {
        mainRecipeId != nil
    }

    private func save() {
        guard canSave, let mainId = mainRecipeId else { return }
        var updated = meal
        updated.recipeIds = [mainId] + sideRecipeIds
        updated.mealType = mealType
        onSave(updated)
        dismiss()
    }
}

// MARK: - Recipe Picker

private struct RecipePickerSheet: View {
    let recipes: [RecipeDTO]
    let onSelect: (RecipeDTO) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [RecipeDTO] {
        if search.isEmpty { return recipes }
        return recipes.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List(filtered, id: \.url) { recipe in
                Button {
                    onSelect(recipe)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DS.ink)
                        HStack(spacing: 12) {
                            if let min = recipe.cooking_time_minutes {
                                Label("\(min) dk", systemImage: "clock")
                            }
                            if let cal = recipe.calories_total_kcal {
                                Label("\(Int(cal)) kcal", systemImage: "flame")
                            }
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(DS.smoke)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
            .searchable(text: $search, prompt: "Tarif ara...")
            .navigationTitle("Tarif Seç")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .foregroundStyle(DS.ember)
                }
            }
        }
    }
}
