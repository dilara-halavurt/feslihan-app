import Foundation

enum APIService {
    // For simulator: localhost works. For physical device, use your Mac's local IP.
    static let baseURL = "http://localhost:3000"

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

    /// Fetch all known ingredient names from the backend.
    static func fetchIngredients() async -> [String] {
        guard let requestURL = URL(string: "\(baseURL)/ingredients") else { return [] }

        guard let (data, response) = try? await URLSession.shared.data(from: requestURL),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {
            return []
        }

        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
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

struct InstagramUserDTO: Codable {
    let username: String
    let profile_picture_url: String?
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
        let ingredients = ingredients_with_measures.map { item in
            Ingredient(
                name: item["name"] ?? "",
                amount: item["amount"] ?? ""
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
            platform: platform
        )
    }

    /// Convert DTO from backend to ProcessedRecipe for the UI.
    func toProcessedRecipe() -> ProcessedRecipe {
        let ingredients = ingredients_with_measures.map { item in
            Ingredient(
                name: item["name"] ?? "",
                amount: item["amount"] ?? ""
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
