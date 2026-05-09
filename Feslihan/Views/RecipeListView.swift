import SwiftUI
import SwiftData
import ClerkKit

struct RecipeListView: View {
    var onBack: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    @State private var showAddRecipe = false
    @State private var searchText = ""
    @State private var folders: [FolderDTO] = []
    @State private var selectedFolder: FolderDTO? = nil
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    @State private var newFolderEmoji = ""
    @State private var recipeToDelete: Recipe?
    @State private var filters = RecipeFilters()
    @State private var showFilterSheet = false
    @State private var ingredientPriceTiers: [String: String] = [:]
    @AppStorage("recipeSortOption") private var sortOptionRaw = RecipeSortOption.newest.rawValue

    private var sortOption: RecipeSortOption {
        RecipeSortOption(rawValue: sortOptionRaw) ?? .newest
    }

    private var filtered: [Recipe] {
        var base: [Recipe]
        if let folder = selectedFolder {
            base = recipes.filter { $0.folderId == folder.id }
        } else {
            base = Array(recipes)
        }
        if !searchText.isEmpty {
            base = base.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        if filters.isActive {
            base = base.filter { matchesFilters($0) }
        }
        return sorted(base)
    }

    private func sorted(_ recipes: [Recipe]) -> [Recipe] {
        switch sortOption {
        case .newest:
            return recipes.sorted { $0.createdAt > $1.createdAt }
        case .alphabetical:
            return recipes.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .cookingTime:
            return recipes.sorted {
                ($0.cookingTimeMinutes ?? Int.max) < ($1.cookingTimeMinutes ?? Int.max)
            }
        case .calories:
            return recipes.sorted {
                ($0.caloriesPerServingKcal ?? .greatestFiniteMagnitude) < ($1.caloriesPerServingKcal ?? .greatestFiniteMagnitude)
            }
        }
    }

    private func matchesFilters(_ recipe: Recipe) -> Bool {
        if !filters.tags.isEmpty {
            let recipeTags = Set(recipe.tags.map { $0.lowercased() })
            if recipeTags.isDisjoint(with: filters.tags.map { $0.lowercased() }) {
                return false
            }
        }
        if !filters.cuisines.isEmpty {
            guard let cuisine = recipe.cuisine?.lowercased(),
                  filters.cuisines.map({ $0.lowercased() }).contains(cuisine) else {
                return false
            }
        }
        if !filters.difficulties.isEmpty {
            guard let difficulty = recipe.difficulty?.lowercased(),
                  filters.difficulties.contains(difficulty) else {
                return false
            }
        }
        if let range = filters.cookingTimeRange {
            guard let minutes = recipe.cookingTimeMinutes,
                  range.minutesRange.contains(minutes) else {
                return false
            }
        }
        if !filters.priceTiers.isEmpty {
            guard let tier = recipePriceTier(recipe),
                  filters.priceTiers.contains(tier) else {
                return false
            }
        }
        return true
    }

    private func recipePriceTier(_ recipe: Recipe) -> String? {
        var foundAny = false
        var hasExpensive = false
        var hasNeutral = false
        for ingredient in recipe.ingredients {
            let key = (ingredient.baseName ?? ingredient.name).lowercased()
            guard let tier = ingredientPriceTiers[key] else { continue }
            foundAny = true
            switch tier {
            case "expensive": hasExpensive = true
            case "neutral": hasNeutral = true
            default: break
            }
        }
        guard foundAny else { return nil }
        if hasExpensive { return "expensive" }
        if hasNeutral { return "neutral" }
        return "cheap"
    }

    private var availableTags: [String] {
        Array(Set(recipes.flatMap { $0.tags })).sorted()
    }

    private var availableCuisines: [String] {
        Array(Set(recipes.compactMap { $0.cuisine })).sorted()
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

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

                            if searchText.isEmpty && selectedFolder == nil {
                                // Folders section
                                if !folders.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Klasörlerim")
                                            .font(.displayTitle())
                                            .foregroundStyle(DS.ink)
                                            .padding(.horizontal, 16)

                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 12) {
                                                // Create folder button
                                                Button {
                                                    showCreateFolder = true
                                                } label: {
                                                    VStack(spacing: 8) {
                                                        ZStack {
                                                            RoundedRectangle(cornerRadius: 14)
                                                                .strokeBorder(DS.dust.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                                                .frame(width: 100, height: 100)
                                                            Image(systemName: "plus")
                                                                .font(.system(size: 24, weight: .medium))
                                                                .foregroundStyle(DS.dust)
                                                        }
                                                        Text("Yeni Klasör")
                                                            .font(.system(size: 12, weight: .medium))
                                                            .foregroundStyle(DS.smoke)
                                                    }
                                                }
                                                .buttonStyle(.plain)

                                                ForEach(folders) { folder in
                                                    Button {
                                                        selectedFolder = folder
                                                    } label: {
                                                        FolderCard(folder: folder, recipes: recipes)
                                                    }
                                                    .buttonStyle(.plain)
                                                    .contextMenu {
                                                        Button(role: .destructive) {
                                                            Task { await deleteFolder(folder) }
                                                        } label: {
                                                            Label("Klasörü Sil", systemImage: "trash")
                                                        }
                                                    }
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                        }
                                    }
                                } else {
                                    // Show create folder prompt when no folders exist
                                    Button {
                                        showCreateFolder = true
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "folder.badge.plus")
                                                .font(.system(size: 18, weight: .medium))
                                            Text("Klasör Oluştur")
                                                .font(.system(size: 15, weight: .medium))
                                        }
                                        .foregroundStyle(DS.ember)
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 20)
                                        .background(DS.ember.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 16)
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
                                            .contextMenu {
                                                folderContextMenu(for: recipe)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            } else if selectedFolder != nil {
                                // Folder contents
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("\(filtered.count) tarif")
                                        .font(.label())
                                        .foregroundStyle(DS.smoke)
                                        .padding(.horizontal, 16)

                                    LazyVGrid(columns: columns, spacing: 12) {
                                        ForEach(filtered) { recipe in
                                            NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                                                RecipeCard(recipe: recipe)
                                            }
                                            .buttonStyle(.plain)
                                            .contextMenu {
                                                Button {
                                                    Task { await moveRecipeToFolder(recipe, folder: nil) }
                                                } label: {
                                                    Label("Klasörden Çıkar", systemImage: "folder.badge.minus")
                                                }
                                                folderContextMenu(for: recipe)
                                            }
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
                if selectedFolder != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        BackButton {
                            selectedFolder = nil
                        }
                    }
                } else if let onBack {
                    ToolbarItem(placement: .navigationBarLeading) {
                        BackButton(action: onBack)
                    }
                }
                ToolbarItem(placement: .principal) {
                    if let folder = selectedFolder {
                        HStack(spacing: 6) {
                            if let emoji = folder.emoji, !emoji.isEmpty {
                                Text(emoji)
                            }
                            Text(folder.name)
                                .font(.displayTitle())
                                .foregroundStyle(DS.ink)
                        }
                    } else {
                        Text("Tariflerim")
                            .font(.displayTitle())
                            .foregroundStyle(DS.ink)
                    }
                }
                if !recipes.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Picker("Sırala", selection: $sortOptionRaw) {
                                ForEach(RecipeSortOption.allCases) { option in
                                    Label(option.label, systemImage: option.icon)
                                        .tag(option.rawValue)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(DS.ink)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showFilterSheet = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: filters.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(filters.isActive ? DS.ember : DS.ink)
                                if filters.isActive {
                                    Text("\(filters.activeCount)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(minWidth: 14, minHeight: 14)
                                        .padding(.horizontal, 3)
                                        .background(DS.honey)
                                        .clipShape(Capsule())
                                        .offset(x: 6, y: -6)
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                RecipeFilterSheet(
                    filters: $filters,
                    availableTags: availableTags,
                    availableCuisines: availableCuisines
                )
            }
            .alert("Yeni Klasör", isPresented: $showCreateFolder) {
                TextField("Klasör adı", text: $newFolderName)
                TextField("Emoji (opsiyonel)", text: $newFolderEmoji)
                Button("Oluştur") {
                    Task { await createFolder() }
                }
                Button("İptal", role: .cancel) {
                    newFolderName = ""
                    newFolderEmoji = ""
                }
            }
            .alert("Tarifi Sil", isPresented: Binding(
                get: { recipeToDelete != nil },
                set: { if !$0 { recipeToDelete = nil } }
            )) {
                Button("Sil", role: .destructive) {
                    if let recipe = recipeToDelete {
                        Task { await deleteRecipe(recipe) }
                    }
                }
                Button("İptal", role: .cancel) {
                    recipeToDelete = nil
                }
            } message: {
                Text("Bu tarif koleksiyonundan kaldırılacak. Emin misin?")
            }
            .task {
                await syncFromBackend()
                await loadFolders()
                await loadIngredientPriceTiers()
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
                existing.difficulty = dto.difficulty
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
                existing.folderId = dto.folder_id
            } else {
                let thumbData = await CaptionService.downloadImage(from: fullThumbURL)
                modelContext.insert(dto.toRecipe(thumbnailData: thumbData))
            }
        }

        try? modelContext.save()
    }

    private func loadFolders() async {
        guard let userId = Clerk.shared.user?.id else { return }
        folders = await APIService.fetchFolders(userId: userId)
    }

    private func loadIngredientPriceTiers() async {
        let allIngredients = await APIService.fetchIngredients()
        var tiers: [String: String] = [:]
        for dto in allIngredients {
            if let tier = dto.price_tier {
                tiers[dto.name.lowercased()] = tier
            }
        }
        ingredientPriceTiers = tiers
    }

    private func createFolder() async {
        guard let userId = Clerk.shared.user?.id, !newFolderName.isEmpty else { return }
        if let folder = await APIService.createFolder(
            userId: userId,
            name: newFolderName,
            emoji: newFolderEmoji.isEmpty ? nil : newFolderEmoji
        ) {
            folders.append(folder)
        }
        newFolderName = ""
        newFolderEmoji = ""
    }

    private func deleteFolder(_ folder: FolderDTO) async {
        guard await APIService.deleteFolder(id: folder.id) else { return }
        folders.removeAll { $0.id == folder.id }
        // Clear folderId on local recipes
        for recipe in recipes where recipe.folderId == folder.id {
            recipe.folderId = nil
        }
        try? modelContext.save()
    }

    @ViewBuilder
    private func folderContextMenu(for recipe: Recipe) -> some View {
        if !folders.isEmpty {
            Menu("Klasöre Taşı") {
                ForEach(folders) { folder in
                    Button {
                        Task { await moveRecipeToFolder(recipe, folder: folder) }
                    } label: {
                        Label(
                            "\(folder.emoji ?? "") \(folder.name)",
                            systemImage: recipe.folderId == folder.id ? "checkmark.circle.fill" : "folder"
                        )
                    }
                }
                if recipe.folderId != nil {
                    Divider()
                    Button {
                        Task { await moveRecipeToFolder(recipe, folder: nil) }
                    } label: {
                        Label("Klasörden Çıkar", systemImage: "folder.badge.minus")
                    }
                }
            }
        }
        Divider()
        Button(role: .destructive) {
            recipeToDelete = recipe
        } label: {
            Label("Tarifi Sil", systemImage: "trash")
        }
    }

    private func deleteRecipe(_ recipe: Recipe) async {
        guard let userId = Clerk.shared.user?.id,
              let url = recipe.sourceURL,
              let dto = await APIService.lookup(url: url),
              let backendId = dto.id else { return }

        if await APIService.deleteUserRecipe(userId: userId, recipeId: backendId) {
            modelContext.delete(recipe)
            try? modelContext.save()
        }
    }

    private func moveRecipeToFolder(_ recipe: Recipe, folder: FolderDTO?) async {
        guard let userId = Clerk.shared.user?.id else { return }
        // Fetch the backend recipe ID via lookup
        guard let url = recipe.sourceURL else { return }
        guard let dto = await APIService.lookup(url: url), let backendId = dto.id else { return }

        if await APIService.moveRecipeToFolder(userId: userId, recipeId: backendId, folderId: folder?.id) {
            recipe.folderId = folder?.id
            try? modelContext.save()
            await loadFolders() // refresh counts
        }
    }
}

// MARK: - Folder Card

private struct FolderCard: View {
    let folder: FolderDTO
    let recipes: [Recipe]

    private var folderRecipes: [Recipe] {
        recipes.filter { $0.folderId == folder.id }
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(DS.sand)
                    .frame(width: 100, height: 100)

                if let first = folderRecipes.first,
                   let data = first.thumbnailData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.black.opacity(0.2))
                        )
                } else {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(DS.dust)
                }

