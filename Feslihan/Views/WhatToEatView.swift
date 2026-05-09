import SwiftUI
import ClerkKit

// MARK: - Main Flow

struct WhatToEatView: View {
    var onBack: (() -> Void)?

    @State private var step: WhatToEatStep = .bubbles
    @State private var selectedIngredients: Set<String> = []
    @State private var selectedTime: CookingTime = .medium
    @State private var selectedCuisine: CuisineType = .any
    @State private var selectedCategory: MealCategory = .any

    enum WhatToEatStep {
        case bubbles, time, cuisine, category, results
    }

    var body: some View {
        ZStack {
            DS.cream.ignoresSafeArea()

            switch step {
            case .bubbles:
                BubbleGameView(selected: $selectedIngredients) {
                    withAnimation(.spring(response: 0.2)) {
                        step = .time
                    }
                }
                .transition(.move(edge: .trailing))

            case .time:
                TimeSelectionView(selectedTime: $selectedTime) {
                    withAnimation(.spring(response: 0.2)) {
                        step = .cuisine
                    }
                }
                .transition(.move(edge: .trailing))

            case .cuisine:
                CuisineSelectionView(selectedCuisine: $selectedCuisine) {
                    withAnimation(.spring(response: 0.2)) {
                        step = .category
                    }
                }
                .transition(.move(edge: .trailing))

            case .category:
                CategorySelectionView(selectedCategory: $selectedCategory) {
                    withAnimation(.spring(response: 0.2)) {
                        step = .results
                    }
                }
                .transition(.move(edge: .trailing))

            case .results:
                SwipeResultsView(
                    ingredients: selectedIngredients,
                    time: selectedTime,
                    cuisine: selectedCuisine,
                    category: selectedCategory
                )
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.spring(response: 0.2), value: step)
        .overlay(alignment: .topLeading) {
            if let onBack {
                BackButton(action: onBack)
                    .padding(.leading, 16)
                    .padding(.top, 8)
            }
        }
    }
}

// MARK: - Cooking Time

enum CookingTime: String, CaseIterable {
    case quick = "15 dk"
    case medium = "30 dk"
    case long = "1 saat"
    case noRush = "Acelem Yok"

    var icon: String {
        switch self {
        case .quick: return "bolt.fill"
        case .medium: return "timer"
        case .long: return "clock"
        case .noRush: return "cup.and.saucer.fill"
        }
    }
}

// MARK: - Cuisine Type

enum CuisineType: String, CaseIterable {
    case any = "Farketmez"
    case italian = "İtalyan"
    case chinese = "Çin"
    case mexican = "Meksika"
    case indian = "Hint"
    case thai = "Tayland"
    case french = "Fransız"
    case japanese = "Japon"
    case mediterranean = "Akdeniz"

    var icon: String {
        switch self {
        case .any: return "globe"
        case .italian: return "fork.knife"
        case .chinese: return "takeoutbag.and.cup.and.straw.fill"
        case .mexican: return "flame.fill"
        case .indian: return "leaf.fill"
        case .thai: return "cup.and.saucer.fill"
        case .french: return "wineglass.fill"
        case .japanese: return "fish.fill"
        case .mediterranean: return "sun.max.fill"
        }
    }
}

// MARK: - Meal Category

enum MealCategory: String, CaseIterable {
    case any = "Farketmez"
    case anaYemek = "Ana Yemek"
    case atistirmalik = "Atıştırmalık"
    case tatli = "Tatlı"
    case corba = "Çorba"
    case salata = "Salata"
    case kahvalti = "Kahvaltı"
    case meze = "Meze"
    case icecek = "İçecek"

    var icon: String {
        switch self {
        case .any: return "square.grid.2x2"
        case .anaYemek: return "fork.knife"
        case .atistirmalik: return "takeoutbag.and.cup.and.straw.fill"
        case .tatli: return "birthday.cake.fill"
        case .corba: return "mug.fill"
        case .salata: return "leaf.fill"
        case .kahvalti: return "sun.horizon.fill"
        case .meze: return "circle.grid.3x3.fill"
        case .icecek: return "cup.and.saucer.fill"
        }
    }
}

struct CategorySelectionView: View {
    @Binding var selectedCategory: MealCategory
    var onDone: () -> Void

    @State private var appeared = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(DS.ember)

