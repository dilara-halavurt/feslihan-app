import SwiftUI
import SwiftData
import ClerkKit

struct RecipeListView: View {
    var onBack: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    @State private var showAddRecipe = false
    @State private var searchText = ""

    private var filtered: [Recipe] {
        if searchText.isEmpty { return recipes }
        return recipes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var mostLiked: [Recipe] {
        recipes
            .filter { ($0.likesCount ?? 0) > 0 }
            .sorted { ($0.likesCount ?? 0) > ($1.likesCount ?? 0) }
            .prefix(10)
            .map { $0 }
    }

    private var mostRecent: [Recipe] {
        Array(recipes.prefix(10))
    }

    // Group recipes by tags for the featured carousel
    private var collections: [(title: String, subtitle: String, recipes: [Recipe])] {
        let tagGroups: [(tag: String, title: String, subtitle: String)] = [
            ("kahvaltı", "Kahvaltılıklar", "Güne güzel başla"),
            ("ana yemek", "Ana Yemekler", "Doyurucu ve lezzetli"),
            ("tatlı", "Tatlılar", "Tatlı bir son"),
            ("çorba", "Çorbalar", "Sıcacık bir kase"),
            ("pratik", "Pratik Tarifler", "Hızlı ve kolay"),
            ("sağlıklı", "Sağlıklı Seçimler", "Hafif ve besleyici"),
        ]

        return tagGroups.compactMap { group in
            let matching = recipes.filter { $0.tags.contains(group.tag) }
            guard matching.count >= 2 else { return nil }
            return (group.title, group.subtitle, Array(matching.prefix(8)))
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.cream.ignoresSafeArea()

                if recipes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(DS.dust)
                        Text("Henüz tarif yok")
                            .font(.displayTitle())
                            .foregroundStyle(DS.ink)
                        Text("Video ekleyerek ilk tarifini oluştur")
                            .font(.bodyText())
                            .foregroundStyle(DS.smoke)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Search bar
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(DS.dust)
                                TextField("Tarif ara...", text: $searchText)
                                    .font(.bodyText())
                                if !searchText.isEmpty {
                                    Button {
                                        searchText = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(DS.dust)
                                    }
                                }
                            }
                            .padding(12)
                            .background(DS.sand)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 16)

                            if searchText.isEmpty {
                                // Featured collections carousel
                                if !collections.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Sana Özel Seçimler")
                                            .font(.displayTitle())
                                            .foregroundStyle(DS.ink)
                                            .padding(.horizontal, 16)

                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 12) {
                                                ForEach(collections, id: \.title) { collection in
                                                    CollectionCard(
                                                        title: collection.title,
                                                        subtitle: collection.subtitle,
                                                        recipes: collection.recipes
                                                    )
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                        }
                                    }
                                }