                // Emoji overlay
                if let emoji = folder.emoji, !emoji.isEmpty {
                    Text(emoji)
                        .font(.system(size: 28))
                }
            }

            VStack(spacing: 2) {
                Text(folder.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.ink)
                    .lineLimit(1)

                Text("\(folder.recipe_count ?? folderRecipes.count) tarif")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.smoke)
            }
        }
        .frame(width: 100)
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

// MARK: - Sort

enum RecipeSortOption: String, CaseIterable, Identifiable {
    case newest
    case alphabetical
    case cookingTime
    case calories

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newest: return "En Yeni"
        case .alphabetical: return "Alfabetik (A-Z)"
        case .cookingTime: return "Pişirme Süresi"
        case .calories: return "Kalori"
        }
    }

    var icon: String {
        switch self {
        case .newest: return "clock.arrow.circlepath"
        case .alphabetical: return "textformat"
        case .cookingTime: return "timer"
        case .calories: return "flame"
        }
    }
}

// MARK: - Filters

struct RecipeFilters: Equatable {
    var tags: Set<String> = []
    var cuisines: Set<String> = []
    var difficulties: Set<String> = []
    var cookingTimeRange: CookingTimeRange? = nil
    var priceTiers: Set<String> = []

    var activeCount: Int {
        var count = 0
        if !tags.isEmpty { count += 1 }
        if !cuisines.isEmpty { count += 1 }
        if !difficulties.isEmpty { count += 1 }
        if cookingTimeRange != nil { count += 1 }
        if !priceTiers.isEmpty { count += 1 }
        return count
    }

