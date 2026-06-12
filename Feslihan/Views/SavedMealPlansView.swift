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
    let shopping_list: [String]?
    let avg_calories_per_day: Int?
}

struct SavedPlanDay: Codable {
    let day_name: String?
    let meals: [SavedPlanMeal]?
}

struct SavedPlanMeal: Codable {
    let meal_type: String?
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
    @State private var ingredientData: [String: IngredientDTO] = [:]
    @State private var isSaving = false
    @State private var hasChanges = false
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary
                HStack(spacing: 8) {
                    StatPill(icon: "fork.knife", value: "\(days.flatMap(\.meals).count)", label: "Tarif")
                    StatPill(icon: "cart", value: "\(currentShoppingListNames.count)", label: "Malzeme")
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
                MealEditSheet(meal: meal, userRecipes: userRecipes) { updated in
                    replaceMeal(meal, with: updated)
                    editingMeal = nil
                }
            }
            .sheet(item: $newMealForDay) { meal in
                MealEditSheet(meal: meal, userRecipes: userRecipes) { updated in
                    addNewMealToDay(updated)
                    newMealForDay = nil
                    addingToDayId = nil
                }
            }
            .task {
                // Convert saved data to editable model
                days = (plan.plan.days ?? []).enumerated().map { index, day in
                    MealPlanDay(
                        id: "day-\(index)",
                        name: day.day_name ?? "Gün \(index + 1)",
                        meals: (day.meals ?? []).map { meal in
                            MealPlanMeal(
                                mealType: meal.meal_type ?? "",
                                name: meal.name ?? "",
                                description: meal.description,
                                calories: meal.calories,
                                ingredients: meal.ingredients ?? []
                            )
                        }
                    )
                }

                if let userId = Clerk.shared.user?.id {
                    userRecipes = await APIService.fetchUserRecipes(userId: userId)
                }

                // Load ingredient data for unit conversions
                let allIngredients = await APIService.fetchIngredients()
                var dataMap: [String: IngredientDTO] = [:]
                for ing in allIngredients {
                    dataMap[ing.name.lowercased()] = ing
                }
                ingredientData = dataMap
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

    // MARK: - Shopping List (computed from current meals + recipe measures)

    private struct ShoppingItem: Hashable {
        let name: String
        let amount: String
    }

    // MARK: - Standard Turkish volume measures (ml)
    private static let volumeToMl: [(pattern: String, ml: Double)] = [
        ("su bardağı", 200), ("su bardagi", 200),
        ("çay bardağı", 100), ("cay bardagi", 100),
        ("yemek kaşığı", 15), ("yemek kasigi", 15),
        ("tatlı kaşığı", 5), ("tatli kasigi", 5),
        ("çay kaşığı", 2.5), ("cay kasigi", 2.5),
        ("cup", 240),
    ]

    private var currentShoppingList: [ShoppingItem] {
        // Collect recipe usage counts
        var titleCounts: [String: Int] = [:]
        for day in days {
            for meal in day.meals {
                for part in meal.name.components(separatedBy: " + ") {
                    let title = part.trimmingCharacters(in: .whitespaces)
                    titleCounts[title, default: 0] += 1
                }
            }
        }

        // Collect ALL amounts per ingredient
        var measuresByName: [String: [String]] = [:]
        for recipe in userRecipes {
            guard let count = titleCounts[recipe.title], count > 0 else { continue }
            for ing in recipe.ingredients_with_measures {
                let name = (ing["name"] ?? "").lowercased()
                let amount = ing["amount"] ?? ""
                guard !name.isEmpty, !amount.isEmpty else { continue }
                for _ in 0..<count {
                    measuresByName[name, default: []].append(amount)
                }
            }
        }

        // Deduplicate and aggregate
        var seen = Set<String>()
        var result: [ShoppingItem] = []
        for day in days {
            for meal in day.meals {
                for ingredient in meal.ingredients {
                    let trimmed = ingredient.trimmingCharacters(in: .whitespaces)
                    let key = trimmed.lowercased()
                    guard !key.isEmpty, !seen.contains(key) else { continue }
                    seen.insert(key)
                    let displayName = String(trimmed.prefix(1)).uppercased() + trimmed.dropFirst()
                    let amounts = measuresByName[key] ?? []
                    let ing = ingredientData[key]
                    let combinedAmount: String
                    if amounts.isEmpty {
                        combinedAmount = ""
                    } else if amounts.count == 1 {
                        combinedAmount = amounts[0]
                    } else {
                        combinedAmount = aggregateAmounts(amounts, ingredient: ing)
                    }
                    result.append(ShoppingItem(name: displayName, amount: combinedAmount))
                }
            }
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Amount Parsing & Aggregation

    private func parseAmount(_ amount: String) -> (value: Double, unit: String)? {
        let pattern = #"^(\d+(?:[.,/]\d+)?)\s*(.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: amount, range: NSRange(location: 0, length: (amount as NSString).length)),
              let numRange = Range(match.range(at: 1), in: amount) else { return nil }
        let numStr = String(amount[numRange]).replacingOccurrences(of: ",", with: ".")
        let unit = match.range(at: 2).length > 0
            ? String(amount[Range(match.range(at: 2), in: amount)!]).trimmingCharacters(in: .whitespaces)
            : ""
        if numStr.contains("/") {
            let parts = numStr.split(separator: "/")
            guard parts.count == 2, let n = Double(parts[0]), let d = Double(parts[1]), d != 0 else { return nil }
            return (n / d, unit)
        }
        guard let value = Double(numStr) else { return nil }
        return (value, unit)
    }

    /// Convert amount to grams using density and standard volumes
    private func toGrams(_ value: Double, unit: String, ingredient: IngredientDTO?) -> Double? {
        let u = unit.lowercased()
        let density = ingredient?.density_g_ml ?? 1.0

        // Weight units → grams directly
        if u == "g" || u == "gr" || u == "gram" { return value }
        if u == "kg" { return value * 1000 }

        // Volume units → ml → grams via density
        if u == "ml" { return value * density }
        if u == "l" || u == "lt" || u == "litre" { return value * 1000 * density }

        // Turkish volume measures → ml → grams
        for (pattern, ml) in Self.volumeToMl {
            if u.contains(pattern) {
                return value * ml * density
            }
        }

        // "adet" / "tane" / bare number → grams via gram_per_adet
        if u == "adet" || u == "tane" || u == "" {
            if let gpa = ingredient?.gram_per_adet { return value * gpa }
            return nil
        }

        // Other units we can't convert (demet, tutam, diş, etc.)
        return nil
    }

    /// Convert grams back to best display unit
    private func formatFromGrams(_ grams: Double, ingredient: IngredientDTO?) -> String {
        let isLiquid = ingredient?.default_unit == "ml"
        let density = ingredient?.density_g_ml ?? 1.0

        if isLiquid {
            let ml = grams / density
            if ml >= 1000 {
                return formatNum(ml / 1000) + " litre"
            }
            return formatNum(ml) + " ml"
        }

        // Prefer "adet" for countable items
        if ingredient?.default_unit == "adet", let gpa = ingredient?.gram_per_adet, gpa > 0 {
            let count = grams / gpa
            if count >= 1 {
                return formatNum(count) + " adet"
            }
        }

        // Weight display
        if grams >= 1000 {
            return formatNum(grams / 1000) + " kg"
        }
        return formatNum(grams) + " g"
    }

    private func formatNum(_ n: Double) -> String {
        if n == n.rounded() && n < 10000 { return String(Int(n)) }
        return String(format: "%.0f", n)
    }

    /// Aggregate multiple amounts, converting to a common base unit
    private func aggregateAmounts(_ amounts: [String], ingredient: IngredientDTO?) -> String {
        var totalGrams: Double = 0
        var allConverted = true

        for amount in amounts {
            if let parsed = parseAmount(amount),
               let g = toGrams(parsed.value, unit: parsed.unit, ingredient: ingredient) {
                totalGrams += g
            } else {
                allConverted = false
            }
        }

        if allConverted && totalGrams > 0 {
            return formatFromGrams(totalGrams, ingredient: ingredient)
        }

        // Fallback: sum same-unit amounts
        var unitGroups: [String: Double] = [:]
        var unparsed: [String] = []
        for amount in amounts {
            if let parsed = parseAmount(amount) {
                unitGroups[parsed.unit, default: 0] += parsed.value
            } else {
                unparsed.append(amount)
            }
        }
        if unitGroups.count == 1, unparsed.isEmpty, let (unit, total) = unitGroups.first {
            return unit.isEmpty ? formatNum(total) : "\(formatNum(total)) \(unit)"
        }
        var parts = unitGroups.sorted(by: { $0.key < $1.key }).map { (unit, total) in
            unit.isEmpty ? formatNum(total) : "\(formatNum(total)) \(unit)"
        }
        parts.append(contentsOf: unparsed)
        return parts.joined(separator: " + ")
    }

    private var currentShoppingListNames: [String] {
        currentShoppingList.map(\.name)
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
                                                Text(meal.name)
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
                                        name: "",
                                        description: nil,
                                        calories: nil,
                                        ingredients: []
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

    private var shoppingListTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if currentShoppingList.isEmpty {
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
                    VStack(spacing: 0) {
                        ForEach(Array(currentShoppingList.enumerated()), id: \.offset) { index, item in
                            HStack(spacing: 13) {
                                Circle()
                                    .stroke(DS.stone, lineWidth: 2)
                                    .frame(width: 22, height: 22)
                                Text(item.name)
                                    .font(.system(size: 15))
                                    .foregroundStyle(DS.ink)
                                Spacer()
                                if !item.amount.isEmpty {
                                    Text(item.amount)
                                        .font(.system(size: 14))
                                        .foregroundStyle(DS.smoke)
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 46)

                            if index < currentShoppingList.count - 1 {
                                Divider()
                                    .background(DS.stone)
                                    .padding(.leading, 51)
                            }
                        }
                    }
                    .background(DS.flour)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: DS.shadowCard, radius: 4, y: 2)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    Text("\(currentShoppingList.count) malzeme")
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
        guard !meal.name.isEmpty else { return }
        days[dayIndex].meals.append(meal)
        hasChanges = true
    }

    private func saveChanges() {
        isSaving = true
        Task {
            defer { isSaving = false }

            guard let url = URL(string: "\(APIService.baseURL)/meal-plans/\(plan.id)") else {
                print("[SavePlan] Invalid URL")
                return
            }

            // Rebuild shopping list with measures from recipes
            let shoppingList = currentShoppingList.map { item in
                item.amount.isEmpty ? item.name : "\(item.amount) \(item.name)"
            }

            // Recalculate avg calories
            let totalDays = days.count
            let totalCalories = days.flatMap(\.meals).compactMap(\.calories).reduce(0, +)
            let avgCalories = totalDays > 0 ? totalCalories / totalDays : 0

            let planData: [String: Any] = [
                "days": days.map { day in
                    [
                        "day_name": day.name,
                        "meals": day.meals.map { meal in
                            [
                                "meal_type": meal.mealType,
                                "name": meal.name,
                                "description": meal.description ?? "",
                                "calories": meal.calories ?? 0,
                                "ingredients": meal.ingredients
                            ] as [String: Any]
                        }
                    ] as [String: Any]
                },
                "shopping_list": shoppingList,
                "avg_calories_per_day": avgCalories
            ]

            let body: [String: Any] = ["plan": planData]

            guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
                print("[SavePlan] JSON serialization failed")
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = httpBody

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse {
                    print("[SavePlan] Status: \(http.statusCode)")
                    if http.statusCode == 200 {
                        hasChanges = false
                        DispatchQueue.main.async {
                            onPlanUpdated?()
                        }
                    } else {
                        let responseBody = String(data: data, encoding: .utf8) ?? "no body"
                        print("[SavePlan] Error response: \(responseBody)")
                    }
                }
            } catch {
                print("[SavePlan] Network error: \(error)")
            }
        }
    }
}