                                // Most liked banner
                                if !mostLiked.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("En Beğenilenler")
                                            .font(.displayTitle())
                                            .foregroundStyle(DS.ink)
                                            .padding(.horizontal, 16)

                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 12) {
                                                ForEach(mostLiked) { recipe in
                                                    NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                                                        RecipeCard(recipe: recipe)
                                                            .frame(width: 160)
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                        }
                                    }
                                }

                                // Most recent banner
                                if !mostRecent.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Yeni Eklenenler")
                                            .font(.displayTitle())
                                            .foregroundStyle(DS.ink)
                                            .padding(.horizontal, 16)

                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 12) {
                                                ForEach(mostRecent) { recipe in
                                                    NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                                                        RecipeCard(recipe: recipe)
                                                            .frame(width: 160)
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                        }
                                    }
                                }

                                // All recipes grid
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Tüm Tarifler")
                                        .font(.displayTitle())
                                        .foregroundStyle(DS.ink)
                                        .padding(.horizontal, 16)

                                    LazyVGrid(columns: columns, spacing: 12) {
                                        ForEach(filtered) { recipe in
                                            NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                                                RecipeCard(recipe: recipe)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            } else {
                                // Search results
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("\(filtered.count) sonuç")
                                        .font(.label())
                                        .foregroundStyle(DS.smoke)
                                        .padding(.horizontal, 16)

                                    LazyVGrid(columns: columns, spacing: 12) {
                                        ForEach(filtered) { recipe in
                                            NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                                                RecipeCard(recipe: recipe)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(.bottom, 80)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onBack {
                    ToolbarItem(placement: .navigationBarLeading) {
                        BackButton(action: onBack)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Tariflerim")
                        .font(.displayTitle())
                        .foregroundStyle(DS.ink)
                }
            }
            .task {
                await syncFromBackend()
            }
        }
    }

    private func syncFromBackend() async {
        guard let userId = Clerk.shared.user?.id else { return }
        let remoteRecipes = await APIService.fetchUserRecipes(userId: userId)
        guard !remoteRecipes.isEmpty else { return }

        let remoteURLs = Set(remoteRecipes.map { $0.url })

        for recipe in recipes {
            guard let url = recipe.sourceURL, remoteURLs.contains(url) else {
                modelContext.delete(recipe)
                continue
            }
        }

        let localByURL = Dictionary(recipes.compactMap { r in
            r.sourceURL.map { ($0, r) }
        }, uniquingKeysWith: { first, _ in first })
        for dto in remoteRecipes {
            let fullThumbURL = dto.thumbnail_url.map { $0.hasPrefix("http") ? $0 : "\(APIService.baseURL)\($0)" }
            if let existing = localByURL[dto.url] {
                if existing.thumbnailData == nil {
                    existing.thumbnailData = await CaptionService.downloadImage(from: fullThumbURL)
                }
                existing.likesCount = dto.likes_count
                existing.cuisine = dto.cuisine
                existing.tags = dto.tags ?? []
                existing.cookingTimeMinutes = dto.cooking_time_minutes
                existing.platformUser = dto.platform_user
                existing.platform = dto.platform
                existing.servings = dto.servings
                existing.caloriesTotalKcal = dto.calories_total_kcal
                existing.caloriesPerServingKcal = dto.calories_per_serving_kcal
                existing.proteinGrams = dto.protein_grams
                existing.carbsGrams = dto.carbs_grams
                existing.fatGrams = dto.fat_grams
                existing.fiberGrams = dto.fiber_grams
            } else {
                let thumbData = await CaptionService.downloadImage(from: fullThumbURL)
                modelContext.insert(dto.toRecipe(thumbnailData: thumbData))
            }
        }

        try? modelContext.save()
    }
}

// MARK: - Collection Card (Hero Carousel)

private struct CollectionCard: View {
    let title: String
    let subtitle: String
    let recipes: [Recipe]

    // Use the first recipe with a thumbnail as hero image
    private var heroRecipe: Recipe? {
        recipes.first { $0.thumbnailData != nil }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background image
            Group {
                if let data = heroRecipe?.thumbnailData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    DS.stone
                }
            }
            .frame(width: 300, height: 360)
            .clipped()

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )

            // Content overlay
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.8))

                HStack(spacing: 8) {
                    // Small recipe thumbnails
                    HStack(spacing: -8) {
                        ForEach(Array(recipes.prefix(3).enumerated()), id: \.offset) { _, recipe in
                            if let data = recipe.thumbnailData,
                               let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 32, height: 32)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(.white, lineWidth: 1.5)
                                    )
                            }
                        }
                    }

                    Spacer()

                    Text("Tarifleri Gör")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Recipe Card (Grid)

private struct RecipeCard: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image
            Group {
                if let data = recipe.thumbnailData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        DS.stone.opacity(0.3)
                        Image(systemName: "fork.knife")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(DS.dust)
                    }
                }
            }
            .frame(height: 180)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 36, alignment: .top)

                HStack(spacing: 4) {
                    if let minutes = recipe.cookingTimeMinutes {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text(minutes >= 60 ? "\(minutes / 60) sa \(minutes % 60 > 0 ? "\(minutes % 60) dk" : "")" : "\(minutes) dk")
                            .font(.system(size: 12))
                    } else if let likes = recipe.likesCount, likes > 0 {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11))
                        Text(formatLikes(likes))
                            .font(.system(size: 12))
                    } else {
                        Image(systemName: "leaf")
                            .font(.system(size: 11))
                        Text("\(recipe.ingredients.count) malzeme")
                            .font(.system(size: 12))
                    }
                }
                .foregroundStyle(DS.smoke)
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
    }

    private func formatLikes(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
