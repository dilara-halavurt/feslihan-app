import SwiftUI

struct RecipeDetailView: View {
    @Bindable var recipe: Recipe
    @State private var selectedTab = 0
    @State private var profilePicData: Data?
    @State private var servingMultiplier: Double = 1.0

    private let multiplierOptions: [(label: String, value: Double)] = [
        ("1/2x", 0.5), ("1x", 1.0), ("2x", 2.0), ("3x", 3.0), ("4x", 4.0), ("6x", 6.0)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero image - tappable to open video
                if let data = recipe.thumbnailData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 380)
                        .clipped()
                        .onTapGesture { openVideo() }
                }

                VStack(alignment: .leading, spacing: 24) {
                    // Recipe owner
                    if let username = recipe.platformUser, !username.isEmpty {
                        Button {
                            let profileURL: String
                            switch recipe.platform {
                            case "tiktok":
                                profileURL = "https://www.tiktok.com/@\(username)"
                            case "x":
                                profileURL = "https://x.com/\(username)"
                            default:
                                profileURL = "https://www.instagram.com/\(username)/"
                            }
                            if let url = URL(string: profileURL) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                if let picData = profilePicData,
                                   let uiImg = UIImage(data: picData) {
                                    Image(uiImage: uiImg)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 36, height: 36)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 36))
                                        .foregroundStyle(DS.dust)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("@\(username)")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(DS.ink)
                                    if let platform = recipe.platform {
                                        Text(platform == "tiktok" ? "TikTok" : platform == "x" ? "X" : "Instagram")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(DS.smoke)
                                    }
                                }

                                Spacer()

                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(DS.dust)
                            }
                            .padding(12)
                            .background(DS.sand)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // Title + meta
                    VStack(alignment: .leading, spacing: 8) {
                        Text(recipe.title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.ink)

                        HStack(spacing: 16) {
                            if let minutes = recipe.cookingTimeMinutes {
                                Label(formatMinutes(minutes), systemImage: "clock")
                            }
                            if let cuisine = recipe.cuisine {
                                Label(cuisine.capitalized, systemImage: "globe")
                            }
                            Label("\(recipe.ingredients.count)", systemImage: "leaf")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DS.smoke)
                    }

                    // Tab selector
                    HStack(spacing: 0) {
                        tabButton(title: "Malzemeler", index: 0)
                        tabButton(title: "Yapılış", index: 1)
                        tabButton(title: "Besin", index: 2)
                    }
                    .background(DS.sand)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Tab content
                    switch selectedTab {
                    case 0:
                        ingredientsView
                    case 1:
                        instructionsView
                    default:
                        macrosView
                    }

                    // Open video button
                    if recipe.sourceURL != nil {
                        Button { openVideo() } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 18))
                                Text("Videoyu Aç")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .foregroundStyle(.white)
                            .background(DS.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton(action: { dismiss() })
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            // Fetch fresh recipe data from backend
            print("[Detail] sourceURL: \(recipe.sourceURL ?? "nil")")
            if let rawURL = recipe.sourceURL,
               let dto = await APIService.lookup(url: cleanURL(rawURL)) {
                print("[Detail] Got nutrition: cal=\(dto.calories_total_kcal ?? -1), user=\(dto.platform_user ?? "nil")")
                recipe.caloriesTotalKcal = dto.calories_total_kcal
                recipe.caloriesPerServingKcal = dto.calories_per_serving_kcal
                recipe.proteinGrams = dto.protein_grams
                recipe.carbsGrams = dto.carbs_grams
                recipe.fatGrams = dto.fat_grams
                recipe.fiberGrams = dto.fiber_grams
                recipe.servings = dto.servings
                recipe.platformUser = dto.platform_user
                recipe.platform = dto.platform
                recipe.cuisine = dto.cuisine
                recipe.cookingTimeMinutes = dto.cooking_time_minutes
                recipe.likesCount = dto.likes_count
                recipe.tags = dto.tags ?? []
            }

            // Fetch profile picture
            guard let username = recipe.platformUser, !username.isEmpty else { return }
            if let user = await APIService.fetchCreator(username: username),
               let picPath = user.profile_picture_url {
                let fullURL = picPath.hasPrefix("http") ? picPath : "\(APIService.baseURL)\(picPath)"
                profilePicData = await CaptionService.downloadImage(from: fullURL)
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h) sa \(m) dk" : "\(h) sa"
        }
        return "\(minutes) dk"
    }

    private func cleanURL(_ urlString: String) -> String {
        guard var components = URLComponents(string: urlString) else { return urlString }
        components.queryItems = nil
        components.fragment = nil
        return components.url?.absoluteString ?? urlString
    }

    private func openVideo() {
        if let urlStr = recipe.sourceURL,
           let url = URL(string: urlStr) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Tab Button

    private func tabButton(title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(selectedTab == index ? DS.cream : DS.smoke)
                .background(selectedTab == index ? DS.ember : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Ingredients View

    private var ingredientsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Servings indicator + multiplier pills
            VStack(spacing: 12) {
                if let servings = recipe.servings {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 13))
                        Text("\(Int(Double(servings) * servingMultiplier))")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(DS.smoke)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(multiplierOptions, id: \.value) { option in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    servingMultiplier = option.value
                                }
                            } label: {
                                Text(option.label)
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .foregroundStyle(servingMultiplier == option.value ? DS.cream : DS.ink)
                                    .background(servingMultiplier == option.value ? DS.ink : DS.sand)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }

            // Scaled ingredients list
            IngredientsView(ingredients: scaledIngredients)
        }
    }

    private var scaledIngredients: [Ingredient] {
        guard servingMultiplier != 1.0 else { return recipe.ingredients }
        return recipe.ingredients.map { ingredient in
            Ingredient(
                name: ingredient.name,
                amount: scaleAmount(ingredient.amount, by: servingMultiplier)
            )
        }
    }

    private func scaleAmount(_ amount: String, by multiplier: Double) -> String {
        guard !amount.isEmpty else { return amount }

        // Match leading number (integer, decimal, or fraction like 1/2)
        let pattern = #"^(\d+(?:[.,/]\d+)?)\s*(.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: amount, range: NSRange(amount.startIndex..., in: amount)) else {
            return amount
        }

        guard let numRange = Range(match.range(at: 1), in: amount) else { return amount }
        let numStr = String(amount[numRange])
        let rest = match.range(at: 2).length > 0
            ? String(amount[Range(match.range(at: 2), in: amount)!])
            : ""

        let value: Double
        if numStr.contains("/") {
            let parts = numStr.split(separator: "/")
            guard parts.count == 2,
                  let num = Double(parts[0]),
                  let den = Double(parts[1]), den != 0 else { return amount }
            value = num / den
        } else {
            guard let parsed = Double(numStr.replacingOccurrences(of: ",", with: ".")) else { return amount }
            value = parsed
        }

        let scaled = value * multiplier
        let formatted: String
        if scaled == scaled.rounded() && scaled >= 1 {
            formatted = String(Int(scaled))
        } else {
            formatted = String(format: "%.1f", scaled)
                .replacingOccurrences(of: ".0", with: "")
        }

        return rest.isEmpty ? formatted : "\(formatted) \(rest)"
    }

    // MARK: - Instructions View

    private var instructionsView: some View {
        Text(recipe.instructions)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(DS.ink)
            .lineSpacing(6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Macros View

    private var hasMacros: Bool {
        recipe.caloriesTotalKcal != nil
            || recipe.proteinGrams != nil
            || recipe.carbsGrams != nil
            || recipe.fatGrams != nil
    }

    private var macrosView: some View {
        Group {
            if hasMacros {
                VStack(spacing: 20) {
                    // Calories header
                    if let cal = recipe.caloriesTotalKcal {
                        VStack(spacing: 4) {
                            Text("\(Int(cal))")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundStyle(DS.ink)
                            Text("toplam kcal")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(DS.smoke)

                            if let perServing = recipe.caloriesPerServingKcal,
                               let servings = recipe.servings {
                                Text("\(Int(perServing)) kcal / \(servings) kişilik")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(DS.smoke)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(DS.sand)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Macro bars
                    VStack(spacing: 12) {
                        if let protein = recipe.proteinGrams {
                            macroRow(label: "Protein", value: protein, color: Color(hex: 0x4ECDC4), total: macroTotal)
                        }
                        if let carbs = recipe.carbsGrams {
                            macroRow(label: "Karbonhidrat", value: carbs, color: Color(hex: 0xF7DC6F), total: macroTotal)
                        }
                        if let fat = recipe.fatGrams {
                            macroRow(label: "Yağ", value: fat, color: Color(hex: 0xF1948A), total: macroTotal)
                        }
                        if let fiber = recipe.fiberGrams {
                            macroRow(label: "Lif", value: fiber, color: Color(hex: 0x82E0AA), total: macroTotal)
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(DS.dust)
                    Text("Besin değerleri mevcut değil")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DS.smoke)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }

    private var macroTotal: Double {
        (recipe.proteinGrams ?? 0) + (recipe.carbsGrams ?? 0) + (recipe.fatGrams ?? 0) + (recipe.fiberGrams ?? 0)
    }

    private func macroRow(label: String, value: Double, color: Color, total: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DS.ink)
                Spacer()
                Text(String(format: "%.0fg", value))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.ink)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DS.sand)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: total > 0 ? geo.size.width * CGFloat(value / total) : 0, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}
