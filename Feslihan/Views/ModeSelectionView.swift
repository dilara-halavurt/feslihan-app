import SwiftUI
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
    @State private var showPantryGate = false
    @State private var pendingMode: AppMode?
    @EnvironmentObject var subscription: SubscriptionService

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

                VStack(spacing: 24) {
                    HStack {
                        Spacer()
                        Button { showAccountSheet = true } label: {
                            if let url = Clerk.shared.user?.imageUrl,
                               let imageURL = URL(string: url) {
                                AsyncImage(url: imageURL) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(DS.smoke)
                                }
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(DS.smoke)
                                    .frame(width: 36, height: 36)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    VStack(spacing: 8) {

                        Text("Bir mod seç ve başla")
                            .font(.bodyText())
                            .foregroundStyle(DS.smoke)
                    }

                    VStack(spacing: 12) {
                        ModeCard(
                            icon: "calendar",
                            title: "Meal Prep",
                            subtitle: "Haftalık yemek planı oluştur"
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
                            icon: "sparkles",
                            title: "Ne Yesem?",
                            subtitle: "Malzemelerine göre tarif bul"
                        )
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : 20)
                        .onTapGesture {
                            navigateOrGate(.whatToEat)
                        }

                        ModeCard(
                            icon: "book",
                            title: "Tariflerim",
                            subtitle: "Kaydettiğin tariflere göz at"
                        )
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : 20)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.2)) {
                                selectedMode = .browse
                            }
                        }

                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
            .overlay(alignment: .bottom) {
                Button(action: { showAddRecipe = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(DS.cream)
                        .frame(width: 56, height: 56)
                        .background(DS.ember)
                        .clipShape(Circle())
                        .shadow(color: DS.ember.opacity(0.3), radius: 8, y: 4)
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

    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(DS.ember)
                .frame(width: 48, height: 48)
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
        .padding(16)
        .background(DS.sand)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeOut(duration: 0.15)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}
