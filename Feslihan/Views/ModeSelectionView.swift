import SwiftUI
import SwiftData
import ClerkKit
import ClerkKitUI

enum AppMode: String, CaseIterable {
    case mealPrep
    case whatToEat
    case browse
    case pantry
    case shoppingList
}

struct ModeSelectionView: View {
    @State private var selectedMode: AppMode?
    @State private var cardsVisible = false
    @State private var showAddRecipe = false
    @State private var showPaywall = false
    @State private var showMealPrepWizard = false
    @State private var showAccountSheet = false
    @State private var pantryCount = 0
    @State private var shoppingCount = 0
    @State private var recipeCount = 0
    @State private var showPantryGate = false
    @State private var pendingMode: AppMode?
    @EnvironmentObject var subscription: SubscriptionService
    @Environment(\.modelContext) private var modelContext

    private let minPantryCount = 30

    private func goBack() {
        withAnimation(.spring(response: 0.2)) {
            selectedMode = nil
        }
        Task { await refreshPantryCount() }
    }

    private func refreshPantryCount() async {
        guard let userId = Clerk.shared.user?.id else { return }
        let items = await APIService.fetchPantry(userId: userId)
        pantryCount = items.count
        let shoppingItems = await APIService.fetchShoppingList(userId: userId)
        shoppingCount = shoppingItems.filter { !$0.is_checked }.count
    }

    private func navigateOrGate(_ mode: AppMode) {
        if pantryCount < minPantryCount {
            pendingMode = mode
            showPantryGate = true
        } else {
            withAnimation(.spring(response: 0.2)) {
                selectedMode = mode
            }
        }
    }

    var body: some View {
        if let mode = selectedMode {
            Group {
                switch mode {
                case .browse:
                    ContentView(onBack: goBack)
                case .mealPrep:
                    SavedMealPlansView(
                        onBack: goBack,
                        onCreateNew: {
                            withAnimation(.spring(response: 0.2)) {
                                selectedMode = nil
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(.spring(response: 0.2)) {
                                    showMealPrepWizard = true
                                }
                            }
                        }
                    )
                case .whatToEat:
                    WhatToEatView(onBack: goBack)
                case .pantry:
                    PantryView(onBack: goBack)
                case .shoppingList:
                    ShoppingListView(onBack: goBack)
                }
            }
            .transition(.move(edge: .trailing).combined(with: .opacity))
        } else {
            ZStack {
                DS.cream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Greeting + avatar
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("İyi akşamlar,")
                                    .font(.handwritten())
                                    .foregroundStyle(DS.dust)

                                Text(Clerk.shared.user?.firstName.map { "Merhaba, \($0)" } ?? "Merhaba")
                                    .font(.displayLarge())
                                    .foregroundStyle(DS.ink)
                            }

                            Spacer()

                            Button { showAccountSheet = true } label: {
                                if let url = Clerk.shared.user?.imageUrl,
                                   let imageURL = URL(string: url) {
                                    AsyncImage(url: imageURL) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        avatarPlaceholder
                                    }
                                    .frame(width: 46, height: 46)
                                    .clipShape(Circle())
                                } else {
                                    avatarPlaceholder
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 18)

                        // Empty state prompt
                        if recipeCount == 0 {
                            Button(action: { showAddRecipe = true }) {
                                HStack(spacing: 14) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28, weight: .medium))
                                        .foregroundStyle(DS.flour)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("İlk tarifini ekle")
                                            .font(.cardTitle())
                                            .foregroundStyle(DS.flour)

                                        Text("Sosyal medyadan veya web'den tarif kaydet")
                                            .font(.captionText())
                                            .foregroundStyle(DS.flour.opacity(0.8))
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(DS.flour.opacity(0.6))
                                }
                                .padding(16)
                                .background(
                                    LinearGradient(colors: [DS.ember, DS.emberDark], startPoint: .leading, endPoint: .trailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: DS.shadowButton, radius: 8, y: 4)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                        }

                        // Mode cards (3 primary modes)
                        VStack(spacing: 12) {
                            ModeCard(
                                icon: "calendar",
                                title: "Haftalık Plan",
                                subtitle: "Bir haftalık yemek planı hazırla",
                                premium: true
                            )
                            .opacity(cardsVisible ? 1 : 0)
                            .offset(y: cardsVisible ? 0 : 20)
                            .onTapGesture {
                                if subscription.currentPlan.canMealPrep {
                                    navigateOrGate(.mealPrep)
                                } else {
                                    showPaywall = true
                                }
                            }

                            ModeCard(
                                icon: "wand.and.stars",
                                title: "Ne Yesem?",
                                subtitle: "Sana özel tarif önerileri keşfet"
                            )
                            .opacity(cardsVisible ? 1 : 0)
                            .offset(y: cardsVisible ? 0 : 20)
                            .onTapGesture {
                                navigateOrGate(.whatToEat)
                            }

                            ModeCard(
                                icon: "book.closed.fill",
                                title: "Tariflerim",
                                subtitle: "Kaydettiğin tüm tarifler"
                            )
                            .opacity(cardsVisible ? 1 : 0)
                            .offset(y: cardsVisible ? 0 : 20)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.2)) {
                                    selectedMode = .browse
                                }
                            }

                            // Mutfak section
                            Text("MUTFAK")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .tracking(1.4)
                                .foregroundStyle(DS.dust)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 14)
                                .padding(.leading, 2)

                            HStack(spacing: 12) {
                                UtilCard(
                                    icon: "cabinet.fill",
                                    title: "Kilerim",
                                    count: "\(pantryCount)",
                                    unit: "malzeme",
                                    tint: DS.ember
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.2)) {
                                        selectedMode = .pantry
                                    }
                                }

                                UtilCard(
                                    icon: "basket.fill",
                                    title: "Alışveriş",
                                    count: "\(shoppingCount)",
                                    unit: "eksik ürün",
                                    tint: DS.terracotta
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.2)) {
                                        selectedMode = .shoppingList
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 80)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                Button(action: { showAddRecipe = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(DS.flour)
                        .frame(width: 56, height: 56)
                        .background(DS.ember)
                        .clipShape(Circle())
                        .shadow(color: DS.shadowButton, radius: 8, y: 4)
                }
                .padding(.bottom, 24)
            }
            .sheet(isPresented: $showAddRecipe) {
                AddRecipeView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .fullScreenCover(isPresented: $showMealPrepWizard) {
                MealPrepView(onBack: { showMealPrepWizard = false })
            }
            .sheet(isPresented: $showAccountSheet) {
                AccountSheet(onNavigate: { mode in
                    showAccountSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.spring(response: 0.2)) {
                            selectedMode = mode
                        }
                    }
                })
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.2).delay(0.05)) {
                    cardsVisible = true
                }
            }
            .task {
                await refreshPantryCount()
                // Check local first, then backend
                let descriptor = FetchDescriptor<Recipe>()
                recipeCount = (try? modelContext.fetchCount(descriptor)) ?? 0
                if recipeCount == 0, let userId = Clerk.shared.user?.id {
                    let remote = await APIService.fetchUserRecipes(userId: userId)
                    recipeCount = remote.count
                }
            }
            .fullScreenCover(isPresented: $showPantryGate) {
                PantryGateView(
                    currentCount: pantryCount,
                    minCount: minPantryCount,
                    onDone: {
                        showPantryGate = false
                        Task {
                            await refreshPantryCount()
                            if let mode = pendingMode, pantryCount >= minPantryCount {
                                withAnimation(.spring(response: 0.2)) {
                                    selectedMode = mode
                                }
                            }
                            pendingMode = nil
                        }
                    }
                )
            }
        }
    }

    private var avatarPlaceholder: some View {
        Text(String(Clerk.shared.user?.firstName?.prefix(1) ?? "N"))
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(DS.flour)
            .frame(width: 46, height: 46)
            .background(
                LinearGradient(colors: [DS.terracotta, DS.honey], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Circle())
    }
}

