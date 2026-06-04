import SwiftUI
import ClerkKit

struct PantryView: View {
    var onBack: (() -> Void)?

    @State private var items: [PantryItemDTO] = []
    @State private var isLoading = true
    @State private var showBubbleGame = false
    @State private var searchText = ""

    private var filteredItems: [PantryItemDTO] {
        if searchText.isEmpty { return items }
        return items.filter { $0.ingredient_name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            DS.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    if let onBack {
                        BackButton(action: onBack)
                    }

                    Spacer()

                    Text("Kilerim")
                        .font(.displayTitle())
                        .foregroundStyle(DS.ink)

                    Spacer()

                    Button {
                        showBubbleGame = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DS.cream)
                            .frame(width: 36, height: 36)
                            .background(DS.ember)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(DS.ember)
                    Spacer()
                } else if items.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "refrigerator")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(DS.dust)

                        Text("Kilerin bos")
                            .font(.displayTitle())
                            .foregroundStyle(DS.ink)

                        Text("Malzeme eklemek icin + butonuna dokun")
                            .font(.bodyText())
                            .foregroundStyle(DS.smoke)
                            .multilineTextAlignment(.center)

                        Button {
                            showBubbleGame = true
                        } label: {
                            Text("Malzeme Ekle")
                                .font(.buttonFont())
                                .foregroundStyle(DS.cream)
                                .frame(width: 180, height: 48)
                                .background(DS.ember)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 40)
                    Spacer()
                } else {
                    // Search bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(DS.smoke)
                            .font(.system(size: 14))

                        TextField("Malzeme ara...", text: $searchText)
                            .font(.bodyText())
                    }
                    .padding(12)
                    .background(DS.sand)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                    // Count
                    HStack {
                        Text("\(items.count) malzeme")
                            .font(.label())
                            .foregroundStyle(DS.smoke)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)

                    // List
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredItems) { item in
                                PantryItemRow(
                                    item: item,
                                    onDelete: { Task { await removeItem(item) } },
                                    onMoveToShoppingList: { Task { await moveToShoppingList(item) } }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showBubbleGame) {
            PantryBubbleSheet(
                existingNames: Set(items.map { $0.ingredient_name }),
                onSave: { names in
                    Task { await addItems(names: names) }
                }
            )
        }
        .task {
            await loadPantry()
        }
    }

    private func loadPantry() async {
        guard let userId = Clerk.shared.user?.id else { return }
        items = await APIService.fetchPantry(userId: userId)
        isLoading = false
    }

    private func addItems(names: [String]) async {
        guard let userId = Clerk.shared.user?.id else { return }
        let _ = await APIService.addToPantry(userId: userId, ingredientNames: names)
        await loadPantry()
    }

    private func moveToShoppingList(_ item: PantryItemDTO) async {
        guard let userId = Clerk.shared.user?.id else { return }
        let _ = await APIService.addToShoppingList(userId: userId, ingredientNames: [item.ingredient_name])
        let _ = await APIService.removeFromPantry(userId: userId, ingredientId: item.ingredient_id)
        withAnimation(.spring(response: 0.2)) {
            items.removeAll { $0.id == item.id }
        }
    }

    private func removeItem(_ item: PantryItemDTO) async {
        guard let userId = Clerk.shared.user?.id else { return }
        let _ = await APIService.removeFromPantry(userId: userId, ingredientId: item.ingredient_id)
        withAnimation(.spring(response: 0.2)) {
            items.removeAll { $0.id == item.id }
        }
    }
}

// MARK: - Pantry Item Row

private struct PantryItemRow: View {
    let item: PantryItemDTO
    let onDelete: () -> Void
    let onMoveToShoppingList: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 14))
                .foregroundStyle(DS.ember)
                .frame(width: 36, height: 36)
                .background(DS.emberLight)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(item.ingredient_name)
                .font(.sectionHeader())
                .foregroundStyle(DS.ink)

            Spacer()

            if let tier = item.price_tier {
                Text(priceTierEmoji(tier))
                    .font(.captionText())
            }

            Button(action: onMoveToShoppingList) {
                Image(systemName: "cart.badge.plus")
                    .font(.system(size: 15))
                    .foregroundStyle(DS.ember)
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(DS.smoke)
            }
        }
        .padding(12)
        .background(DS.sand)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func priceTierEmoji(_ tier: String) -> String {
        switch tier {
        case "cheap": return "₺"
        case "neutral": return "₺₺"
        case "expensive": return "₺₺₺"
        default: return ""
        }
    }
}

// MARK: - Pantry Gate (minimum items required)

struct PantryGateView: View {
    let currentCount: Int
    let minCount: Int
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showBubbleGame = false
    @State private var pantryCount: Int = 0

    var body: some View {
        ZStack {
            DS.cream.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "refrigerator")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(DS.ember)

                VStack(spacing: 8) {
                    Text("Önce kilerini doldur!")
                        .font(.displayTitle())
                        .foregroundStyle(DS.ink)

                    Text("Bu özelliği kullanmak için en az \(minCount) malzeme eklemelisin. Şu an \(pantryCount) malzemen var.")
                        .font(.bodyText())
                        .foregroundStyle(DS.smoke)
                        .multilineTextAlignment(.center)
                }

                Button {
                    showBubbleGame = true
                } label: {
                    Text("Malzeme Ekle")
                        .font(.buttonFont())
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(DS.ember)
                        .foregroundStyle(DS.cream)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 20)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("Geri Dön")
                        .font(.buttonFont())
                        .foregroundStyle(DS.smoke)
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 20)
        }
        .onAppear { pantryCount = currentCount }
        .fullScreenCover(isPresented: $showBubbleGame) {
            PantryBubbleSheet(
                existingNames: [],
                onSave: { names in
                    guard let userId = Clerk.shared.user?.id else { return }
                    Task {
                        let _ = await APIService.addToPantry(userId: userId, ingredientNames: names)
                        let items = await APIService.fetchPantry(userId: userId)
                        pantryCount = items.count
                        if pantryCount >= minCount {
                            onDone()
                        }
                    }
                }
            )
        }
    }
}

// MARK: - Bubble Game Sheet for Pantry

struct PantryBubbleSheet: View {
    let existingNames: Set<String>
    let onSave: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []

    var body: some View {
        ZStack {
            DS.cream.ignoresSafeArea()

            BubbleGameView(selected: $selected, onDone: {
                let names = Array(selected)
                onSave(names)
                dismiss()
            })
            .overlay(alignment: .topLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.ink)
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.85))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                }
                .padding(.leading, 20)
                .padding(.top, 12)
            }
        }
    }
}
