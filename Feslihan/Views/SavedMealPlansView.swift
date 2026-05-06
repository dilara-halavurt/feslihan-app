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
                                .font(.system(size: 28, weight: .bold, design: .rounded))
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
                SavedPlanDetailSheet(plan: plan)
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
                StatPill(icon: "person.2", value: "-", label: "Kişi")
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
    @Environment(\.dismiss) private var dismiss
    @State private var days: [MealPlanDay] = []
    @State private var expandedDay: String?
    @State private var editingMeal: MealPlanMeal?
    @State private var addingToDayId: String?
    @State private var userRecipes: [RecipeDTO] = []
    @State private var isSaving = false
    @State private var hasChanges = false

    var body: some View {
        NavigationStack {
            ZStack {
                DS.cream.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Summary
                        HStack(spacing: 8) {
                            StatPill(icon: "fork.knife", value: "\(days.flatMap(\.meals).count)", label: "Tarif")
                            StatPill(icon: "cart", value: "\(plan.plan.shopping_list?.count ?? 0)", label: "Malzeme")
                            StatPill(icon: "flame", value: plan.avgCalories > 0 ? "\(plan.avgCalories)" : "-", label: "kcal/gün")
                        }
                        .padding(.horizontal, 20)

                        // Days
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
                                                    }
                                                    Spacer()
                                                    Image(systemName: "chevron.right")
                                                        .font(.system(size: 12))
                                                        .foregroundStyle(DS.dust)
                                                }
                                            }
                                            .padding(.vertical, 4)
                                        }

                                        // Add meal
                                        Button {
                                            addingToDayId = day.id
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

                        // Shopping list
                        if let list = plan.plan.shopping_list, !list.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    Image(systemName: "cart.fill")
                                        .foregroundStyle(DS.ember)
                                    Text("Alışveriş Listesi")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(DS.ink)
                                }
                                ForEach(list, id: \.self) { item in
                                    HStack(spacing: 8) {
                                        Image(systemName: "circle")
                                            .font(.system(size: 8))
                                            .foregroundStyle(DS.dust)
                                        Text(item)
                                            .font(.system(size: 14))
                                            .foregroundStyle(DS.ink)
                                    }
                                }
                            }
                            .padding(14)
                            .background(DS.sand)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 20)
                        }

                        // Save changes button
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
                            }
                            .disabled(isSaving)
                            .padding(.horizontal, 20)
                        }

                        Spacer().frame(height: 20)
                    }
                    .padding(.top, 16)
                }
            }
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
            .sheet(isPresented: Binding(
                get: { addingToDayId != nil },
                set: { if !$0 { addingToDayId = nil } }
            )) {
                RecipeSwapSheet(
                    currentMealName: "Yeni öğün ekle",
                    recipes: userRecipes,
                    onSelect: { selected in
                        addMealToDay(selected)
                        addingToDayId = nil
                    }
                )
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

                if let userId = await Clerk.shared.user?.id {
                    userRecipes = await APIService.fetchUserRecipes(userId: userId)
                }
            }
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

    private func addMealToDay(_ recipe: RecipeDTO) {
        guard let dayId = addingToDayId,
              let dayIndex = days.firstIndex(where: { $0.id == dayId }) else { return }
        days[dayIndex].meals.append(MealPlanMeal(
            mealType: "Ek Öğün",
            name: recipe.title,
            description: String(recipe.description.prefix(120)),
            calories: recipe.calories_total_kcal.map { Int($0) },
            ingredients: recipe.ingredients_without_measures
        ))
        hasChanges = true
    }

    private func saveChanges() {
        isSaving = true
        Task {
            guard let url = URL(string: "\(APIService.baseURL)/meal-plans/\(plan.id)") else {
                isSaving = false
                return
            }

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
                "shopping_list": plan.plan.shopping_list ?? [],
                "avg_calories_per_day": plan.plan.avg_calories_per_day ?? 0
            ]

            let body: [String: Any] = ["plan": planData]

            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            if let (_, response) = try? await URLSession.shared.data(for: request),
               let http = response as? HTTPURLResponse,
               http.statusCode == 200 {
                hasChanges = false
            }
            isSaving = false
        }
    }
}
