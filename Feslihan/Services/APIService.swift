import Foundation

enum APIService {
    #if DEBUG
    static let baseURL = "http://localhost:3000"
    #else
    static let baseURL = "https://feslihan-app.vercel.app"
    #endif

    /// Check if a recipe already exists for this URL.
    static func lookup(url: String) async -> RecipeDTO? {
        guard let encoded = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let requestURL = URL(string: "\(baseURL)/recipes/lookup?url=\(encoded)") else {
            return nil
        }

        guard let (data, response) = try? await URLSession.shared.data(from: requestURL),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {
            return nil
        }

        return try? JSONDecoder().decode(RecipeDTO.self, from: data)
    }

    /// Fetch all recipes from the backend.
    static func fetchAll() async -> [RecipeDTO] {
        guard let requestURL = URL(string: "\(baseURL)/recipes") else { return [] }

        guard let (data, response) = try? await URLSession.shared.data(from: requestURL),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {
            return []
        }

        return (try? JSONDecoder().decode([RecipeDTO].self, from: data)) ?? []
    }

    /// Fetch recipes for a specific user.
    static func fetchUserRecipes(userId: String) async -> [RecipeDTO] {
        guard let requestURL = URL(string: "\(baseURL)/users/\(userId)/recipes") else { return [] }

        guard let (data, response) = try? await URLSession.shared.data(from: requestURL),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {
            return []
        }

        return (try? JSONDecoder().decode([RecipeDTO].self, from: data)) ?? []
    }

    /// Fetch all known ingredients (with price tier) from the backend.
    static func fetchIngredients() async -> [IngredientDTO] {
        guard let requestURL = URL(string: "\(baseURL)/ingredients") else { return [] }

        guard let (data, response) = try? await URLSession.shared.data(from: requestURL),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {
            return []
        }

        return (try? JSONDecoder().decode([IngredientDTO].self, from: data)) ?? []
    }

    /// Fetch all predefined tags from the backend.
    static func fetchTags() async -> [String] {
        guard let requestURL = URL(string: "\(baseURL)/tags") else { return [] }

        guard let (data, response) = try? await URLSession.shared.data(from: requestURL),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {
            return []
        }

        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    /// Save a recipe to the backend.
    static func save(recipe: RecipeDTO) async -> RecipeDTO? {
        guard let requestURL = URL(string: "\(baseURL)/recipes") else { return nil }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let body = try? JSONEncoder().encode(recipe) else { return nil }
        request.httpBody = body

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...201).contains(http.statusCode) else {
            return nil
        }

        return try? JSONDecoder().decode(RecipeDTO.self, from: data)
    }

    // MARK: - Folders

    static func fetchFolders(userId: String) async -> [FolderDTO] {
        guard let url = URL(string: "\(baseURL)/users/\(userId)/folders") else { return [] }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
        return (try? JSONDecoder().decode([FolderDTO].self, from: data)) ?? []
    }

    static func createFolder(userId: String, name: String, emoji: String?) async -> FolderDTO? {
        guard let url = URL(string: "\(baseURL)/folders") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["user_id": userId, "name": name, "emoji": emoji ?? ""]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 201 else { return nil }
        return try? JSONDecoder().decode(FolderDTO.self, from: data)
    }

    static func deleteFolder(id: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/folders/\(id)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 204 else { return false }
        return true
    }

    static func moveRecipeToFolder(userId: String, recipeId: String, folderId: String?) async -> Bool {
        guard let url = URL(string: "\(baseURL)/users/\(userId)/recipes/\(recipeId)/folder") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any?] = ["folder_id": folderId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
        return true
    }

    /// Delete a recipe from the user's collection (keeps the global recipe).
    static func deleteUserRecipe(userId: String, recipeId: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/users/\(userId)/recipes/\(recipeId)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 204 else { return false }
        return true
    }

    /// Fetch estimated cost for a recipe.
    static func fetchRecipeCost(recipeId: String) async -> RecipeCostDTO? {
        guard let requestURL = URL(string: "\(baseURL)/recipes/\(recipeId)/cost") else { return nil }
        guard let (data, response) = try? await URLSession.shared.data(from: requestURL),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(RecipeCostDTO.self, from: data)
    }

    /// Fetch instagram user info including profile picture URL.
    static func fetchCreator(username: String) async -> InstagramUserDTO? {
        guard let requestURL = URL(string: "\(baseURL)/creators/\(username)") else { return nil }

        guard let (data, response) = try? await URLSession.shared.data(from: requestURL),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {
            return nil
        }

        return try? JSONDecoder().decode(InstagramUserDTO.self, from: data)
    }
}

struct FolderDTO: Codable, Identifiable {
    var id: String
    var user_id: String
    var name: String
    var emoji: String?
    var sort_order: Int
    var recipe_count: Int?
}

struct IngredientDTO: Codable, Identifiable {
    var id: String { name }
    let name: String
    let price_tier: String?
    let availability: String?
    let price_per_unit: Double?
    let price_unit: String?
    let price_updated_at: String?

    var priceTierEmoji: String? {
        switch price_tier {
        case "cheap": return "₺"
        case "neutral": return "₺₺"
        case "expensive": return "₺₺₺"
        default: return nil
        }
    }

    var formattedPrice: String? {
        guard let price = price_per_unit, let unit = price_unit else { return nil }
        return String(format: "%.2f ₺/%@", price, unit)
    }

