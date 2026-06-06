import SwiftUI
import ClerkKit

struct ShoppingListView: View {
    var onBack: (() -> Void)?

    @State private var items: [ShoppingItemDTO] = []
    @State private var isLoading = true
    @State private var showAddSheet = false

    private var uncheckedItems: [ShoppingItemDTO] {
        items.filter { !$0.is_checked }
    }

    private var checkedItems: [ShoppingItemDTO] {
        items.filter { $0.is_checked }
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

                    Text("Alışveriş Listesi")
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                        .foregroundStyle(DS.ink)

                    Spacer()

                    Button {
                        showAddSheet = true
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
                        Image(systemName: "cart")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(DS.dust)

                        Text("Listeniz bos")
                            .font(.displayTitle())
                            .foregroundStyle(DS.ink)

                        Text("Alisveris listesine malzeme ekleyin")
                            .font(.bodyText())
                            .foregroundStyle(DS.smoke)
                            .multilineTextAlignment(.center)

                        Button {
                            showAddSheet = true
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
                    ScrollView {
                        VStack(spacing: 16) {
                            // Unchecked items
                            if !uncheckedItems.isEmpty {
                                VStack(spacing: 8) {
                                    HStack {
                                        Text("Alinacaklar")
                                            .font(.label())
                                            .foregroundStyle(DS.smoke)
                                        Spacer()
                                        Text("\(uncheckedItems.count)")
                                            .font(.label())
                                            .foregroundStyle(DS.smoke)
                                    }

                                    ForEach(uncheckedItems) { item in
                                        ShoppingItemRow(
                                            item: item,
                                            onToggle: { Task { await toggleItem(item) } },
                                            onDelete: { Task { await deleteItem(item) } }
                                        )
                                    }
                                }
                            }

                            // Checked items
                            if !checkedItems.isEmpty {
                                VStack(spacing: 8) {
                                    HStack {
                                        Text("Alinanlar")
                                            .font(.label())
                                            .foregroundStyle(DS.smoke)
                                        Spacer()
                                        Text("\(checkedItems.count)")
                                            .font(.label())
                                            .foregroundStyle(DS.smoke)
                                    }

                                    ForEach(checkedItems) { item in
                                        ShoppingItemRow(
                                            item: item,
                                            onToggle: { Task { await toggleItem(item) } },
                                            onDelete: { Task { await deleteItem(item) } }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showAddSheet) {
            ShoppingAddSheet { names in
                Task { await addItems(names: names) }
            }
        }
        .task {
            await loadList()
        }
    }

    private func loadList() async {
        guard let userId = Clerk.shared.user?.id else { return }
        items = await APIService.fetchShoppingList(userId: userId)
        isLoading = false
    }

    private func addItems(names: [String]) async {
        guard let userId = Clerk.shared.user?.id else { return }
        let _ = await APIService.addToShoppingList(userId: userId, ingredientNames: names)
        await loadList()
    }

    private func toggleItem(_ item: ShoppingItemDTO) async {
        guard let userId = Clerk.shared.user?.id else { return }
        let newChecked = !item.is_checked
        let _ = await APIService.toggleShoppingItem(userId: userId, itemId: item.id, isChecked: newChecked)
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            withAnimation(.spring(response: 0.2)) {
                items[index] = ShoppingItemDTO(
                    id: item.id,
                    ingredient_id: item.ingredient_id,
                    ingredient_name: item.ingredient_name,
                    price_tier: item.price_tier,
                    availability: item.availability,
                    is_checked: newChecked,
                    added_at: item.added_at
                )
            }
        }
    }

    private func deleteItem(_ item: ShoppingItemDTO) async {
        guard let userId = Clerk.shared.user?.id else { return }
        let _ = await APIService.removeFromShoppingList(userId: userId, itemId: item.id)
        withAnimation(.spring(response: 0.2)) {
            items.removeAll { $0.id == item.id }
        }
    }
}

// MARK: - Shopping Item Row

private struct ShoppingItemRow: View {
    let item: ShoppingItemDTO
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.is_checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(item.is_checked ? DS.ember : DS.dust)
            }

            Text(item.ingredient_name)
                .font(.sectionHeader())
                .foregroundStyle(item.is_checked ? DS.smoke : DS.ink)
                .strikethrough(item.is_checked, color: DS.smoke)

            Spacer()

            if let tier = item.price_tier {
                Text(priceTierEmoji(tier))
                    .font(.captionText())
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

// MARK: - Add Sheet (uses BubbleGameView)

struct ShoppingAddSheet: View {
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