                Text("Ne tür bir şey?")
                    .font(.displayTitle())
                    .foregroundStyle(DS.ink)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(MealCategory.allCases.enumerated()), id: \.element) { index, category in
                    Button {
                        selectedCategory = category
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: category.icon)
                                .font(.system(size: 22, weight: .medium))

                            Text(category.rawValue)
                                .font(.label())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundStyle(selectedCategory == category ? DS.cream : DS.ink)
                        .background(selectedCategory == category ? DS.ember : DS.sand)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .scaleEffect(appeared ? 1 : 0.97)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        .easeOut(duration: 0.2).delay(Double(index) * 0.03),
                        value: appeared
                    )
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            Button(action: onDone) {
                Text("Tarifleri Göster")
                    .font(.buttonFont())
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(DS.ember)
                    .foregroundStyle(DS.cream)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Fallback ingredients

private let turkishFixMap: [String: String] = [
    "sarimsak": "Sarımsak",
    "sogan": "Soğan",
    "kiyma": "Kıyma",
    "feslegen": "Fesleğen",
    "cilek": "Çilek",
    "maydanoz": "Maydanoz",
    "dereotu": "Dereotu",
    "nisasta": "Nişasta",
    "paprika": "Paprika",
    "salca": "Salça",
    "pul biber": "Pul Biber",
    "kirmizi biber": "Kırmızı Biber",
    "yesil biber": "Yeşil Biber",
    "taze sogan": "Taze Soğan",
    "beyaz peynir": "Beyaz Peynir",
    "kasar peyniri": "Kaşar Peyniri",
    "yogurt": "Yoğurt",
    "sut": "Süt",
    "tereyagi": "Tereyağı",
    "zeytinyagi": "Zeytinyağı",
    "seker": "Şeker",
    "pirinc": "Pirinç",
    "havuc": "Havuç",
    "kabartma tozu": "Kabartma Tozu",
    "mandalina": "Mandalina",
    "yufka": "Yufka",
    "yulaf": "Yulaf",
    "patlican": "Patlıcan",
    "nohut": "Nohut",
    "mercimek": "Mercimek",
    "bulgur": "Bulgur",
    "ispanak": "Ispanak",
    "ceviz": "Ceviz",
    "fistik": "Fıstık",
    "domates": "Domates",
    "patates": "Patates",
    "tavuk": "Tavuk",
    "peynir": "Peynir",
    "limon": "Limon",
    "kabak": "Kabak",
    "biber": "Biber",
    "tuz": "Tuz",
    "un": "Un",
    "yumurta": "Yumurta",
    "makarna": "Makarna",
    "ekmek": "Ekmek",
    "bal": "Bal",
    "muz": "Muz",
    "elma": "Elma",
    "somon": "Somon",
    "ton baligi": "Ton Balığı",
    "krema": "Krema",
    "sirke": "Sirke",
    "karabiber": "Karabiber",
    "kimyon": "Kimyon",
    "kekik": "Kekik",
    "defne yapragi": "Defne Yaprağı",
    "tatli biber": "Tatlı Biber",
    "sarimsak tozu": "Sarımsak Tozu",
    "sogan tozu": "Soğan Tozu",
    "taze fasulye": "Taze Fasulye",
    "bezelye": "Bezelye",
    "misir": "Mısır",
    "barbunya": "Barbunya",
    "pirasa": "Pırasa",
    "kereviz": "Kereviz",
    "turp": "Turp",
    "roka": "Roka",
    "marul": "Marul",
    "salatalik": "Salatalık",
    "enginar": "Enginar",
    "bamya": "Bamya",
    "lahana": "Lahana",
    "karnabahar": "Karnabahar",
    "brokoli": "Brokoli",
    "seftali": "Şeftali",
    "kayisi": "Kayısı",
    "visne": "Vişne",
    "kiraz": "Kiraz",
    "uzum": "Üzüm",
    "armut": "Armut",
    "portakal": "Portakal",
    "nar": "Nar",
    "incir": "İncir",
    "karpuz": "Karpuz",
    "kavun": "Kavun",
    "antep fistigi": "Antep Fıstığı",
    "pudra sekeri": "Pudra Şekeri",
    "lavash": "Lavaş",
    "badem unu": "Badem Unu",
    "kakao": "Kakao",
    "vanilya": "Vanilya",
    "mayonez": "Mayonez",
    "file badem": "File Badem",
]

private func fixTurkishCharacters(_ input: String) -> String {
    let lowered = input.lowercased()
    if let fixed = turkishFixMap[lowered] {
        return fixed
    }
    // Capitalize first letter as fallback
    guard let first = input.first else { return input }
    return first.uppercased() + input.dropFirst()
}

private let fallbackIngredients = [
    "Yumurta", "Un", "Süt", "Tereyağı", "Şeker",
    "Tuz", "Pirinç", "Makarna", "Domates", "Soğan",
    "Sarımsak", "Biber", "Patates", "Tavuk", "Kıyma",
    "Peynir", "Yoğurt", "Zeytinyağı", "Limon", "Havuç",
    "Kabak", "Patlıcan", "Nohut", "Mercimek", "Bulgur",
    "Ekmek", "Bal", "Ceviz", "Fıstık", "Ispanak",
    "Muz", "Elma", "Somon", "Ton Balığı", "Krema"
]

private let bubbleColors: [Color] = [
    Color(hex: 0xF3F0EB), // warm grey
    Color(hex: 0xEDE7DC), // light beige
    Color(hex: 0xE8E4DE), // stone
    Color(hex: 0xF0ECE6), // cream
    Color(hex: 0xEAE6E1), // sand
    Color(hex: 0xE5E1DB), // pebble
]

struct Bubble: Identifiable {
    let id = UUID()
    let name: String
    var x: CGFloat
    var delay: Double
    var speed: Double
    var size: CGFloat
    var color: Color
}

struct BubbleGameView: View {
    @Binding var selected: Set<String>
    var onDone: () -> Void

    @State private var ingredientNames: [String] = []
    @State private var isLoading = true
    @State private var bubbles: [Bubble] = []
    @State private var popped: Set<String> = []
    @State private var popScales: [String: CGFloat] = [:]
    @State private var gameStarted = false
    @State private var yOffsets: [UUID: CGFloat] = [:]
    @State private var queue: [String] = []
    @State private var screenSize: CGSize = .zero

    private let maxOnScreen = 12

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 6) {
                    Text("Evinde ne var?")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.ink)

                    Text("Malzemelere dokunarak seç")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(DS.smoke)
                }
                .padding(.top, 16)
                .padding(.bottom, 4)

