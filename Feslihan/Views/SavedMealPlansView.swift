import SwiftUI
import ClerkKit

struct SavedMealPlansView: View {
    var onBack: () -> Void
    var onCreateNew: () -> Void

    @State private var plans: [SavedPlanItem] = []
    @State private var isLoading = true
    @State private var selectedPlan: SavedPlanItem?

    var body: some View {
        NavigationStack {
            ZStack {
                DS.cream.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                } else if plans.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(DS.dust)
                        Text("Henüz kayıtlı plan yok")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(DS.ink)
                        Text("Yeni bir yemek planı oluştur")
                            .font(.system(size: 14))
                            .foregroundStyle(DS.smoke)
                        Button("Plan Oluştur", action: onCreateNew)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DS.ember)
                            .padding(.top, 4)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Kayıtlı Planlar")
                                .font(.system(size: 30, weight: .semibold, design: .serif))
                                .foregroundStyle(DS.ink)

                            Text("\(plans.count) yemek planı")
                                .font(.system(size: 14))
                                .foregroundStyle(DS.smoke)

                            Rectangle()
                                .fill(DS.stone)
                                .frame(height: 1)

                            ForEach(plans) { plan in
                                Button {
                                    selectedPlan = plan
                                } label: {
                                    SavedPlanCard(plan: plan, onDelete: {
                                        Task { await deletePlan(plan) }
                                    })
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BackButton(action: onBack)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onCreateNew) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(DS.ink)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedPlan) { plan in
                SavedPlanDetailSheet(plan: plan, onPlanUpdated: {
                    Task { await loadPlans() }
                })
            }
            .task {
                await loadPlans()
            }
        }
    }

    private func loadPlans() async {
        guard let userId = Clerk.shared.user?.id else { return }
        guard let url = URL(string: "\(APIService.baseURL)/users/\(userId)/meal-plans") else { return }

        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {
            isLoading = false
            return
        }

        if let decoded = try? JSONDecoder().decode([SavedPlanItem].self, from: data) {
            plans = decoded
        }
        isLoading = false
    }

    private func deletePlan(_ plan: SavedPlanItem) async {
        guard let url = URL(string: "\(APIService.baseURL)/meal-plans/\(plan.id)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try? await URLSession.shared.data(for: request)
        plans.removeAll { $0.id == plan.id }
    }
}

// MARK: - Data Model

struct SavedPlanItem: Identifiable, Codable {
    let id: String
    let user_id: String
    let name: String
    let plan: SavedPlanData
    let recipe_ids: [String]?
    let shopping_list: [String]?
    let created_at: String

    var createdDate: Date? {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return df.date(from: created_at) ?? ISO8601DateFormatter().date(from: created_at)
    }

    var timeAgo: String {
        guard let date = createdDate else { return "" }
        let diff = Calendar.current.dateComponents([.day, .weekOfYear], from: date, to: Date())
        if let weeks = diff.weekOfYear, weeks > 0 {
            return "\(weeks) hafta önce"
        }
        if let days = diff.day {
            if days == 0 { return "Bugün" }
            if days == 1 { return "Dün" }
            return "\(days) gün önce"
        }
        return ""
    }

    var totalMeals: Int {
        plan.days?.reduce(0) { $0 + ($1.meals?.count ?? 0) } ?? 0
    }

    var avgCalories: Int {
        plan.avg_calories_per_day ?? 0
    }

    var peopleCount: String {
        // Parse from name like "Haftalık - 2 Kişi"
        if let match = name.range(of: #"(\d+\+?)\s*[Kk]işi"#, options: .regularExpression) {
            let sub = name[match]
            if let numMatch = sub.range(of: #"\d+\+?"#, options: .regularExpression) {
                return String(sub[numMatch])
            }
        }
        return "-"
    }
}

struct SavedPlanData: Codable {
    let days: [SavedPlanDay]?
    let shopping_list: [String]?  // Legacy: old plans stored this inside plan JSON
    let avg_calories_per_day: Int?
}

struct SavedPlanDay: Codable {
    let day_name: String?
    let meals: [SavedPlanMeal]?
}