    var isActive: Bool { activeCount > 0 }

    mutating func reset() {
        tags = []
        cuisines = []
        difficulties = []
        cookingTimeRange = nil
        priceTiers = []
    }
}

enum CookingTimeRange: String, CaseIterable, Identifiable, Equatable {
    case under15
    case from15to30
    case from30to60
    case over60

    var id: String { rawValue }

    var label: String {
        switch self {
        case .under15: return "15 dakikadan az"
        case .from15to30: return "15-30 dakika"
        case .from30to60: return "30-60 dakika"
        case .over60: return "1 saatten fazla"
        }
    }

    var minutesRange: ClosedRange<Int> {
        switch self {
        case .under15: return 0...14
        case .from15to30: return 15...30
        case .from30to60: return 31...60
        case .over60: return 61...Int.max
        }
    }
}

private let difficultyOptions: [(value: String, label: String)] = [
    ("low", "Kolay"),
    ("medium", "Orta"),
    ("high", "Zor"),
]

private let priceTierOptions: [(value: String, label: String)] = [
    ("cheap", "Ucuz ₺"),
    ("neutral", "Orta ₺₺"),
    ("expensive", "Pahalı ₺₺₺"),
]

// MARK: - Filter Sheet

struct RecipeFilterSheet: View {
    @Binding var filters: RecipeFilters
    let availableTags: [String]
    let availableCuisines: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !availableTags.isEmpty {
                        FilterSection(title: "Etiket") {
                            FilterChipGrid(
                                items: availableTags,
                                isSelected: { filters.tags.contains($0) },
                                toggle: { tag in
                                    if filters.tags.contains(tag) {
                                        filters.tags.remove(tag)
                                    } else {
                                        filters.tags.insert(tag)
                                    }
                                }
                            )
                        }
                    }

