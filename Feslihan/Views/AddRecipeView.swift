import SwiftUI
import SwiftData
import ClerkKit

struct AddRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var subscription: SubscriptionService
    @State private var showPaywall = false

    @State private var urlText = ""
    @State private var fetchedCaption: String?
    @State private var captionError: String?
    @State private var isFetchingCaption = false
    @State private var processingState: ProcessingState = .idle
    @State private var processedRecipe: ProcessedRecipe?
    @State private var errorMessage: String?

    enum ProcessingState {
        case idle
        case fetchingCaption
        case extractingFrames
        case extractingAudio
        case transcribing
        case analyzingRecipe
        case done
        case error
    }

    private var canProcess: Bool {
        !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                switch processingState {
                case .idle:
                    idleView
                case .fetchingCaption, .extractingFrames, .extractingAudio, .transcribing, .analyzingRecipe:
                    processingView
                case .done:
                    if let recipe = processedRecipe {
                        resultView(recipe)
                    }
                case .error:
                    errorView
                }
            }
            .navigationTitle("Yeni Tarif")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DS.ink)
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Idle View

    private var idleView: some View {
        ZStack {
            DS.cream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tarif Ekle")
                            .font(.system(size: 26, weight: .semibold, design: .serif))
                            .foregroundStyle(DS.ink)

                        Text("Bir video veya tarif linki yapıştır, tarifi senin için çıkaralım.")
                            .font(.bodyText())
                            .foregroundStyle(DS.smoke)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // URL input + paste button
                    HStack(spacing: 8) {
                        TextField("Link yapıştır…", text: $urlText)
                            .textContentType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.bodyText())
                            .padding(14)
                            .background(DS.sand)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(DS.stone, lineWidth: 1)
                            )

                        Button {
                            if let clip = UIPasteboard.general.string {
                                urlText = clip
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.system(size: 14))
                                Text("Yapıştır")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(DS.ember)
                            .padding(.horizontal, 16)
                            .frame(height: 46)
                            .background(DS.emberLight)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.horizontal, 20)

                    // Platform icons
                    HStack(spacing: 10) {
                        Text("Desteklenen:")
                            .font(.captionText())
                            .foregroundStyle(DS.dust)

                        ForEach(["♪", "◎", "𝕏"], id: \.self) { glyph in
                            Text(glyph)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(DS.smoke)
                                .frame(width: 36, height: 36)
                                .background(DS.sand)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        Image(systemName: "fork.knife")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DS.smoke)
                            .frame(width: 36, height: 36)
                            .background(DS.sand)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal, 20)

                    Button(action: processAll) {
                        Text("Tarif Ekle")
                            .font(.buttonFont())
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(canProcess ? DS.ember : DS.stone)
                            .foregroundStyle(canProcess ? DS.flour : DS.dust)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: canProcess ? DS.shadowButton : .clear, radius: 8, y: 4)
                    }
                    .disabled(!canProcess)
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - Processing View

    private var processingView: some View {
        ZStack {
            DS.cream.ignoresSafeArea()

            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tarif Ekle")
                        .font(.system(size: 26, weight: .semibold, design: .serif))
                        .foregroundStyle(DS.ink)

                    Text(isWebRecipe
                        ? "Tarif sitesinden bilgiler çıkartılıyor…"
                        : "Bir video linki yapıştır, tarifi senin için çıkaralım.")
                        .font(.bodyText())
                        .foregroundStyle(DS.smoke)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Processing checklist card
                VStack(spacing: 0) {
                    if isWebRecipe {
                        checklistRow("Tarif bilgileri", state: checkState(for: .fetchingCaption))
                        Divider().background(DS.stone)
                        checklistRow("Besin değerleri", state: checkState(for: .analyzingRecipe))
                    } else {
                        checklistRow("Video bilgileri", state: checkState(for: .fetchingCaption))
                        Divider().background(DS.stone)
                        checklistRow("Ses çıkartma", state: checkState(for: .extractingAudio))
                        Divider().background(DS.stone)
                        checklistRow("Yazı çevirme", state: checkState(for: .transcribing))
                        Divider().background(DS.stone)
                        checklistRow("Tarif analizi", state: checkState(for: .analyzingRecipe))
                    }
                }
                .background(DS.flour)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: DS.shadowCard, radius: 4, y: 2)

                Text("Bir dakika sürmez, ocağı yakmaya hazırlan…")
                    .font(.handwritten())
                    .foregroundStyle(DS.smoke)
                    .padding(.top, 8)

                Spacer()

                Button {} label: {
                    Text("İşleniyor…")
                        .font(.buttonFont())
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(DS.stone)
                        .foregroundStyle(DS.dust)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(true)
            }
            .padding(20)
        }
    }

    private enum CheckState { case done, active, waiting }

    private func checkState(for step: ProcessingState) -> CheckState {
        let order: [ProcessingState] = [.fetchingCaption, .extractingAudio, .transcribing, .analyzingRecipe]
        guard let targetIdx = order.firstIndex(of: step),
              let currentIdx = order.firstIndex(of: processingState) else { return .waiting }
        if targetIdx < currentIdx { return .done }
        if targetIdx == currentIdx { return .active }
        return .waiting
    }

    @ViewBuilder
    private func checklistRow(_ label: String, state: CheckState) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(state == .done ? DS.ember : state == .active ? DS.emberLight : DS.sand)
                    .frame(width: 26, height: 26)

                if state == .done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DS.flour)
                } else if state == .active {
                    Circle()
                        .fill(DS.ember)
                        .frame(width: 9, height: 9)
                }
            }

            Text(label)
                .font(.bodyText())
                .foregroundStyle(state == .waiting ? DS.dust : DS.ink)
                .fontWeight(state == .active ? .bold : .regular)

            Spacer()

            if state == .done {
                Text("tamam")
                    .font(.captionText())
                    .foregroundStyle(DS.ember)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
    }

    // MARK: - Result View

    private func resultView(_ recipe: ProcessedRecipe) -> some View {
        ZStack {
            DS.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(recipe.title)
                        .font(.displayTitle())
                        .foregroundStyle(DS.ink)

                    Rectangle()
                        .fill(DS.stone)
                        .frame(height: 1)

                    Text("Malzemeler")
                        .font(.sectionHeader())
                        .foregroundStyle(DS.ink)

                    IngredientsView(ingredients: recipe.ingredients)

                    Rectangle()
                        .fill(DS.stone)
                        .frame(height: 1)

                    Text("Yapılış")
                        .font(.sectionHeader())
                        .foregroundStyle(DS.ink)

                    Text(recipe.instructions)
                        .font(.bodyText())
                        .foregroundStyle(DS.ink)
                        .lineSpacing(4)

                    Button(action: saveRecipe) {
                        Text("Tarifi Kaydet")
                            .font(.buttonFont())
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(DS.ember)
                            .foregroundStyle(DS.cream)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        ZStack {
            DS.cream.ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(DS.ember)
                Text("Hata")
                    .font(.displayTitle())
                    .foregroundStyle(DS.ink)
                Text(errorMessage ?? "Bilinmeyen bir hata oluştu")
                    .font(.bodyText())
                    .foregroundStyle(DS.smoke)
                    .multilineTextAlignment(.center)
                Button("Tekrar Dene") {
                    processingState = .idle
                    errorMessage = nil
                }
                .font(.buttonFont())
                .foregroundStyle(DS.ember)
                .padding(.top)
                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Status

    private var statusText: String {
        switch processingState {
        case .fetchingCaption: return "Açıklama getiriliyor..."
        case .extractingFrames: return "Video analiz ediliyor..."
        case .extractingAudio: return "Ses ayıklanıyor..."
        case .transcribing: return "Yazıya çevriliyor..."
        case .analyzingRecipe: return "Tarif hazırlanıyor..."
        default: return ""
        }
    }

    private var statusDescription: String {
        switch processingState {
        case .fetchingCaption: return "Video açıklaması indiriliyor"
        case .extractingFrames: return "Videodan kareler çıkarılıyor"
        case .extractingAudio: return "Videodan ses dosyası oluşturuluyor"
        case .transcribing: return "Konuşmalar yazıya çevriliyor"
        case .analyzingRecipe: return "Tüm veriler birlikte analiz ediliyor"
        default: return ""
        }
    }

    // MARK: - Actions

    private func fetchCaption() {
        let url = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }

        isFetchingCaption = true
        captionError = nil
        fetchedCaption = nil
        Task {
            do {
                let result = try await CaptionService.fetchCaption(from: url)
                fetchedCaption = result.caption
            } catch {
                captionError = "Açıklama alınamadı. Link'i kontrol edin."
            }
            isFetchingCaption = false
        }
    }

    private var trimmedURL: String {
        let raw = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip tracking/sharing query params (igsh, utm_, etc.)
        guard var components = URLComponents(string: raw) else { return raw }
        components.queryItems = nil
        components.fragment = nil
        return components.url?.absoluteString ?? raw
    }

    private func detectPlatform() -> String {
        let host = URL(string: trimmedURL)?.host?.lowercased() ?? ""
        if host.contains("instagram") { return "instagram" }
        if host.contains("tiktok") { return "tiktok" }
        if host.contains("twitter") || host.contains("x.com") { return "x" }
        if host.contains("nefisyemektarifleri") { return "nefisyemektarifleri" }
        return "other"
    }

    private var isWebRecipe: Bool {
        detectPlatform() == "nefisyemektarifleri"
    }

    private func processAll() {
        guard canProcess else { return }

        if !subscription.canAddRecipe {
            showPaywall = true
            return
        }

        Task {
            do {
                processingState = .analyzingRecipe
                if let cached = await APIService.lookup(url: trimmedURL) {
                    // Create user-recipe mapping for existing recipe
                    var dto = cached
                    dto.user_id = Clerk.shared.user?.id
                    _ = await APIService.save(recipe: dto)

                    try await Task.sleep(for: .seconds(Double.random(in: 4...5)))
                    processedRecipe = cached.toProcessedRecipe()
                    subscription.recordRecipeAdded()
                    processingState = .done
                    return
                }

                if isWebRecipe {
                    try await processWebRecipe()
                } else {
                    try await processVideoRecipe()
                }

                subscription.recordRecipeAdded()
                processingState = .done
            } catch {
                errorMessage = error.localizedDescription
                processingState = .error
            }
        }
    }

    private func processWebRecipe() async throws {
        processingState = .fetchingCaption
        let scraped = try await APIService.scrapeWebRecipe(url: trimmedURL)

        processingState = .analyzingRecipe

        // Download thumbnail if URL provided
        var thumbnailBase64: String?
        if let thumbURL = scraped.thumbnail_url {
            let thumbData = await CaptionService.downloadImage(from: thumbURL)
            thumbnailBase64 = thumbData?.base64EncodedString()
        }

        var dto = RecipeDTO(
            platform: "nefisyemektarifleri",
            platform_user: scraped.platform_user,
            url: trimmedURL,
            likes_count: 0,
            comments_count: 0,
            caption: nil,
            title: scraped.title,
            description: scraped.instructions,
            ingredients_with_measures: scraped.ingredients.map {
                var dict = ["name": $0.name, "amount": $0.amount]
                if let ingId = $0.ingredient_id, !ingId.isEmpty { dict["ingredient_id"] = ingId }
                return dict
            },
            ingredients_without_measures: scraped.base_ingredients,
            servings: scraped.servings,
            calories_total_kcal: scraped.calories_total_kcal,
            calories_total_joules: scraped.calories_total_kcal.map { $0 * 4.184 },
            calories_per_serving_kcal: scraped.calories_per_serving_kcal,
            protein_grams: scraped.protein_grams,
            carbs_grams: scraped.carbs_grams,
            fat_grams: scraped.fat_grams,
            fiber_grams: scraped.fiber_grams,
            tags: scraped.tags,
            cooking_time_minutes: scraped.cooking_time_minutes,
            cuisine: scraped.cuisine,
            difficulty: scraped.difficulty,
            thumbnail_base64: thumbnailBase64,
            freezer_friendly: scraped.freezer_friendly,
            requested_by: Clerk.shared.user?.id ?? "default",
            user_id: Clerk.shared.user?.id
        )

        guard await APIService.save(recipe: dto) != nil else {
            throw FeslihanError.recipeParseFailed
        }

        processedRecipe = ProcessedRecipe(
            title: scraped.title,
            ingredients: scraped.ingredients.map { Ingredient(name: $0.name, amount: $0.amount) },
            instructions: scraped.instructions,
            cookingTimeMinutes: scraped.cooking_time_minutes,
            thumbnailData: nil,
            servings: scraped.servings,
            caloriesTotalKcal: scraped.calories_total_kcal,
            caloriesPerServingKcal: scraped.calories_per_serving_kcal,
            proteinGrams: scraped.protein_grams,
            carbsGrams: scraped.carbs_grams,
            fatGrams: scraped.fat_grams,
            fiberGrams: scraped.fiber_grams,
            baseIngredients: scraped.base_ingredients,
            difficulty: scraped.difficulty,
            cuisine: scraped.cuisine,
            tags: scraped.tags,
            platformUser: scraped.platform_user,
            likesCount: 0,
            commentsCount: 0,
            freezerFriendly: scraped.freezer_friendly
        )
    }

    private func processVideoRecipe() async throws {
        processingState = .fetchingCaption
        let captionResult = try await CaptionService.fetchCaption(from: trimmedURL)
        guard !captionResult.caption.isEmpty else {
            throw FeslihanError.captionFetchFailed
        }

        // Try to extract audio from the video for transcription
        var audioData: Data?
        processingState = .extractingAudio
        if let videoURL = URL(string: trimmedURL) {
            do {
                let audioURL = try await AudioExtractor.extractAudio(from: videoURL)
                audioData = try Data(contentsOf: audioURL)
                try? FileManager.default.removeItem(at: audioURL)
            } catch {
                print("[Audio] Extraction failed, continuing without audio: \(error)")
            }
        }

        processingState = .analyzingRecipe
        let recipe = try await ClaudeService.analyzeRecipe(
            transcription: "",
            caption: captionResult.caption,
            audio: audioData
        )

        var dto = RecipeDTO.from(
            processed: recipe,
            url: trimmedURL,
            platform: detectPlatform(),
            caption: captionResult.caption,
            requestedBy: Clerk.shared.user?.id ?? "default",
            userId: Clerk.shared.user?.id
        )
        dto.thumbnail_base64 = captionResult.thumbnailData?.base64EncodedString()
        dto.creator_profile_pic_base64 = captionResult.authorProfilePicData?.base64EncodedString()
        // Prefer oEmbed author over Claude's extraction
        if let author = captionResult.authorName, !author.isEmpty {
            dto.platform_user = author
        }
        // For Instagram: fetch profile pic from the device (servers get blocked)
        if dto.creator_profile_pic_base64 == nil, let username = dto.platform_user {
            let picData = await CaptionService.fetchInstagramProfilePic(username: username)
            dto.creator_profile_pic_base64 = picData?.base64EncodedString()
        }
        guard await APIService.save(recipe: dto) != nil else {
            throw FeslihanError.recipeParseFailed
        }

        processedRecipe = recipe
    }

    private func saveRecipe() {
        guard let processed = processedRecipe else { return }

        let recipe = Recipe(
            title: processed.title,
            ingredients: processed.ingredients,
            instructions: processed.instructions,
            sourceURL: urlText.isEmpty ? nil : urlText,
            thumbnailData: processed.thumbnailData,
            cookingTimeMinutes: processed.cookingTimeMinutes,
            cuisine: processed.cuisine,
            difficulty: processed.difficulty,
            tags: processed.tags,
            likesCount: processed.likesCount,
            servings: processed.servings,
            caloriesTotalKcal: processed.caloriesTotalKcal,
            caloriesPerServingKcal: processed.caloriesPerServingKcal,
            proteinGrams: processed.proteinGrams,
            carbsGrams: processed.carbsGrams,
            fatGrams: processed.fatGrams,
            fiberGrams: processed.fiberGrams,
            platformUser: processed.platformUser,
            platform: detectPlatform(),
            freezerFriendly: processed.freezerFriendly
        )

        modelContext.insert(recipe)
        dismiss()
    }
}
