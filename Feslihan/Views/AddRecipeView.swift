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
                VStack(spacing: 24) {
                    Image(systemName: "link")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(DS.ember)
                        .frame(width: 56, height: 56)
                        .background(DS.emberLight)
                        .clipShape(Circle())
                        .padding(.top, 24)

                    VStack(spacing: 8) {
                        Text("Video Linki Ekle")
                            .font(.displayTitle())
                            .foregroundStyle(DS.ink)

                        Text("TikTok, Instagram veya X'ten tarif videosu linkini yapıştırın")
                            .font(.bodyText())
                            .foregroundStyle(DS.smoke)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Video URL")
                            .font(.label())
                            .foregroundStyle(DS.ink)

                        TextField("https://www.tiktok.com/@user/video/...", text: $urlText)
                            .textContentType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.bodyText())
                            .padding(14)
                            .background(DS.sand)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(DS.stone, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Desteklenen Platformlar")
                            .font(.label())
                            .foregroundStyle(DS.ink)

                        VStack(alignment: .leading, spacing: 6) {
                            platformRow("TikTok")
                            platformRow("Instagram Reels")
                            platformRow("X (Twitter)")
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.sand)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)

                    Button(action: processAll) {
                        Text("Tarif Ekle")
                            .font(.buttonFont())
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(canProcess ? DS.ember : DS.ember.opacity(0.4))
                            .foregroundStyle(DS.cream)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(!canProcess)
                    .padding(.horizontal, 20)

                    Text("Video içeriği AI ile transkript edilir ve Türkçe tarif kartına dönüştürülür. İşlem 30-60 saniye sürer.")
                        .font(.captionText())
                        .foregroundStyle(DS.dust)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 24)
                }
            }
        }
    }

    private func platformRow(_ name: String) -> some View {
        HStack(spacing: 8) {
            Text("•")
                .foregroundStyle(DS.smoke)
            Text(name)
                .font(.bodyText())
                .foregroundStyle(DS.ink)
        }
    }

    // MARK: - Processing View

    private var processingView: some View {
        ZStack {
            DS.cream.ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer()
                ProgressView()
                    .scaleEffect(1.3)
                Text(statusText)
                    .font(.sectionHeader())
                    .foregroundStyle(DS.ink)
                Text(statusDescription)
                    .font(.bodyText())
                    .foregroundStyle(DS.smoke)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding()
        }
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
        return "other"
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
                    processedRecipe = cached.toProcessedRecipe()
                    processingState = .done
                    return
                }

                processingState = .fetchingCaption
                guard let captionResult = try? await CaptionService.fetchCaption(from: trimmedURL),
                      !captionResult.caption.isEmpty else {
                    throw FeslihanError.noInputProvided
                }

                processingState = .analyzingRecipe
                let recipe = try await ClaudeService.analyzeRecipe(
                    transcription: "",
                    caption: captionResult.caption,
                    coverImage: captionResult.thumbnailData
                )

                var dto = RecipeDTO.from(
                    processed: recipe,
                    url: trimmedURL,
                    platform: detectPlatform(),
                    caption: captionResult.caption,
                    requestedBy: Clerk.shared.user?.id ?? "default",
                    userId: Clerk.shared.user?.id
                )
                // Prefer oEmbed author over Claude's extraction
                if let author = captionResult.authorName, !author.isEmpty {
                    dto.platform_user = author
                }
                guard await APIService.save(recipe: dto) != nil else {
                    throw FeslihanError.recipeParseFailed
                }

                processedRecipe = recipe
                subscription.recordRecipeAdded()
                processingState = .done
            } catch {
                errorMessage = error.localizedDescription
                processingState = .error
            }
        }
    }

    private func saveRecipe() {
        guard let processed = processedRecipe else { return }

        let recipe = Recipe(
            title: processed.title,
            ingredients: processed.ingredients,
            instructions: processed.instructions,
            sourceURL: urlText.isEmpty ? nil : urlText,
            thumbnailData: processed.thumbnailData,
            cookingTimeMinutes: processed.cookingTimeMinutes
        )

        modelContext.insert(recipe)
        dismiss()
    }
}