struct SavedPlanMeal: Codable {
    let meal_type: String?
    let recipe_ids: [String]?
    // Legacy/fallback fields for plans with AI-invented recipes
    let name: String?
    let description: String?
    let calories: Int?
    let ingredients: [String]?
}

// MARK: - Plan Card

private struct SavedPlanCard: View {
    let plan: SavedPlanItem
    let onDelete: () -> Void
    @State private var showMenu = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(DS.ink)

                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                        Text(plan.createdDate.map { formatDateRange($0, days: plan.plan.days?.count ?? 7) } ?? "")
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(DS.smoke)
                }

                Spacer()

                Menu {
                    Button(role: .destructive, action: onDelete) {
                        Label("Sil", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DS.smoke)
                        .frame(width: 32, height: 32)
                }
            }

            HStack(spacing: 8) {
                StatPill(icon: "person.2", value: plan.peopleCount, label: "Kişi")
                StatPill(icon: "fork.knife", value: "\(plan.totalMeals)", label: "Tarif")
                StatPill(icon: "flame", value: plan.avgCalories > 0 ? "\(plan.avgCalories)" : "-", label: "kcal/gün")
            }

            Text("Oluşturuldu: \(plan.timeAgo)")
                .font(.system(size: 12))
                .foregroundStyle(DS.dust)
        }
        .padding(16)
        .background(DS.sand)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func formatDateRange(_ start: Date, days: Int) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "tr_TR")
        df.dateFormat = "d MMMM"
        let end = Calendar.current.date(byAdding: .day, value: days - 1, to: start) ?? start
        return "\(df.string(from: start)) - \(df.string(from: end))"
    }
}

private struct StatPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DS.smoke)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(DS.ink)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(DS.smoke)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(DS.cream)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Plan Detail Sheet (Editable)

