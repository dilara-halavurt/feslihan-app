import SwiftUI
import ClerkKit

struct ShoppingListView: View {
    var onBack: () -> Void

    @State private var items: [ShoppingListItemDTO] = []
    @State private var isLoading = true
    @State private var newItemName = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                DS.cream.ignoresSafeArea()

                VStack(spacing: 0) {
                    if isLoading {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if items.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "cart")
                                .font(.system(size: 44, weight: .medium))
                                .foregroundStyle(DS.dust)
                            Text("Alışveriş listen boş")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(DS.ink)
                            Text("Aşağıdan malzeme ekle")
                                .font(.system(size: 14))
                                .foregroundStyle(DS.smoke)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                    ShoppingListRow(
                                        item: item,
                                        onToggle: { Task { await toggle(item) } },
                                        onDelete: { Task { await delete(item) } }
                                    )
                                    if index < items.count - 1 {
                                        Divider().padding(.leading, 48)
                                    }
                                }
                            }
                            .background(DS.sand)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        }
                    }

                    HStack(spacing: 12) {
                        TextField("Malzeme ekle", text: $newItemName)
                            .focused($inputFocused)
                            .font(.system(size: 15))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(DS.sand)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .onSubmit { Task { await addItem() } }

                        Button(action: { Task { await addItem() } }) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(DS.cream)
                                .frame(width: 44, height: 44)
                                .background(DS.ember)
                                .clipShape(Circle())
                        }
                        .disabled(newItemName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(newItemName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(DS.cream)
                }
            }
            .navigationTitle("Alışveriş Listesi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BackButton(action: onBack)
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        guard let userId = Clerk.shared.user?.id else {
            isLoading = false
            return
        }
        items = await APIService.fetchShoppingList(userId: userId)
        isLoading = false
    }

    private func addItem() async {
        let trimmed = newItemName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let userId = Clerk.shared.user?.id else { return }
        newItemName = ""
        if let created = await APIService.addShoppingListItem(userId: userId, ingredientName: trimmed) {
            items.insert(created, at: 0)
        }
    }

    private func toggle(_ item: ShoppingListItemDTO) async {
        guard let userId = Clerk.shared.user?.id,
              let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let newChecked = !item.is_checked
        items[index] = ShoppingListItemDTO(
            id: item.id,
            user_id: item.user_id,
            ingredient_name: item.ingredient_name,
            is_checked: newChecked,
            added_at: item.added_at
        )
        _ = await APIService.updateShoppingListItem(userId: userId, id: item.id, isChecked: newChecked)
    }

    private func delete(_ item: ShoppingListItemDTO) async {
        guard let userId = Clerk.shared.user?.id else { return }
        items.removeAll { $0.id == item.id }
        _ = await APIService.deleteShoppingListItem(userId: userId, id: item.id)
    }
}

private struct ShoppingListRow: View {
    let item: ShoppingListItemDTO
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.is_checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(item.is_checked ? DS.ember : DS.dust)
            }
            .buttonStyle(.plain)

            Text(item.ingredient_name)
                .font(.system(size: 15))
                .foregroundStyle(item.is_checked ? DS.smoke : DS.ink)
                .strikethrough(item.is_checked, color: DS.smoke)

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(DS.smoke)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}
