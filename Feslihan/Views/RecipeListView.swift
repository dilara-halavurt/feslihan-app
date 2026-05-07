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

    private var filtered: [Recipe] {
        let base: [Recipe]
        if let folder = selectedFolder {
            base = recipes.filter { $0.folderId == folder.id }
        } else {
            base = Array(recipes)
        }
        if searchText.isEmpty { return base }
        return base.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
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
