import Foundation
import SwiftData

@Model
final class Recipe {
    var id: UUID
    var title: String
    var ingredients: [Ingredient]
    var instructions: String
    var sourceURL: String?
    var thumbnailData: Data?
    var cookingTimeMinutes: Int?
    var cuisine: String?
    var difficulty: String?
    var tags: [String]
    var likesCount: Int?
    var servings: Int?
    var caloriesTotalKcal: Double?
    var caloriesPerServingKcal: Double?
    var proteinGrams: Double?
    var carbsGrams: Double?
    var fatGrams: Double?
    var fiberGrams: Double?
    var platformUser: String?
    var platform: String?
    var folderId: String?
    var freezerFriendly: Bool
    var createdAt: Date

    init(
        title: String,
        ingredients: [Ingredient],
        instructions: String,
        sourceURL: String? = nil,
        thumbnailData: Data? = nil,
        cookingTimeMinutes: Int? = nil,
        cuisine: String? = nil,
        difficulty: String? = nil,
        tags: [String] = [],
        likesCount: Int? = nil,
        servings: Int? = nil,
        caloriesTotalKcal: Double? = nil,
        caloriesPerServingKcal: Double? = nil,
        proteinGrams: Double? = nil,
        carbsGrams: Double? = nil,
        fatGrams: Double? = nil,
        fiberGrams: Double? = nil,
        platformUser: String? = nil,
        platform: String? = nil,
        folderId: String? = nil,
        freezerFriendly: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.ingredients = ingredients
        self.instructions = instructions
        self.sourceURL = sourceURL
        self.thumbnailData = thumbnailData
        self.cookingTimeMinutes = cookingTimeMinutes
        self.cuisine = cuisine
        self.difficulty = difficulty
        self.tags = tags
        self.likesCount = likesCount
        self.servings = servings
        self.caloriesTotalKcal = caloriesTotalKcal
        self.caloriesPerServingKcal = caloriesPerServingKcal
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.platformUser = platformUser
        self.platform = platform
        self.folderId = folderId
        self.freezerFriendly = freezerFriendly
        self.createdAt = Date()
    }
}

struct Ingredient: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var amount: String
    var baseName: String?
}