    var availabilityIcon: String? {
        switch availability {
        case "easy": return "checkmark.circle"
        case "neutral": return "minus.circle"
        case "rare": return "exclamationmark.circle"
        default: return nil
        }
    }
}

struct InstagramUserDTO: Codable {
    let username: String
    let profile_picture_url: String?
}

struct RecipeCostDTO: Codable {
    let estimated_cost: Double?
    let currency: String?
    let priced_count: Int
    let total_count: Int
    let ingredients: [IngredientCostDTO]
}

struct IngredientCostDTO: Codable {
    let name: String
    let measure: String?
    let price_per_unit: Double?
    let price_unit: String?
    let estimated_qty: Double?
    let estimated_cost: Double?
}

/// DTO matching the backend API shape.
struct RecipeDTO: Codable {
    var id: String?
    var platform: String
    var platform_user: String?
    var url: String
    var likes_count: Int?
    var comments_count: Int?
    var caption: String?

    var title: String
    var description: String

    var ingredients_with_measures: [[String: String]]
    var ingredients_without_measures: [String]
    var servings: Int?

    var calories_total_kcal: Double?
    var calories_total_joules: Double?
    var calories_per_serving_kcal: Double?
    var protein_grams: Double?
    var carbs_grams: Double?
    var fat_grams: Double?
    var fiber_grams: Double?

    var tags: [String]?
    var cooking_time: String?
    var cooking_time_minutes: Int?
    var cuisine: String?
    var difficulty: String?
    var health_score: Double?
    var thumbnail_url: String?
    var thumbnail_base64: String?

    var requested_by: String
    var user_id: String?
    var folder_id: String?
}

extension RecipeDTO {
    /// Convert from ProcessedRecipe (Claude output) to DTO for saving.
    static func from(
        processed: ProcessedRecipe,
        url: String,
        platform: String,
        caption: String?,
        requestedBy: String,
        userId: String? = nil
    ) -> RecipeDTO {
        RecipeDTO(
            platform: platform,
            platform_user: processed.platformUser,
            url: url,
            likes_count: processed.likesCount,
            comments_count: processed.commentsCount,
            caption: caption,
            title: processed.title,
            description: processed.instructions,
            ingredients_with_measures: processed.ingredients.map {
                ["name": $0.name, "amount": $0.amount]
            },
            ingredients_without_measures: processed.baseIngredients,
            servings: processed.servings,
            calories_total_kcal: processed.caloriesTotalKcal,
            calories_total_joules: processed.caloriesTotalKcal.map { $0 * 4.184 },
            calories_per_serving_kcal: processed.caloriesPerServingKcal,
            protein_grams: processed.proteinGrams,
            carbs_grams: processed.carbsGrams,
            fat_grams: processed.fatGrams,
            fiber_grams: processed.fiberGrams,
            tags: processed.tags,
            cooking_time: nil,
            cooking_time_minutes: processed.cookingTimeMinutes,
            cuisine: processed.cuisine,
            difficulty: processed.difficulty,
            thumbnail_base64: processed.thumbnailData?.base64EncodedString(),
            requested_by: requestedBy,
            user_id: userId
        )
    }

    /// Convert DTO to local SwiftData Recipe. Call from async context.
    func toRecipe(thumbnailData: Data? = nil) -> Recipe {
        let ingredients = ingredients_with_measures.enumerated().map { index, item in
            Ingredient(
                name: item["name"] ?? "",
                amount: item["amount"] ?? "",
                baseName: index < ingredients_without_measures.count ? ingredients_without_measures[index] : nil
            )
        }

        return Recipe(
            title: title,
            ingredients: ingredients,
            instructions: description,
            sourceURL: url,
            thumbnailData: thumbnailData,
            cookingTimeMinutes: cooking_time_minutes,
            cuisine: cuisine,
            tags: tags ?? [],
            likesCount: likes_count,
            servings: servings,
            caloriesTotalKcal: calories_total_kcal,
            caloriesPerServingKcal: calories_per_serving_kcal,
            proteinGrams: protein_grams,
            carbsGrams: carbs_grams,
            fatGrams: fat_grams,
            fiberGrams: fiber_grams,
            platformUser: platform_user,
            platform: platform,
            folderId: folder_id
        )
    }

    /// Convert DTO from backend to ProcessedRecipe for the UI.
    func toProcessedRecipe() -> ProcessedRecipe {
        let ingredients = ingredients_with_measures.enumerated().map { index, item in
            Ingredient(
                name: item["name"] ?? "",
                amount: item["amount"] ?? "",
                baseName: index < ingredients_without_measures.count ? ingredients_without_measures[index] : nil
            )
        }

        return ProcessedRecipe(
            title: title,
            ingredients: ingredients,
            instructions: description,
            cookingTimeMinutes: cooking_time_minutes,
            thumbnailData: nil,
            servings: servings,
            caloriesTotalKcal: calories_total_kcal,
            caloriesPerServingKcal: calories_per_serving_kcal,
            proteinGrams: protein_grams,
            carbsGrams: carbs_grams,
            fatGrams: fat_grams,
            fiberGrams: fiber_grams,
            baseIngredients: ingredients_without_measures,
            difficulty: difficulty,
            cuisine: cuisine,
            tags: tags ?? [],
            platformUser: platform_user,
            likesCount: likes_count,
            commentsCount: comments_count
        )
    }
}