                    if !availableCuisines.isEmpty {
                        FilterSection(title: "Mutfak") {
                            FilterChipGrid(
                                items: availableCuisines,
                                isSelected: { filters.cuisines.contains($0) },
                                toggle: { cuisine in
                                    if filters.cuisines.contains(cuisine) {
                                        filters.cuisines.remove(cuisine)
                                    } else {
                                        filters.cuisines.insert(cuisine)
                                    }
                                }
                            )
                        }
                    }

                    FilterSection(title: "Zorluk") {
                        FilterChipGrid(
                            items: difficultyOptions.map { $0.label },
                            isSelected: { label in
                                guard let value = difficultyOptions.first(where: { $0.label == label })?.value else { return false }
                                return filters.difficulties.contains(value)
                            },
                            toggle: { label in
                                guard let value = difficultyOptions.first(where: { $0.label == label })?.value else { return }
                                if filters.difficulties.contains(value) {
                                    filters.difficulties.remove(value)
                                } else {
                                    filters.difficulties.insert(value)
                                }
                            }
                        )
                    }

                    FilterSection(title: "Pişirme Süresi") {
                        FilterChipGrid(
                            items: CookingTimeRange.allCases.map { $0.label },
                            isSelected: { label in
                                filters.cookingTimeRange?.label == label
                            },
                            toggle: { label in
                                let range = CookingTimeRange.allCases.first { $0.label == label }
                                if filters.cookingTimeRange == range {
                                    filters.cookingTimeRange = nil
                                } else {
                                    filters.cookingTimeRange = range
                                }
                            }
                        )
                    }