private struct SavedPlanDetailSheet: View {
    let plan: SavedPlanItem
    var onPlanUpdated: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var days: [MealPlanDay] = []
    @State private var expandedDay: String?
    @State private var editingMeal: MealPlanMeal?
    @State private var addingToDayId: String?
    @State private var newMealForDay: MealPlanMeal?
    @State private var userRecipes: [RecipeDTO] = []
    @State private var recipeById: [String: RecipeDTO] = [:]
    @State private var pantryNames: Set<String> = []
    @State private var shoppingListNames: Set<String> = []
    @State private var isSaving = false
    @State private var hasChanges = false
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary
                HStack(spacing: 8) {
                    StatPill(icon: "fork.knife", value: "\(days.flatMap(\.meals).count)", label: "Tarif")
                    StatPill(icon: "cart", value: "\((plan.shopping_list ?? plan.plan.shopping_list ?? []).count)", label: "Malzeme")
                    StatPill(icon: "flame", value: plan.avgCalories > 0 ? "\(plan.avgCalories)" : "-", label: "kcal/gün")
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Tabs
                HStack(spacing: 22) {
                    tabButton(title: "Yemek Planı", index: 0)
                    tabButton(title: "Alışveriş Listesi", index: 1)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 1)

                Divider().background(DS.stone)

                // Tab content
                if selectedTab == 0 {
                    mealPlanTab
                } else {
                    shoppingListTab
                }

                // Sticky save button
                if hasChanges {
                    Button(action: saveChanges) {
                        HStack(spacing: 8) {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                Text("Değişiklikleri Kaydet")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundStyle(.white)
                        .background(DS.ember)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: DS.shadowButton, radius: 8, y: 4)
                    }
                    .disabled(isSaving)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
            }
            .background(DS.cream)
            .navigationTitle(plan.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                        .foregroundStyle(DS.ember)
                }
            }
            .sheet(item: $editingMeal) { meal in
                MealEditSheet(meal: meal, userRecipes: userRecipes, recipeById: recipeById) { updated in
                    replaceMeal(meal, with: updated)
                    editingMeal = nil
                }
            }
            .sheet(item: $newMealForDay) { meal in
                MealEditSheet(meal: meal, userRecipes: userRecipes, recipeById: recipeById) { updated in
                    addNewMealToDay(updated)
                    newMealForDay = nil
                    addingToDayId = nil
                }
            }
            .task {
                days = (plan.plan.days ?? []).enumerated().map { index, day in
                    MealPlanDay(
                        id: "day-\(index)",
                        name: day.day_name ?? "Gün \(index + 1)",
                        meals: (day.meals ?? []).map { meal in
                            MealPlanMeal(
                                mealType: meal.meal_type ?? "",
                                recipeIds: meal.recipe_ids ?? [],
                                fallbackName: meal.name,
                                fallbackDescription: meal.description,
                                fallbackCalories: meal.calories,
                                fallbackIngredients: meal.ingredients
                            )
                        }
                    )
                }

                if let userId = Clerk.shared.user?.id {
                    userRecipes = await APIService.fetchUserRecipes(userId: userId)
                    var map: [String: RecipeDTO] = [:]
                    for r in userRecipes { if let id = r.id { map[id] = r } }
                    recipeById = map

                    async let pantryTask = APIService.fetchPantry(userId: userId)
                    async let shoppingTask = APIService.fetchShoppingList(userId: userId)
                    let pantryItems = await pantryTask
                    let shoppingItems = await shoppingTask
                    pantryNames = Set(pantryItems.map { $0.ingredient_name.lowercased() })
                    shoppingListNames = Set(shoppingItems.map { $0.ingredient_name.lowercased() })
                }
            }
        }
    }

    // MARK: - Tab Button

    private func tabButton(title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(selectedTab == index ? DS.ember : DS.dust)

                Rectangle()
                    .fill(selectedTab == index ? DS.ember : Color.clear)
                    .frame(height: 2.5)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Shopping List (from AI-generated plan, stored in DB column)

    private var parsedShoppingList: [ShoppingListItem] {
        // New plans: shopping_list in separate DB column; old plans: inside plan JSON
        let list = plan.shopping_list ?? plan.plan.shopping_list ?? []
        return list.map { ShoppingListItem.parse($0) }
    }

    // MARK: - Meal Plan Tab

    private var mealPlanTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(days) { day in
                    VStack(alignment: .leading, spacing: 0) {
                        Button {
                            withAnimation(.spring(response: 0.2)) {
                                expandedDay = expandedDay == day.id ? nil : day.id
                            }
                        } label: {
                            HStack {
                                Text(day.name)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(DS.ink)
                                Spacer()
                                Text("\(day.meals.count) öğün")
                                    .font(.system(size: 12))
                                    .foregroundStyle(DS.smoke)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(DS.dust)
                                    .rotationEffect(.degrees(expandedDay == day.id ? 90 : 0))
                            }
                            .padding(14)
                        }

                        if expandedDay == day.id {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(day.meals) { meal in
                                    Button {
                                        editingMeal = meal
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(meal.mealType)
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundStyle(DS.ember)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 2)
                                                    .background(DS.emberLight)
                                                    .clipShape(Capsule())
                                                Text(meal.displayName(using: recipeById))
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundStyle(DS.ink)
                                                    .multilineTextAlignment(.leading)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12))
                                                .foregroundStyle(DS.dust)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }

                                Button {
                                    addingToDayId = day.id
                                    newMealForDay = MealPlanMeal(
                                        mealType: "Öğle",
                                        recipeIds: []
                                    )
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 14))
                                        Text("Öğün Ekle")
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundStyle(DS.ember)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(DS.emberLight)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.bottom, 14)
                        }
                    }
                    .background(DS.sand)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Shopping List Tab

    private func addToShoppingList(_ name: String) {
        Task {
            guard let userId = Clerk.shared.user?.id else { return }
            let success = await APIService.addToShoppingList(userId: userId, ingredientNames: [name])
            if success {
                shoppingListNames.insert(name.lowercased())
            }
        }
    }

    private var shoppingListTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if parsedShoppingList.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "cart")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(DS.dust)
                        Text("Alışveriş listesi boş")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(DS.smoke)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    HStack(spacing: 16) {
                        HStack(spacing: 5) {
                            Circle().fill(DS.ember).frame(width: 8, height: 8)
                            Text("Kilerde var").font(.captionText()).foregroundStyle(DS.smoke)
                        }
                        HStack(spacing: 5) {
                            Circle().fill(DS.tomato).frame(width: 8, height: 8)
                            Text("Alınacak").font(.captionText()).foregroundStyle(DS.smoke)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    VStack(spacing: 0) {
                        ForEach(Array(parsedShoppingList.enumerated()), id: \.offset) { index, item in
                            let inPantry = pantryNames.contains(item.name.lowercased())
                            let inCart = shoppingListNames.contains(item.name.lowercased())

                            HStack(spacing: 10) {
                                Circle()
                                    .fill(inPantry ? DS.ember : DS.tomato)
                                    .frame(width: 9, height: 9)

                                Text(item.name)
                                    .font(.system(size: 15))
                                    .foregroundStyle(inPantry ? DS.smoke : DS.ink)

                                Spacer()

                                if !item.amount.isEmpty {
                                    Text(item.amount)
                                        .font(.system(size: 14))
                                        .foregroundStyle(DS.smoke)
                                }

                                if !inPantry {
                                    if inCart {
                                        Image(systemName: "cart.fill.badge.checkmark")
                                            .font(.system(size: 14))
                                            .foregroundStyle(DS.ember)
                                    } else {
                                        Button {
                                            addToShoppingList(item.name)
                                        } label: {
                                            Image(systemName: "cart.badge.plus")
                                                .font(.system(size: 14))
                                                .foregroundStyle(DS.ember)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 46)

                            if index < parsedShoppingList.count - 1 {
                                Divider()
                                    .background(DS.stone)
                                    .padding(.leading, 35)
                            }
                        }
                    }
                    .background(DS.flour)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: DS.shadowCard, radius: 4, y: 2)
                    .padding(.horizontal, 20)

                    let needCount = parsedShoppingList.filter { !pantryNames.contains($0.name.lowercased()) }.count
                    Text("\(parsedShoppingList.count) malzeme · \(needCount) eksik")
                        .font(.captionText())
                        .foregroundStyle(DS.dust)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                }
            }
            .padding(.bottom, 20)
        }
    }

    private func replaceMeal(_ old: MealPlanMeal, with updated: MealPlanMeal) {
        for dayIndex in days.indices {
            if let mealIndex = days[dayIndex].meals.firstIndex(where: { $0.id == old.id }) {
                days[dayIndex].meals[mealIndex] = updated
                hasChanges = true
                break
            }
        }
    }

    private func addNewMealToDay(_ meal: MealPlanMeal) {
        guard let dayId = addingToDayId,
              let dayIndex = days.firstIndex(where: { $0.id == dayId }) else { return }
        guard !meal.recipeIds.isEmpty else { return }
        days[dayIndex].meals.append(meal)
        hasChanges = true
    }

    private func saveChanges() {
        isSaving = true
        Task {
            defer { isSaving = false }

            guard let url = URL(string: "\(APIService.baseURL)/meal-plans/\(plan.id)") else { return }

            // Collect all recipe IDs
            let allIds = Array(Set(days.flatMap { $0.meals.flatMap(\.recipeIds) }))

            let planData: [String: Any] = [
                "days": days.map { day in
                    [
                        "day_name": day.name,
                        "meals": day.meals.map { meal in
                            var m: [String: Any] = [
                                "meal_type": meal.mealType,
                                "recipe_ids": meal.recipeIds
                            ]
                            if let n = meal.fallbackName { m["name"] = n }
                            if let d = meal.fallbackDescription { m["description"] = d }
                            if let c = meal.fallbackCalories { m["calories"] = c }
                            if let i = meal.fallbackIngredients { m["ingredients"] = i }
                            return m as [String: Any]
                        }
                    ] as [String: Any]
                },
                "avg_calories_per_day": plan.avgCalories
            ]

            let body: [String: Any] = [
                "plan": planData,
                "recipe_ids": allIds
            ]

            guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = httpBody

            if let (_, response) = try? await URLSession.shared.data(for: request),
               let http = response as? HTTPURLResponse,
               http.statusCode == 200 {
                hasChanges = false
                onPlanUpdated?()
            }
        }
    }
}