                // Selected count badge (always present, opacity toggles)
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                    Text("\(selected.count) malzeme seçildi")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(hex: 0x1A1A1A))
                )
                .opacity(selected.isEmpty ? 0 : 1)
                .padding(.top, 4)

                // Selected chips row (always present, opacity toggles)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(selected).sorted(), id: \.self) { name in
                            HStack(spacing: 4) {
                                Text(name)
                                    .font(.system(size: 12, weight: .medium))
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(Color(hex: 0x1A1A1A))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(hex: 0xF0ECE6))
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.2)) {
                                    selected.remove(name)
                                    popped.remove(name)
                                    queue.append(name)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 36)
                .padding(.top, 6)
                .opacity(selected.isEmpty ? 0 : 1)

                if isLoading {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(Color(hex: 0x1A1A1A))
                        Text("Malzemeler yükleniyor...")
                            .font(.bodyText())
                            .foregroundStyle(DS.smoke)
                    }
                    Spacer()
                } else {
                    GeometryReader { geo in
                        ZStack {
                            ForEach(bubbles) { bubble in
                                BubbleView(
                                    name: bubble.name,
                                    size: bubble.size,
                                    isSelected: selected.contains(bubble.name),
                                    color: bubble.color
                                )
                                .scaleEffect(popScales[bubble.name] ?? 1.0)
                                .position(
                                    x: bubble.x * geo.size.width,
                                    y: yOffsets[bubble.id] ?? -bubble.size
                                )
                                .onTapGesture {
                                    tapBubble(bubble)
                                }
                            }
                        }
                        .clipped()
                        .onAppear {
                            screenSize = geo.size
                            startGame()
                        }
                    }
                }

                // Bottom button
                Button(action: onDone) {
                    Text("Devam Et (\(selected.count))")
                        .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(selected.isEmpty ? Color(hex: 0xE0E0E0) : Color(hex: 0x1A1A1A))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(selected.isEmpty)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .animation(.spring(response: 0.3), value: selected.count)
        }
        .task {
            let fetched = await APIService.fetchIngredients()
            let all = fetched.isEmpty ? fallbackIngredients : fetched.map { fixTurkishCharacters($0.name) }
            ingredientNames = all.sorted()
            isLoading = false
        }
    }

    private func startGame() {
        guard !gameStarted, screenSize != .zero else { return }
        gameStarted = true

        queue = ingredientNames.shuffled()

        // Launch initial batch with staggered delays
        let initialCount = min(maxOnScreen, queue.count)
        for i in 0..<initialCount {
            let name = queue.removeFirst()
            let delay = Double(i) * 0.6
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                launchBubble(name: name)
            }
        }
    }

    private func launchBubble(name: String) {
        let bubble = Bubble(
            name: name,
            x: CGFloat.random(in: 0.12...0.88),
            delay: 0,
            speed: Double.random(in: 6...9),
            size: CGFloat.random(in: 55...80),
            color: bubbleColors.randomElement()!
        )
        bubbles.append(bubble)
        yOffsets[bubble.id] = -bubble.size

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.linear(duration: bubble.speed)) {
                yOffsets[bubble.id] = screenSize.height + bubble.size
            }
        }

        // When bubble exits screen, remove it and launch next
        DispatchQueue.main.asyncAfter(deadline: .now() + bubble.speed + 0.1) {
            removeBubble(bubble)
            recycleOrLaunchNext(name: name)
        }
    }

    private func removeBubble(_ bubble: Bubble) {
        yOffsets.removeValue(forKey: bubble.id)
        bubbles.removeAll { $0.id == bubble.id }
    }

    private func recycleOrLaunchNext(name: String) {
        // If this ingredient wasn't selected, put it back in the queue
        if !popped.contains(name) && !selected.contains(name) {
            queue.append(name)
        }

        // Only launch if under max
        guard bubbles.count < maxOnScreen, let next = queue.first else { return }
        queue.removeFirst()
        launchBubble(name: next)
    }

    private func tapBubble(_ bubble: Bubble) {
        if selected.contains(bubble.name) {
            selected.remove(bubble.name)
        } else {
            selected.insert(bubble.name)
            popped.insert(bubble.name)

            withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                popScales[bubble.name] = 1.3
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
                    popScales[bubble.name] = 0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                removeBubble(bubble)
                // Launch replacement if under max
                if bubbles.count < maxOnScreen, let next = queue.first {
                    queue.removeFirst()
                    launchBubble(name: next)
                }
            }
        }
    }
}