                    FilterSection(title: "Fiyat") {
                        FilterChipGrid(
                            items: priceTierOptions.map { $0.label },
                            isSelected: { label in
                                guard let value = priceTierOptions.first(where: { $0.label == label })?.value else { return false }
                                return filters.priceTiers.contains(value)
                            },
                            toggle: { label in
                                guard let value = priceTierOptions.first(where: { $0.label == label })?.value else { return }
                                if filters.priceTiers.contains(value) {
                                    filters.priceTiers.remove(value)
                                } else {
                                    filters.priceTiers.insert(value)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(DS.cream)
            .navigationTitle("Filtrele")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Sıfırla") {
                        filters.reset()
                    }
                    .foregroundStyle(filters.isActive ? DS.ember : DS.dust)
                    .disabled(!filters.isActive)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Tamam") {
                        dismiss()
                    }
                    .foregroundStyle(DS.ember)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct FilterSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.sectionHeader())
                .foregroundStyle(DS.ink)
            content()
        }
    }
}

private struct FilterChipGrid: View {
    let items: [String]
    let isSelected: (String) -> Bool
    let toggle: (String) -> Void

    var body: some View {
        FlexibleHStack(spacing: 8) {
            ForEach(items, id: \.self) { item in
                let selected = isSelected(item)
                Button {
                    toggle(item)
                } label: {
                    Text(item)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(selected ? .white : DS.ink)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(selected ? DS.ember : DS.sand)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct FlexibleHStack: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + (rowWidth > 0 ? spacing : 0)
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth.isFinite ? maxWidth : rowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
