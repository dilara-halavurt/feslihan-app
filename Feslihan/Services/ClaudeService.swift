import Foundation
import ClerkKit

struct ProcessedRecipe {
    let title: String
    let ingredients: [Ingredient]
    let instructions: String
    let cookingTimeMinutes: Int?
    let thumbnailData: Data?
    let servings: Int?
    let caloriesTotalKcal: Double?
    let caloriesPerServingKcal: Double?
    let proteinGrams: Double?
    let carbsGrams: Double?
    let fatGrams: Double?
    let fiberGrams: Double?
    let baseIngredients: [String]
    let difficulty: String?
    let cuisine: String?
    let tags: [String]
    let platformUser: String?
    let likesCount: Int?
    let commentsCount: Int?
}

enum ClaudeService {
    static func analyzeRecipe(transcription: String, caption: String = "", frames: [Data] = [], coverImage: Data? = nil) async throws -> ProcessedRecipe {
        var body: [String: Any] = [
            "caption": caption,
            "transcription": transcription,
            "frames": frames.map { $0.base64EncodedString() }
        ]
        if let coverImage {
            body["cover_image"] = coverImage.base64EncodedString()
        }

        guard let url = URL(string: "\(APIService.baseURL)/ai/analyze") else {
            throw FeslihanError.recipeParseFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw FeslihanError.recipeParseFailed
        }

        if http.statusCode != 200 {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            print("[AI Analyze] HTTP \(http.statusCode): \(responseBody)")
            throw FeslihanError.recipeParseFailed
        }

        let recipeJSON: RecipeJSON
        do {
            recipeJSON = try JSONDecoder().decode(RecipeJSON.self, from: data)
        } catch {
            print("[AI Analyze] JSON parse error: \(error)")
            throw error
        }

        if recipeJSON.isRecipe == false {
            throw FeslihanError.notARecipe
        }

        let thumbnail = coverImage

        return ProcessedRecipe(
            title: recipeJSON.title ?? "",
            ingredients: (recipeJSON.ingredients ?? []).map { ing in
                Ingredient(name: ing.name, amount: ing.amount)
            },
            instructions: recipeJSON.instructions ?? "",
            cookingTimeMinutes: recipeJSON.cookingTimeMinutes,
            thumbnailData: thumbnail,
            servings: recipeJSON.servings,
            caloriesTotalKcal: recipeJSON.caloriesTotalKcal,
            caloriesPerServingKcal: recipeJSON.caloriesPerServingKcal,
            proteinGrams: recipeJSON.proteinGrams,
            carbsGrams: recipeJSON.carbsGrams,
            fatGrams: recipeJSON.fatGrams,
            fiberGrams: recipeJSON.fiberGrams,
            baseIngredients: recipeJSON.baseIngredients ?? [],
            difficulty: recipeJSON.difficulty,
            cuisine: recipeJSON.cuisine,
            tags: recipeJSON.tags ?? [],
            platformUser: recipeJSON.platformUser,
            likesCount: recipeJSON.likesCount,
            commentsCount: recipeJSON.commentsCount
        )
    }

    // MARK: - Meal Plan Generation

    static func generateMealPlan(
        peopleCount: String,
        mealsPerDay: String,
        eatingStyles: [String],
        period: String,
        hasKids: Bool,
        kidsCount: Int,
        prepStyle: String,
        budget: String
    ) async throws -> MealPlan {
        let userId = await Clerk.shared.user?.id ?? ""
        let body: [String: Any] = [
            "people_count": peopleCount,
            "meals_per_day": mealsPerDay,
            "eating_styles": eatingStyles,
            "period": period,
            "has_kids": hasKids,
            "kids_count": kidsCount,
            "prep_style": prepStyle,
            "budget": budget,
            "user_id": userId
        ]

        guard let url = URL(string: "\(APIService.baseURL)/ai/meal-plan") else {
            throw FeslihanError.recipeParseFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw FeslihanError.recipeParseFailed
        }

        if http.statusCode != 200 {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            print("[AI MealPlan] HTTP \(http.statusCode): \(responseBody)")
            throw FeslihanError.recipeParseFailed
        }

        let planJSON = try JSONDecoder().decode(MealPlanJSON.self, from: data)

        let days = planJSON.days.enumerated().map { index, day in
            MealPlanDay(
                id: "day-\(index)",
                name: day.dayName,
                meals: day.meals.map { meal in
                    MealPlanMeal(
                        mealType: meal.mealType,
                        name: meal.name,
                        description: meal.description,
                        calories: meal.calories,
                        ingredients: meal.ingredients
                    )
                }
            )
        }

        return MealPlan(
            days: days,
            shoppingList: planJSON.shoppingList,
            avgCaloriesPerDay: planJSON.avgCaloriesPerDay
        )
    }
}

// MARK: - Meal Plan JSON Types

private struct MealPlanJSON: Decodable {
    let days: [MealPlanDayJSON]
    let shoppingList: [String]
    let avgCaloriesPerDay: Int?

    enum CodingKeys: String, CodingKey {
        case days
        case shoppingList = "shopping_list"
        case avgCaloriesPerDay = "avg_calories_per_day"
    }
}

private struct MealPlanDayJSON: Decodable {
    let dayName: String
    let meals: [MealPlanMealJSON]

    enum CodingKeys: String, CodingKey {
        case dayName = "day_name"
        case meals
    }
}

private struct MealPlanMealJSON: Decodable {
    let mealType: String
    let name: String
    let description: String?
    let calories: Int?
    let ingredients: [String]

    enum CodingKeys: String, CodingKey {
        case mealType = "meal_type"
        case name, description, calories, ingredients
    }
}

// MARK: - Recipe JSON

private struct RecipeJSON: Decodable {
    let isRecipe: Bool?
    let title: String?
    let ingredients: [IngredientJSON]?
    let instructions: String?
    let cookingTime: String?
    let servings: Int?
    let caloriesTotalKcal: Double?
    let caloriesPerServingKcal: Double?
    let proteinGrams: Double?
    let carbsGrams: Double?
    let fatGrams: Double?
    let fiberGrams: Double?
    let baseIngredients: [String]?
    let difficulty: String?
    let cuisine: String?
    let tags: [String]?
    let bestThumbnailIndex: Int?
    let generatedThumbnail: String?
    let platformUser: String?
    let likesCount: Int?
    let commentsCount: Int?
    let cookingTimeMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case title, ingredients, instructions, servings, cuisine, tags
        case isRecipe = "is_recipe"
        case baseIngredients = "base_ingredients"
        case cookingTime = "cooking_time"
        case cookingTimeMinutes = "cooking_time_minutes"
        case caloriesTotalKcal = "calories_total_kcal"
        case caloriesPerServingKcal = "calories_per_serving_kcal"
        case proteinGrams = "protein_grams"
        case carbsGrams = "carbs_grams"
        case fatGrams = "fat_grams"
        case fiberGrams = "fiber_grams"
        case difficulty
        case generatedThumbnail = "generated_thumbnail"
        case bestThumbnailIndex = "best_thumbnail_index"
        case platformUser = "platform_user"
        case likesCount = "likes_count"
        case commentsCount = "comments_count"
    }
}

private struct IngredientJSON: Decodable {
    let name: String
    let amount: String
}