// MARK: - Util Card (compact Mutfak cards)

private struct UtilCard: View {
    let icon: String
    let title: String
    let count: String
    let unit: String
    let tint: Color

    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(DS.sand)
                    .clipShape(RoundedRectangle(cornerRadius: 11))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.dust)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.ink)

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(count)
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .foregroundStyle(tint)
                    Text(unit)
                        .font(.captionText())
                        .foregroundStyle(DS.dust)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.flour)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: DS.shadowCard, radius: 4, y: 2)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeOut(duration: 0.15)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Account Sheet

private struct AccountSheet: View {
    let onNavigate: (AppMode) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Profile header
                VStack(spacing: 12) {
                    if let url = Clerk.shared.user?.imageUrl,
                       let imageURL = URL(string: url) {
                        AsyncImage(url: imageURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(DS.dust)
                        }
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(DS.dust)
                    }

                    if let name = Clerk.shared.user?.firstName {
                        Text(name)
                            .font(.displayTitle())
                            .foregroundStyle(DS.ink)
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 20)

                // Menu items
                VStack(spacing: 2) {
                    AccountRow(icon: "refrigerator", title: "Kilerim", subtitle: "Evindeki malzemeleri yönet") {
                        onNavigate(.pantry)
                    }

                    AccountRow(icon: "cart", title: "Alışveriş Listesi", subtitle: "Alması gerekenleri listele") {
                        onNavigate(.shoppingList)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                // Clerk account management (manage account, security, sign out)
                UserButton()
                    .padding(.bottom, 32)
            }
            .background(DS.cream)
            .navigationTitle("Hesabım")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DS.ink)
                    }
                }
            }
        }
    }
}

private struct AccountRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(DS.ember)
                    .frame(width: 44, height: 44)
                    .background(DS.emberLight)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.sectionHeader())
                        .foregroundStyle(DS.ink)

                    Text(subtitle)
                        .font(.label())
                        .foregroundStyle(DS.smoke)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DS.dust)
            }
            .padding(14)
            .background(DS.sand)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mode Card

private struct ModeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var premium: Bool = false

    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(DS.ember)
                .frame(width: 50, height: 50)
                .background(DS.cream)
                .clipShape(RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.ink)

                    if premium {
                        HStack(spacing: 3) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10))
                            Text("PLUS")
                                .font(.system(size: 10, weight: .heavy))
                                .tracking(0.4)
                        }
                        .foregroundStyle(DS.terracotta)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(DS.terracotta.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                Text(subtitle)
                    .font(.system(size: 13.5, weight: .regular))
                    .foregroundStyle(DS.smoke)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.dust)
        }
        .padding(16)
        .background(DS.sand)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DS.stone, lineWidth: 1)
        )
        .shadow(color: DS.shadowCard, radius: 4, y: 2)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeOut(duration: 0.15)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}