private struct BubbleView: View {
    let name: String
    let size: CGFloat
    let isSelected: Bool
    let color: Color

    var body: some View {
        Text(name)
            .font(.system(size: size * 0.15, weight: .medium))
            .foregroundStyle(isSelected ? .white : Color(hex: 0x1A1A1A))
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(isSelected ? Color(hex: 0x1A1A1A) : color)
            )
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}

// MARK: - Time Selection

struct TimeSelectionView: View {
    @Binding var selectedTime: CookingTime
    var onDone: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(DS.ember)

                Text("Ne kadar vaktin var?")
                    .font(.displayTitle())
                    .foregroundStyle(DS.ink)
            }

            VStack(spacing: 8) {
                ForEach(Array(CookingTime.allCases.enumerated()), id: \.element) { index, time in
                    Button {
                        selectedTime = time
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: time.icon)
                                .font(.system(size: 20, weight: .medium))
                                .frame(width: 32)

                            Text(time.rawValue)
                                .font(.sectionHeader())

                            Spacer()

                            if selectedTime == time {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                        .padding(16)
                        .foregroundStyle(selectedTime == time ? DS.cream : DS.ink)
                        .background(selectedTime == time ? DS.ember : DS.sand)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        .easeOut(duration: 0.2).delay(Double(index) * 0.05),
                        value: appeared
                    )
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            Button(action: onDone) {
                Text("Devam Et")
                    .font(.buttonFont())
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(DS.ember)
                    .foregroundStyle(DS.cream)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Cuisine Selection

struct CuisineSelectionView: View {
    @Binding var selectedCuisine: CuisineType
    var onDone: () -> Void

    @State private var appeared = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(DS.ember)

                Text("Ne tarzı bir şey?")
                    .font(.displayTitle())
                    .foregroundStyle(DS.ink)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(CuisineType.allCases.enumerated()), id: \.element) { index, cuisine in
                    Button {
                        selectedCuisine = cuisine
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: cuisine.icon)
                                .font(.system(size: 22, weight: .medium))

                            Text(cuisine.rawValue)
                                .font(.label())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .foregroundStyle(selectedCuisine == cuisine ? DS.cream : DS.ink)
                        .background(selectedCuisine == cuisine ? DS.ember : DS.sand)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .scaleEffect(appeared ? 1 : 0.97)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        .easeOut(duration: 0.2).delay(Double(index) * 0.03),
                        value: appeared
                    )
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            Button(action: onDone) {
                Text("Tarifleri Göster")
                    .font(.buttonFont())
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(DS.ember)
                    .foregroundStyle(DS.cream)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Swipe Results

struct SwipeResultsView: View {
    let ingredients: Set<String>
    let time: CookingTime
    let cuisine: CuisineType
    let category: MealCategory

    @State private var recipes: [SuggestedRecipe] = []
    @State private var currentIndex = 0
    @State private var dragOffset: CGSize = .zero
    @State private var savedRecipes: [SuggestedRecipe] = []
    @State private var isLoading = true
    @State private var showSaved = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Senin için tarifler")
                        .font(.displayTitle())
                        .foregroundStyle(DS.ink)
                    Text("\(savedRecipes.count) tarif kaydedildi")
                        .font(.captionText())
                        .foregroundStyle(DS.smoke)
                }

                Spacer()

                if !savedRecipes.isEmpty {
                    Button {
                        showSaved = true
                    } label: {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(DS.ember)
                            .font(.system(size: 20, weight: .medium))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)

            if isLoading {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.3)
                    Text("Tarifler hazırlanıyor...")
                        .font(.bodyText())
                        .foregroundStyle(DS.smoke)
                }
                Spacer()
            } else if currentIndex >= recipes.count {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(DS.pine)

                    Text("Hepsi bu kadar!")
                        .font(.displayTitle())
                        .foregroundStyle(DS.ink)

                    Text("\(savedRecipes.count) tarif kaydettin")
                        .font(.bodyText())
                        .foregroundStyle(DS.smoke)
                }
                Spacer()
            } else {
                ZStack {
                    ForEach(Array(recipes.enumerated().reversed()), id: \.element.id) { index, recipe in
                        if index >= currentIndex && index < currentIndex + 3 {
                            RecipeSuggestionCard(recipe: recipe)
                                .scaleEffect(index == currentIndex ? 1 : 1 - CGFloat(index - currentIndex) * 0.05)
                                .offset(y: index == currentIndex ? 0 : CGFloat(index - currentIndex) * 8)
                                .offset(x: index == currentIndex ? dragOffset.width : 0)
                                .rotationEffect(
                                    index == currentIndex
                                    ? .degrees(Double(dragOffset.width) / 20)
                                    : .zero
                                )
                                .overlay(alignment: .top) {
                                    if index == currentIndex {
                                        swipeIndicator
                                    }
                                }
                                .gesture(
                                    index == currentIndex
                                    ? DragGesture()
                                        .onChanged { value in
                                            dragOffset = value.translation
                                        }
                                        .onEnded { value in
                                            handleSwipe(value.translation)
                                        }
                                    : nil
                                )
                                .animation(.spring(response: 0.2), value: dragOffset)
                        }
                    }
                }
                .padding(.horizontal, 20)

                HStack(spacing: 40) {
                    VStack(spacing: 4) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(DS.dust)
                        Text("Geç")
                            .font(.captionText())
                            .foregroundStyle(DS.smoke)
                    }

                    VStack(spacing: 4) {
                        Image(systemName: "heart.circle")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(DS.ember.opacity(0.5))
                        Text("Kaydet")
                            .font(.captionText())
                            .foregroundStyle(DS.smoke)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showSaved) {
            SavedRecipesSheet(recipes: savedRecipes)
        }
        .task {
            await loadRecipes()
        }
    }

    @ViewBuilder
    private var swipeIndicator: some View {
        EmptyView()
    }

    private func handleSwipe(_ translation: CGSize) {
        if translation.width > 120 {
            withAnimation(.spring(response: 0.2)) {
                dragOffset = CGSize(width: 500, height: 0)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                savedRecipes.append(recipes[currentIndex])
                currentIndex += 1
                dragOffset = .zero
            }
        } else if translation.width < -120 {
            withAnimation(.spring(response: 0.2)) {
                dragOffset = CGSize(width: -500, height: 0)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                currentIndex += 1
                dragOffset = .zero
            }
        } else {
            withAnimation(.spring(response: 0.2)) {
                dragOffset = .zero
            }
        }
    }

    private func loadRecipes() async {
        guard let userId = Clerk.shared.user?.id else { return }
        let all = await APIService.fetchUserRecipes(userId: userId)

        let userIngredients = Set(ingredients.map { $0.lowercased() })

        // Map category to matching tags
        let categoryTagMap: [MealCategory: String] = [
            .anaYemek: "ana yemek",
            .atistirmalik: "atıştırmalık",
            .tatli: "tatlı",
            .corba: "çorba",
            .salata: "salata",
            .kahvalti: "kahvaltı",
            .meze: "meze",
            .icecek: "içecek",
        ]

        let scored: [(dto: RecipeDTO, score: Int)] = all.compactMap { dto in
            // Filter by ingredients — must have at least one match
            let recipeIngs = Set(dto.ingredients_without_measures.map { $0.lowercased() })
            let matchCount = recipeIngs.intersection(userIngredients).count
            guard matchCount > 0 else { return nil }

            // Filter by cuisine
            if cuisine != .any {
                let cuisineValue = cuisine.rawValue.lowercased()
                let recipeCuisine = (dto.cuisine ?? "").lowercased()
                // Map display names to API values
                let cuisineMap: [String: [String]] = [
                    "i\u{0307}talyan": ["italian"],
                    "çin": ["chinese"],
                    "meksika": ["mexican"],
                    "hint": ["indian"],
                    "tayland": ["thai"],
                    "fransız": ["french"],
                    "japon": ["japanese"],
                    "akdeniz": ["mediterranean"],
                ]
                let acceptedValues = cuisineMap[cuisineValue] ?? [cuisineValue]
                guard acceptedValues.contains(recipeCuisine) else { return nil }
            }

            // Filter by category (match against tags)
            if category != .any, let requiredTag = categoryTagMap[category] {
                let recipeTags = (dto.tags ?? []).map { $0.lowercased() }
                guard recipeTags.contains(requiredTag) else { return nil }
            }

            return (dto, matchCount)
        }

        let top = scored.sorted { $0.score > $1.score }.prefix(10)

        let cardColors: [Color] = [
            Color(hex: 0xD94B2B), Color(hex: 0xD4952B), Color(hex: 0x2B7A53),
            Color(hex: 0x8B5E3C), Color(hex: 0x6B4C3B), Color(hex: 0xA83820),
            Color(hex: 0x4A7C59), Color(hex: 0xC17838), Color(hex: 0x3D6B5E),
            Color(hex: 0xB8632E),
        ]

        recipes = await withTaskGroup(of: (Int, SuggestedRecipe).self) { group in
            for (index, item) in top.enumerated() {
                group.addTask {
                    let fullThumbURL = item.dto.thumbnail_url.map { $0.hasPrefix("http") ? $0 : "\(APIService.baseURL)\($0)" }
                    let thumbData = await CaptionService.downloadImage(from: fullThumbURL)
                    let recipe = SuggestedRecipe(
                        title: item.dto.title,
                        duration: item.dto.cooking_time ?? "",
                        difficulty: item.dto.difficulty ?? "",
                        ingredients: item.dto.ingredients_without_measures,
                        description: String(item.dto.description.prefix(120)),
                        color: cardColors[index % cardColors.count],
                        thumbnailData: thumbData,
                        sourceURL: item.dto.url
                    )
                    return (index, recipe)
                }
            }
            var results = [(Int, SuggestedRecipe)]()
            for await result in group {
                results.append(result)
            }
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }

        if recipes.isEmpty {
            recipes = SuggestedRecipe.placeholders
        }

        isLoading = false
    }
}

// MARK: - Suggestion Card

struct SuggestedRecipe: Identifiable {
    let id = UUID()
    let title: String
    let duration: String
    let difficulty: String
    let ingredients: [String]
    let description: String
    let color: Color
    var thumbnailData: Data?
    var sourceURL: String?

    static let placeholders: [SuggestedRecipe] = [
        SuggestedRecipe(title: "Menemen", duration: "15 dk", difficulty: "Kolay", ingredients: ["Yumurta", "Domates", "Biber"], description: "Klasik Türk kahvaltısı. Domatesli, biberli, yumurtalı bir lezzet.", color: Color(hex: 0xD94B2B)),
        SuggestedRecipe(title: "Mercimek Çorbası", duration: "30 dk", difficulty: "Kolay", ingredients: ["Mercimek", "Soğan", "Havuç"], description: "Her evin vazgeçilmez çorbası. Sıcak ve doyurucu.", color: Color(hex: 0xD4952B)),
        SuggestedRecipe(title: "Makarna", duration: "20 dk", difficulty: "Kolay", ingredients: ["Makarna", "Domates", "Sarımsak"], description: "Hızlı ve lezzetli. Domates soslu makarna.", color: Color(hex: 0x8B5E3C)),
        SuggestedRecipe(title: "Tavuk Sote", duration: "40 dk", difficulty: "Orta", ingredients: ["Tavuk", "Biber", "Patates"], description: "Sebzeli tavuk sote. Pirinç pilavı ile muhteşem.", color: Color(hex: 0x2B7A53)),
        SuggestedRecipe(title: "Karnıyarık", duration: "1 saat", difficulty: "Orta", ingredients: ["Patlıcan", "Kıyma", "Domates"], description: "Fırında kıyma dolgulu patlıcan. Ev yemeği klasiği.", color: Color(hex: 0x6B4C3B)),
        SuggestedRecipe(title: "Patates Püresi", duration: "25 dk", difficulty: "Kolay", ingredients: ["Patates", "Süt", "Tereyağı"], description: "Kremalı ve yumuşacık püre. Her yemekle uyumlu.", color: Color(hex: 0xC17838)),
        SuggestedRecipe(title: "Yumurta Tost", duration: "10 dk", difficulty: "Kolay", ingredients: ["Yumurta", "Ekmek", "Peynir"], description: "Hızlı atıştırmalık. Peynirli yumurtalı tost.", color: Color(hex: 0x4A7C59)),
        SuggestedRecipe(title: "Bulgur Pilavı", duration: "25 dk", difficulty: "Kolay", ingredients: ["Bulgur", "Domates", "Soğan"], description: "Domatesli bulgur pilavı. Yoğurtla servis edin.", color: Color(hex: 0xA83820)),
        SuggestedRecipe(title: "Ispanaklı Börek", duration: "45 dk", difficulty: "Orta", ingredients: ["Ispanak", "Peynir", "Un"], description: "El açması börek. Ispanak ve peynir dolgusu.", color: Color(hex: 0x3D6B5E)),
        SuggestedRecipe(title: "Bal Ceviz Tatlısı", duration: "5 dk", difficulty: "Kolay", ingredients: ["Bal", "Ceviz", "Yoğurt"], description: "Sağlıklı tatlı. Yoğurt üstüne bal ve ceviz.", color: Color(hex: 0xB8632E)),
    ]
}

private struct RecipeSuggestionCard: View {
    let recipe: SuggestedRecipe

    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail
            ZStack {
                if let data = recipe.thumbnailData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 280)
                        .clipped()
                } else {
                    recipe.color
                        .frame(height: 280)
                }

                // Play button if there's a source URL
                if recipe.sourceURL != nil {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.85))
                        .shadow(radius: 4)
                }
            }
            .onTapGesture {
                if let urlStr = recipe.sourceURL, let url = URL(string: urlStr) {
                    UIApplication.shared.open(url)
                }
            }

            // Info section
            VStack(alignment: .leading, spacing: 8) {
                Text(recipe.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.ink)

                if !recipe.description.isEmpty {
                    Text(recipe.description)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(DS.smoke)
                        .lineLimit(2)
                }

                HStack(spacing: 16) {
                    if !recipe.duration.isEmpty {
                        Label(recipe.duration, systemImage: "clock")
                    }
                    if !recipe.difficulty.isEmpty {
                        Label(recipe.difficulty, systemImage: "chart.bar")
                    }
                    Label("\(recipe.ingredients.count) malzeme", systemImage: "leaf")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DS.smoke)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.cream)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}

// MARK: - Saved Recipes Sheet

private struct SavedRecipesSheet: View {
    let recipes: [SuggestedRecipe]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(recipes) { recipe in
                HStack(spacing: 12) {
                    Circle()
                        .fill(recipe.color)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "fork.knife")
                                .font(.captionText())
                                .foregroundStyle(Color(hex: 0xFAF7F4))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(recipe.title)
                            .font(.label())
                            .foregroundStyle(DS.ink)
                        if !recipe.duration.isEmpty {
                            Text(recipe.duration)
                                .font(.captionText())
                                .foregroundStyle(DS.smoke)
                        }
                    }
                }
            }
            .navigationTitle("Kaydedilenler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                        .foregroundStyle(DS.ember)
                }
            }
        }
    }
}
